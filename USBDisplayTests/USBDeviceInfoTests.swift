import Darwin
import Foundation
import Testing
import XCTest

@testable import iPhoneUSBDisplay

struct USBDeviceInfoTests {
  @Test func mapsProtocolValuesToIndependentModelReferences() throws {
    for (product, name, fraction) in [
      ("iPhone17,1", "iPhone 16 Pro", 62.0 / 402),
      ("iPhone18,1", "iPhone 17 Pro", 62.0 / 402),
      ("iPhone18,2", "iPhone 17 Pro Max", 62.0 / 440),
    ] {
      let value = try USBPlistProtocol.encode(["Request": "GetValue", "Value": product])
      let decoded = try USBPlistProtocol.stringValue(USBPlistProtocol.decode(value))
      let capture = DisplayDevice(
        id: "opaque-capture-uuid", name: "Personal phone", modelID: "iOS Device")
      let resolved = DeviceIdentityMatcher.resolve(
        [capture], identities: [USBDeviceIdentity(name: capture.name, productType: decoded)])
      let device = try #require(resolved.first)
      #expect(device.modelID == "iOS Device")
      #expect(device.productType == product)
      let profile = DisplayCornerProfileResolver.automaticProfile(for: device)
      #expect(profile.modelName == name)
      #expect(profile.fraction == fraction)
    }
  }

