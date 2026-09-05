import Foundation

struct DisplayDevice: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let modelID: String
  let productType: String?
  let identificationState: DeviceIdentificationState

  init(
    id: String, name: String, modelID: String = "", productType: String? = nil,
    identificationState: DeviceIdentificationState = .identifying
  ) {
    self.id = id
    self.name = name
    self.modelID = modelID
    self.productType = productType
    self.identificationState = identificationState
  }

  func identifying(as productType: String?, state: DeviceIdentificationState) -> DisplayDevice {
    DisplayDevice(
      id: id, name: name, modelID: modelID, productType: productType, identificationState: state)
  }

  var modelDisplayName: String {
    DisplayCornerProfileResolver.automaticProfile(for: self).modelName ?? productType ?? name
  }
}

enum DeviceIdentificationState: Equatable, Sendable {
  case identifying, identified, ambiguous, unavailable
}

struct CaptureDeviceDescriptor: Equatable, Sendable {
  let isExternal: Bool
  let hasMuxedMedia: Bool
  let manufacturer: String
}

enum CaptureDeviceFilter {
  static func isEligible(_ descriptor: CaptureDeviceDescriptor) -> Bool {
    // CoreMediaIO disables wireless screen devices before discovery. Do not inspect
    // transportType here because macOS can report a wired iPhone as `Other`.
    descriptor.isExternal
      && descriptor.hasMuxedMedia
      && descriptor.manufacturer == "Apple Inc."
  }
}
