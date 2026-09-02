import Foundation

enum ConnectionStatus: Equatable, Sendable {
  case noDevice
  case waitingForUnlockOrTrust(deviceName: String?)
  case connecting(deviceName: String)
  case connected(deviceName: String)
  case interrupted(deviceName: String?)
  case occupied(deviceName: String)
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
    case .cameraPermissionDenied:
      "Enable camera access in System Settings > Privacy & Security > Camera."
    case .failed(let message):
      message
    }
  }
}

struct CaptureSnapshot: Equatable, Sendable {
  let devices: [DisplayDevice]
  let selectedDeviceID: String?
  let status: ConnectionStatus
}

enum DeviceAbsenceStatusPolicy {
  static func status(
    previousSelectedName: String?,
    currentStatus: ConnectionStatus
  ) -> ConnectionStatus {
    if let previousSelectedName {
      return .interrupted(deviceName: previousSelectedName)
    }

    if case .interrupted(let deviceName) = currentStatus {
      return .interrupted(deviceName: deviceName)
    }

    return .noDevice
  }
}