  @Test func ambiguousNamesAndUnknownProductsNeverGuess() {
    let capture = DisplayDevice(id: "a", name: "Same name", modelID: "iOS Device")
    let usb = USBDeviceIdentity(name: "Same name", productType: "iPhone17,1")
    let duplicateUSB = DeviceIdentityMatcher.resolve([capture], identities: [usb, usb])
    #expect(duplicateUSB.first?.identificationState == .ambiguous)
    #expect(duplicateUSB.first?.productType == nil)
    let duplicateCapture = DeviceIdentityMatcher.resolve(
      [capture, DisplayDevice(id: "b", name: capture.name)], identities: [usb])
    #expect(
      duplicateCapture.allSatisfy { $0.identificationState == .ambiguous && $0.productType == nil })
    let noMatch = DeviceIdentityMatcher.resolve(
      [capture], identities: [USBDeviceIdentity(name: "Other name", productType: "iPhone17,1")])
    #expect(noMatch.first?.identificationState == .unavailable)
    let unknown = DeviceIdentityMatcher.resolve(
      [capture], identities: [USBDeviceIdentity(name: capture.name, productType: "iPhone99,1")])[0]
    #expect(unknown.identificationState == .identified)
    #expect(DisplayCornerProfileResolver.automaticProfile(for: unknown).fraction == 0)
    #expect(DisplayCornerProfileResolver.automaticProfile(for: capture).fraction == 0)
  }

  @Test func legacyManualDataIsPreservedAndCannotOverrideAutomaticRadius() throws {
    let domain = "USBDisplayLegacyTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    let old = ["legacy-hashed-id": 0.07]
    defaults.set(old, forKey: "displayCornerRadiusOverrides")
    let device = DisplayDevice(id: "legacy", name: "Test", productType: "iPhone17,1")
    #expect(DisplayCornerProfileResolver.automaticProfile(for: device).fraction == 62.0 / 402)
    #expect(defaults.dictionary(forKey: "displayCornerRadiusOverrides") as? [String: Double] == old)
  }

  @Test func rejectsMalformedOversizedAndErrorResponses() throws {
    #expect(throws: USBQueryError.responseTooLarge) {
      try USBPlistProtocol.payloadLength(USBPlistProtocol.word(1_048_577, littleEndian: false))
    }
    #expect(throws: USBQueryError.invalidResponse) {
      try USBPlistProtocol.payloadLength(Data([0, 1]))
    }
    #expect(throws: USBQueryError.invalidResponse) {
      try USBPlistProtocol.stringValue(["Request": "GetValue", "Error": "MissingValue"])
    }
    let bad = [UInt32(16), 1, 8, 99].reduce(into: Data()) {
      $0 += USBPlistProtocol.word($1, littleEndian: true)
    }
    #expect(throws: USBQueryError.invalidResponse) {
      try USBPlistProtocol.payloadLength(bad, muxTag: 1)
    }
  }

  @Test @MainActor func disconnectCancelsAndLateIdentityCannotReachNewCapture() async throws {
    let oldStarted = XCTestExpectation(description: "Old query started")
    let newStarted = XCTestExpectation(description: "New query started")
    let newPublished = XCTestExpectation(description: "New identity published")
    let oldFinished = XCTestExpectation(description: "Superseded query finished")
    let query = ControlledIdentityQuery(started: [oldStarted, newStarted])
    let service = DeviceIdentityService(query: { await query.query() })
    defer { service.cancel() }
    var published: [DisplayDevice] = []
    let oldTask = try #require(
      service.refresh([DisplayDevice(id: "old", name: "Old")]) {
        published = $0
      })
    try await waitForSignal(oldStarted)
    service.refresh([DisplayDevice(id: "new", name: "New")]) {
      published = $0
      if $0.first?.identificationState == .identified { newPublished.fulfill() }
    }
    try await waitForSignal(newStarted)
    await query.finish(1, identities: [USBDeviceIdentity(name: "New", productType: "iPhone18,2")])
    try await waitForSignal(newPublished)
    await query.finish(0, identities: [USBDeviceIdentity(name: "Old", productType: "iPhone17,1")])
    Task {
      await oldTask.value
      oldFinished.fulfill()
    }
    try await waitForSignal(oldFinished)
    #expect(published.first?.id == "new")
    #expect(published.first?.productType == "iPhone18,2")
    service.refresh([]) { published = $0 }
    #expect(published.isEmpty)
  }

  @Test @MainActor func timeoutIsAnExplicitUnresolvedState() async throws {
    let service = DeviceIdentityService(query: { throw USBQueryError.timedOut })
    defer { service.cancel() }
    let published = XCTestExpectation(description: "Unresolved state published")
    var device: DisplayDevice?
    service.refresh([DisplayDevice(id: "a", name: "Test")]) {
      device = $0.first
      if device?.identificationState == .unavailable { published.fulfill() }
    }
    try await waitForSignal(published)
    #expect(device?.identificationState == .unavailable)
    #expect(device?.productType == nil)
  }

  @Test func localProtocolReadsPartialResponsesAndOnlyAllowedKeys() async throws {
    let server = try USBFixtureServer(mode: .normal)
    defer { server.stop() }
    let identities = try await USBDeviceInfoClient(timeout: 2, socketPath: server.path).identities()
    #expect(identities == [USBDeviceIdentity(name: "Fixture phone", productType: "iPhone17,1")])
    #expect(server.keys == ["ProductType", "DeviceName"])
  }

  @Test func stalledSocketTimesOutAndCancellationDoesNotWaitForDeadline() async throws {
    let server = try USBFixtureServer(mode: .stall)
    defer { server.stop() }
    let start = ProcessInfo.processInfo.systemUptime
    await #expect(throws: USBQueryError.timedOut) {
      try await USBDeviceInfoClient(timeout: 0.15, socketPath: server.path).identities()
    }
    #expect(ProcessInfo.processInfo.systemUptime - start < 1)
    let accepted = XCTestExpectation(description: "Cancellation fixture accepted query")
    let cancellationServer = try USBFixtureServer(mode: .stall, onAccept: { accepted.fulfill() })
    defer { cancellationServer.stop() }
    let task = Task {
      try await USBDeviceInfoClient(timeout: 4, socketPath: cancellationServer.path).identities()
    }
    try await waitForSignal(accepted)
    let cancelledAt = ProcessInfo.processInfo.systemUptime
    task.cancel()
    await #expect(throws: USBQueryError.cancelled) { try await task.value }
    #expect(ProcessInfo.processInfo.systemUptime - cancelledAt < 0.5)
  }

  @Test func unpluggedSocketRejectsIncompleteSnapshot() async throws {
    let server = try USBFixtureServer(mode: .disconnect)
    defer { server.stop() }
    await #expect(throws: USBQueryError.disconnected) {
      try await USBDeviceInfoClient(timeout: 1, socketPath: server.path).identities()
    }
  }
}

private func waitForSignal(_ expectation: XCTestExpectation) async throws {
  let result = await XCTWaiter.fulfillment(of: [expectation], timeout: 3)
  try #require(result == .completed)
}

private actor ControlledIdentityQuery {
  let started: [XCTestExpectation]
  private var continuations: [CheckedContinuation<[USBDeviceIdentity], Never>] = []

  init(started: [XCTestExpectation]) { self.started = started }

  func query() async -> [USBDeviceIdentity] {
    // Intentionally ignores cancellation; completion is controlled by the test.
    await withCheckedContinuation { continuation in
      continuations.append(continuation)
      started[continuations.count - 1].fulfill()
    }
  }

  func finish(_ index: Int, identities: [USBDeviceIdentity]) {
    continuations[index].resume(returning: identities)
  }
}

