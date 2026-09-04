import Foundation

struct DisplayDevice: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let modelID: String
  let productType: String?
  let identificationState: DeviceIdentificationState
  let kind: DisplayDeviceKind

  init(
    id: String, name: String, modelID: String = "", productType: String? = nil,
    identificationState: DeviceIdentificationState = .identifying
  ) {
    self.id = id
    self.name = name
    self.modelID = modelID
    self.productType = productType
    self.identificationState = identificationState
    kind = DisplayDeviceKind.resolve(modelID: productType ?? modelID, name: name)
  }

  func identifying(as productType: String?, state: DeviceIdentificationState) -> DisplayDevice {
    DisplayDevice(
      id: id, name: name, modelID: modelID, productType: productType, identificationState: state)
  }

  var identificationDescription: String {
    let profile = DisplayCornerProfileResolver.automaticProfile(for: self)
    if let model = profile.modelName { return model + " · Automatic corners" }
    if let productType { return productType + " · No corner profile" }
    switch identificationState {
    case .identifying: return "Identifying device…"
    case .ambiguous: return "Same-name devices · Model unresolved"
    case .unavailable: return "Model unavailable · Square corners"
    case .identified: return "No corner profile"
    }
  }
}

enum DeviceIdentificationState: Equatable, Sendable {
  case identifying, identified, ambiguous, unavailable
}

enum DisplayDeviceKind: String, Equatable, Sendable {
  case iPhone
  case iPad
  case unknown

  static func resolve(modelID: String, name: String) -> DisplayDeviceKind {
    let identity = "\(modelID) \(name)".lowercased()
    if identity.contains("iphone") {
      return .iPhone
    }
    if identity.contains("ipad") {
      return .iPad
    }
    return .unknown
  }
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
