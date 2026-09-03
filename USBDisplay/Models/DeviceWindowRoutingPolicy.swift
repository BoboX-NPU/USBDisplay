import Foundation

enum DeviceWindowRoute: Equatable, Sendable {
  case keepCurrentWindow
  case switchCurrentWindow(deviceID: String)
  case focusExistingWindow(deviceID: String)
}

enum DeviceWindowRoutingPolicy {
  static func route(
    currentDeviceID: String?,
    selectedDeviceID: String,
    selectedDeviceIsClaimedElsewhere: Bool
  ) -> DeviceWindowRoute {
    if currentDeviceID == selectedDeviceID {
      return .keepCurrentWindow
    }

    if selectedDeviceIsClaimedElsewhere {
      return .focusExistingWindow(deviceID: selectedDeviceID)
    }

    return .switchCurrentWindow(deviceID: selectedDeviceID)
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

  func isClaimed(_ deviceID: String, byAnotherWindowThan windowID: UUID) -> Bool {
    guard let owner = ownersByDeviceID[deviceID] else { return false }
    return owner != windowID
  }

  func transfer(
    from currentDeviceID: String?,
    to selectedDeviceID: String,
    windowID: UUID
  ) -> Bool {
    if let owner = ownersByDeviceID[selectedDeviceID], owner != windowID {
      return false
    }

    ownersByDeviceID[selectedDeviceID] = windowID
    if let currentDeviceID, currentDeviceID != selectedDeviceID {
      release(deviceID: currentDeviceID, windowID: windowID)
    }
    return true
  }
}
