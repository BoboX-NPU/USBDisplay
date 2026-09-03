import Foundation

enum DeviceWindowRoute: Equatable, Sendable {
  case assignCurrentWindow(deviceID: String)
  case keepCurrentWindow
  case openDeviceWindow(deviceID: String)
}

enum DeviceWindowRoutingPolicy {
  static func route(currentDeviceID: String?, selectedDeviceID: String) -> DeviceWindowRoute {
    guard let currentDeviceID else {
      return .assignCurrentWindow(deviceID: selectedDeviceID)
    }

    if currentDeviceID == selectedDeviceID {
      return .keepCurrentWindow
    }

    return .openDeviceWindow(deviceID: selectedDeviceID)
  }
}

@MainActor
final class DeviceWindowRegistry {
  private var ownersByDeviceID: [String: UUID] = [:]

  func claim(deviceID: String, windowID: UUID) -> Bool {
    if let owner = ownersByDeviceID[deviceID] {
      return owner == windowID
    }

    ownersByDeviceID[deviceID] = windowID
    return true
  }

  func release(deviceID: String, windowID: UUID) {
    guard ownersByDeviceID[deviceID] == windowID else { return }
    ownersByDeviceID.removeValue(forKey: deviceID)
  }

  func isClaimed(_ deviceID: String) -> Bool {
    ownersByDeviceID[deviceID] != nil
  }
}
