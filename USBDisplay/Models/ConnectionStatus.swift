import Foundation

enum ConnectionStatus: Equatable, Sendable {
  case noDevice
  case waitingForUnlockOrTrust(deviceName: String?)
  case connecting(deviceName: String)
  case connected(deviceName: String)
  case interrupted(deviceName: String?)
  case occupied(deviceName: String)
  case deviceUnavailable(deviceName: String)
  case cameraPermissionDenied
  case failed(message: String)

  var isConnected: Bool {
    if case .connected = self {
      return true
    }
    return false
  }

  var title: String {
    switch self {
    case .noDevice:
      "No device found"
    case .waitingForUnlockOrTrust:
      "Unlock the device and trust this Mac"
    case .connecting:
      "Connecting"
    case .connected:
      "Connected"
    case .interrupted:
      "Connection interrupted"
    case .occupied:
      "Device is in use"
    case .deviceUnavailable:
      "Device unavailable"
    case .cameraPermissionDenied:
      "No camera permission"
    case .failed:
      "Unable to connect"
    }
  }

  var detail: String? {
    switch self {
    case .noDevice:
      nil
    case .waitingForUnlockOrTrust(let deviceName):
      deviceName.map { "Unlock \($0) and trust this Mac if prompted." }
        ?? "Unlock the iPhone or iPad and trust this Mac if prompted."
    case .connecting(let deviceName):
      "Connecting to \(deviceName)…"
    case .connected(let deviceName):
      deviceName
    case .interrupted(let deviceName):
      deviceName.map { "Waiting for \($0) to reconnect…" }
        ?? "Waiting for the device to reconnect…"
    case .occupied(let deviceName):
      "Close QuickTime, OBS, or another app using \(deviceName)."
    case .deviceUnavailable(let deviceName):
      "Unlock \(deviceName), close other capture apps, then reconnect the USB cable."
    case .cameraPermissionDenied:
      "Enable camera access in System Settings > Privacy & Security > Camera."
    case .failed(let message):
      message
    }
  }
}

struct CaptureRequest: Equatable, Sendable {
  let id = UUID()
  let deviceID: String?
}

struct PreviewSource: Equatable, Sendable {
  let requestID: UUID
  let streamID: UUID
}

struct CaptureSnapshot: Equatable, Sendable {
  let request: CaptureRequest
  let streamID: UUID?
  let sequence: UInt64
  let status: ConnectionStatus
}

/// Validates delivery independently of task scheduling order on the main actor.
struct CapturePresentationState {
  private(set) var request: CaptureRequest
  private(set) var status: ConnectionStatus = .noDevice
  private(set) var aspectRatio: Double?
  private var streamID: UUID?
  private var lastSequence: UInt64 = 0

  init(request: CaptureRequest) { self.request = request }

  var source: PreviewSource? {
    guard status.isConnected, let streamID else { return nil }
    return PreviewSource(requestID: request.id, streamID: streamID)
  }

  mutating func apply(_ snapshot: CaptureSnapshot) {
    guard snapshot.request == request, snapshot.sequence > lastSequence else { return }
    lastSequence = snapshot.sequence
    if streamID != snapshot.streamID { aspectRatio = nil }
    streamID = snapshot.streamID
    status = snapshot.status
  }

  mutating func updateAspectRatio(source: PreviewSource, width: Double, height: Double) {
    guard self.source == source,
      let ratio = WindowLayoutPolicy.validAspectRatio(width: width, height: height)
    else { return }
    if let aspectRatio, abs(aspectRatio - ratio) < 0.001 { return }
    aspectRatio = ratio
  }
}
