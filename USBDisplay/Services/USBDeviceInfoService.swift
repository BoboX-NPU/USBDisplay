import Darwin
import Foundation

struct USBDeviceIdentity: Equatable, Sendable {
  let name: String
  let productType: String
}

enum USBQueryError: Error, Equatable {
  case unavailable
  case disconnected
  case timedOut
  case invalidResponse
  case responseTooLarge
  case cancelled
}

/// Only unambiguous, complete snapshots can establish a capture-to-USB association.
enum DeviceIdentityMatcher {
  static func resolve(_ captures: [DisplayDevice], identities: [USBDeviceIdentity])
    -> [DisplayDevice]
  {
    let captureNames = Dictionary(grouping: captures, by: \.name)
    let usbNames = Dictionary(grouping: identities, by: \.name)
    return captures.map { device in
      let matches = usbNames[device.name] ?? []
      let state: DeviceIdentificationState
      let product: String?
      if captureNames[device.name]?.count != 1 || matches.count > 1 {
        state = .ambiguous
        product = nil
      } else if let match = matches.first {
        state = .identified
        product = match.productType
      } else {
        state = .unavailable
        product = nil
      }
      return device.identifying(as: product, state: state)
    }
  }
}

@MainActor
final class DeviceIdentityService {
  typealias Query = @Sendable () async throws -> [USBDeviceIdentity]
  private let query: Query
  private var task: Task<Void, Never>?
  private var generation = 0

  init(query: @escaping Query = { try await USBDeviceInfoClient().identities() }) {
    self.query = query
  }

  func refresh(_ captures: [DisplayDevice], publish: @escaping @MainActor ([DisplayDevice]) -> Void)
  {
    cancel()
    guard !captures.isEmpty else {
      publish([])
      return
    }
    let currentGeneration = generation
    publish(captures.map { $0.identifying(as: nil, state: .identifying) })
    let query = query
    task = Task { [weak self] in
      while !Task.isCancelled {
        let resolved: [DisplayDevice]
        do {
          resolved = DeviceIdentityMatcher.resolve(captures, identities: try await query())
        } catch {
          resolved = captures.map { $0.identifying(as: nil, state: .unavailable) }
        }
        guard !Task.isCancelled, self?.generation == currentGeneration else { return }
        publish(resolved)
        do { try await Task.sleep(for: .seconds(5)) } catch { return }
      }
    }
  }

  func cancel() {
    generation += 1
    task?.cancel()
    task = nil
  }

  deinit { task?.cancel() }
}

/// A minimal read-only usbmuxd/lockdownd client. It never pairs, starts sessions,
/// reads pairing records, or requests services other than the GetValue tunnel.
struct USBDeviceInfoClient: Sendable {
  var timeout: TimeInterval = 4
  var socketPath = "/var/run/usbmuxd"

  func identities() async throws -> [USBDeviceIdentity] {
    let cancellation = USBQueryCancellation()
    return try await withTaskCancellationHandler {
      try await Task.detached(priority: .utility) {
        try query(cancellation: cancellation)
      }.value
    } onCancel: {
      cancellation.cancel()
    }
  }

  private func query(cancellation: USBQueryCancellation) throws -> [USBDeviceIdentity] {
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    let listing = try USBLocalConnection(
      path: socketPath, deadline: deadline, cancellation: cancellation)
    defer { listing.close() }
    let response = try listing.muxRequest(["MessageType": "ListDevices"], tag: 1)
    guard let devices = response["DeviceList"] as? [[String: Any]], devices.count <= 64 else {
      throw USBQueryError.invalidResponse
    }
    var result: [USBDeviceIdentity] = []
    for device in devices {
      guard let properties = device["Properties"] as? [String: Any] else {
        throw USBQueryError.invalidResponse
      }
      guard properties["ConnectionType"] as? String == "USB" else { continue }
      guard let deviceID = device["DeviceID"] as? UInt32 else {
        throw USBQueryError.invalidResponse
      }
      let connection = try USBLocalConnection(
        path: socketPath, deadline: deadline, cancellation: cancellation)
      defer { connection.close() }
      let connected = try connection.muxRequest(
        [
          "MessageType": "Connect", "DeviceID": deviceID,
          "PortNumber": UInt16(62078).bigEndian,
        ], tag: 2)
      guard connected["Number"] as? Int == 0 else { throw USBQueryError.unavailable }
      let productType = try connection.getValue(.productType)
      let name = try connection.getValue(.deviceName)
      result.append(USBDeviceIdentity(name: name, productType: productType))
    }
    return result
  }
}

enum USBReadOnlyKey: String {
  case productType = "ProductType"
  case deviceName = "DeviceName"
}

/// Kept separate from I/O so malformed length/header/value handling is testable.
enum USBPlistProtocol {
  static let maximumResponseLength = 1_048_576