/// A local Unix-domain fixture, never a physical device or external network server.
private final class USBFixtureServer: @unchecked Sendable {
  enum Mode: Sendable { case normal, stall, disconnect }
  let path = "/tmp/usbdisplay-\(UUID().uuidString).sock"
  private let lock = NSLock()
  private var stopped = false
  private var recordedKeys: [String] = []
  var keys: [String] { lock.withLock { recordedKeys } }
  private let descriptor: Int32

  init(mode: Mode, onAccept: @escaping @Sendable () -> Void = {}) throws {
    descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    let bytes = Array(path.utf8CString).map { UInt8(bitPattern: $0) }
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
    let result = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard result == 0, listen(descriptor, 4) == 0 else {
      Darwin.close(descriptor)
      throw USBQueryError.unavailable
    }
    DispatchQueue.global().async { [self] in run(mode, onAccept: onAccept) }
  }

  func stop() { lock.withLock { stopped = true } }

  private func run(_ mode: Mode, onAccept: @Sendable () -> Void) {
    defer {
      Darwin.close(descriptor)
      unlink(path)
    }
    while !lock.withLock({ stopped }) {
      var ready = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
      guard poll(&ready, 1, 50) > 0 else { continue }
      let client = accept(descriptor, nil, nil)
      guard client >= 0 else { continue }
      onAccept()
      var noSignal: Int32 = 1
      setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
      if mode == .disconnect {
        Darwin.close(client)
        continue
      }
      if mode == .stall {
        // Keep the connection open until the test cancels/times out.
        while !lock.withLock({ stopped }) { usleep(10_000) }
        Darwin.close(client)
        continue
      }
      do { try serve(client) } catch {}
      Darwin.close(client)
    }
  }

  private func read(_ client: Int32, _ size: Int) throws -> Data {
    var result = Data(count: size)
    var offset = 0
    while offset < size {
      var ready = pollfd(fd: client, events: Int16(POLLIN), revents: 0)
      guard poll(&ready, 1, 2000) > 0 else { throw USBQueryError.timedOut }
      let count = result.withUnsafeMutableBytes {
        Darwin.read(client, $0.baseAddress!.advanced(by: offset), size - offset)
      }
      guard count > 0 else { throw USBQueryError.disconnected }
      offset += count
    }
    return result
  }

  private func respond(_ client: Int32, _ value: [String: Any], tag: UInt32? = nil) throws {
    let body = try USBPlistProtocol.encode(value)
    var packet: Data
    if let tag {
      packet = [UInt32(body.count + 16), 1, 8, tag].reduce(into: Data()) {
        $0 += USBPlistProtocol.word($1, littleEndian: true)
      }
    } else {
      packet = USBPlistProtocol.word(UInt32(body.count), littleEndian: false)
    }
    packet += body
    for byte in packet {
      var byte = byte
      guard Darwin.write(client, &byte, 1) == 1 else { throw USBQueryError.disconnected }
    }
  }

  private func serve(_ client: Int32) throws {
    let header = try read(client, 16)
    let tag = try USBPlistProtocol.readWord(header, at: 12, littleEndian: true)
    let body = try USBPlistProtocol.decode(
      read(client, USBPlistProtocol.payloadLength(header, muxTag: tag)))
    if body["MessageType"] as? String == "ListDevices" {
      try respond(
        client, ["DeviceList": [["DeviceID": 42, "Properties": ["ConnectionType": "USB"]]]],
        tag: tag)
      return
    }
    guard body["MessageType"] as? String == "Connect",
      body["PortNumber"] as? UInt16 == UInt16(62078).bigEndian
    else { throw USBQueryError.invalidResponse }
    try respond(client, ["MessageType": "Result", "Number": 0], tag: tag)
    for _ in 0..<2 {
      let request = try USBPlistProtocol.decode(
        read(client, USBPlistProtocol.payloadLength(read(client, 4))))
      guard request["Request"] as? String == "GetValue", let key = request["Key"] as? String,
        ["ProductType", "DeviceName"].contains(key)
      else { throw USBQueryError.invalidResponse }
      lock.withLock { recordedKeys.append(key) }
      try respond(
        client,
        ["Request": "GetValue", "Value": key == "ProductType" ? "iPhone17,1" : "Fixture phone"])
    }
  }
}
