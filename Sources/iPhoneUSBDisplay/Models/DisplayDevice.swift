import Foundation

struct DisplayDevice: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
}

struct CaptureDeviceDescriptor: Equatable, Sendable {
  let isExternal: Bool
  let hasMuxedMedia: Bool
  let manufacturer: String
  let isUSB: Bool
}

enum CaptureDeviceFilter {
  static func isEligible(_ descriptor: CaptureDeviceDescriptor) -> Bool {
    descriptor.isExternal
      && descriptor.hasMuxedMedia
      && descriptor.manufacturer == "Apple Inc."
      && descriptor.isUSB
  }
}

enum DeviceSelectionPolicy {
  static func selectedID(
    devices: [DisplayDevice],
    currentID: String?,
    lastSelectedID: String?
  ) -> String? {
    let availableIDs = Set(devices.map(\.id))

    if let currentID, availableIDs.contains(currentID) {
      return currentID
    }

    if let lastSelectedID, availableIDs.contains(lastSelectedID) {
      return lastSelectedID
    }

    return devices.count == 1 ? devices[0].id : nil
  }
}