  static func encode(_ value: [String: Any]) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
  }

  static func decode(_ data: Data) throws -> [String: Any] {
    guard data.count <= maximumResponseLength else { throw USBQueryError.responseTooLarge }
    guard
      let value = try PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any]
    else {
      throw USBQueryError.invalidResponse
    }
    return value
  }

  static func word(_ value: UInt32, littleEndian: Bool) -> Data {
    var encoded = littleEndian ? value.littleEndian : value.bigEndian
    return withUnsafeBytes(of: &encoded) { Data($0) }
  }

  static func readWord(_ data: Data, at offset: Int, littleEndian: Bool) throws -> UInt32 {
    guard offset >= 0, data.count >= offset + 4 else { throw USBQueryError.invalidResponse }
    let word = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    return littleEndian ? UInt32(littleEndian: word) : UInt32(bigEndian: word)
  }

  static func payloadLength(_ header: Data, muxTag: UInt32? = nil) throws -> Int {
    let total = Int(try readWord(header, at: 0, littleEndian: muxTag != nil))
    let length: Int
    if let muxTag {
      guard header.count == 16, total >= 16,
        try readWord(header, at: 4, littleEndian: true) == 1,
        try readWord(header, at: 8, littleEndian: true) == 8,
        try readWord(header, at: 12, littleEndian: true) == muxTag
      else { throw USBQueryError.invalidResponse }
      length = total - 16
    } else {
      length = total
    }
    guard length > 0 else { throw USBQueryError.invalidResponse }
    guard length <= maximumResponseLength else { throw USBQueryError.responseTooLarge }
    return length
  }

  static func stringValue(_ response: [String: Any]) throws -> String {
    guard response["Error"] == nil, response["Request"] as? String == "GetValue",
      let value = response["Value"] as? String, !value.isEmpty, value.utf8.count <= 1024
    else { throw USBQueryError.invalidResponse }
    return value
  }
}

private final class USBQueryCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false
  func cancel() { lock.withLock { cancelled = true } }
  func check() throws {
    if lock.withLock({ cancelled }) { throw USBQueryError.cancelled }
  }
}

/// Nonblocking I/O checks cancellation at most every 50 ms and uses one deadline
/// for the entire snapshot, including partial reads and every connected device.
private final class USBLocalConnection {
  private var descriptor: Int32 = -1
  private let deadline: TimeInterval
  private let cancellation: USBQueryCancellation

  init(path: String, deadline: TimeInterval, cancellation: USBQueryCancellation) throws {
    self.deadline = deadline
    self.cancellation = cancellation
    try cancellation.check()
    descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { throw USBQueryError.unavailable }
    do {
      guard fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0 else { throw USBQueryError.unavailable }
      var noSignal: Int32 = 1
      guard
        setsockopt(
          descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size)) == 0
      else {
        throw USBQueryError.unavailable
      }
      var address = sockaddr_un()
      address.sun_family = sa_family_t(AF_UNIX)
      let path = Array(path.utf8CString)
      guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else {
        throw USBQueryError.unavailable
      }
      withUnsafeMutableBytes(of: &address.sun_path) { bytes in
        bytes.copyBytes(from: path.map { UInt8(bitPattern: $0) })
      }
      address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
      let status = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
      }
      if status != 0 {
        guard errno == EINPROGRESS else { throw USBQueryError.unavailable }
        try wait(for: Int16(POLLOUT))
        var error: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, &size) == 0, error == 0 else {
          throw USBQueryError.unavailable
        }
      }
    } catch {
      close()
      throw error
    }
  }

  deinit { close() }
  func close() {
    if descriptor >= 0 {
      Darwin.close(descriptor)
      descriptor = -1
    }
  }

  func muxRequest(_ request: [String: Any], tag: UInt32) throws -> [String: Any] {
    var request = request
    request["ClientVersionString"] = "USB Display"
    request["ProgName"] = "USB Display"
    request["kLibUSBMuxVersion"] = 3
    let body = try USBPlistProtocol.encode(request)
    let header = [UInt32(body.count + 16), 1, 8, tag].reduce(into: Data()) {
      $0.append(USBPlistProtocol.word($1, littleEndian: true))
    }
    try write(header + body)
    let length = try USBPlistProtocol.payloadLength(read(16), muxTag: tag)
    return try USBPlistProtocol.decode(read(length))
  }

  func getValue(_ key: USBReadOnlyKey) throws -> String {
    let body = try USBPlistProtocol.encode([
      "Label": "USB Display", "Request": "GetValue", "Key": key.rawValue,
    ])
    try write(USBPlistProtocol.word(UInt32(body.count), littleEndian: false) + body)
    let length = try USBPlistProtocol.payloadLength(read(4))
    return try USBPlistProtocol.stringValue(USBPlistProtocol.decode(read(length)))
  }

  private func wait(for events: Int16) throws {
    while true {
      try cancellation.check()
      let remaining = deadline - ProcessInfo.processInfo.systemUptime
      guard remaining > 0 else { throw USBQueryError.timedOut }
      var request = pollfd(fd: descriptor, events: events, revents: 0)
      let status = poll(&request, 1, Int32(min(remaining * 1000, 50).rounded(.up)))
      if status < 0 {
        if errno == EINTR { continue }
        throw USBQueryError.disconnected
      }
      if status > 0 {
        if request.revents & events != 0 { return }
        throw USBQueryError.disconnected
      }
    }
  }

  private func read(_ length: Int) throws -> Data {
    var data = Data(count: length)
    var offset = 0
    while offset < length {
      try wait(for: Int16(POLLIN))
      let count = data.withUnsafeMutableBytes {
        Darwin.read(descriptor, $0.baseAddress!.advanced(by: offset), length - offset)
      }
      if count < 0, errno == EINTR || errno == EAGAIN { continue }
      guard count > 0 else { throw USBQueryError.disconnected }
      offset += count
    }
    return data
  }

  private func write(_ data: Data) throws {
    var offset = 0
    while offset < data.count {
      try wait(for: Int16(POLLOUT))
      let count = data.withUnsafeBytes {
        Darwin.write(descriptor, $0.baseAddress!.advanced(by: offset), data.count - offset)
      }
      if count < 0, errno == EINTR || errno == EAGAIN { continue }
      guard count > 0 else { throw USBQueryError.disconnected }
      offset += count
    }
  }
}
