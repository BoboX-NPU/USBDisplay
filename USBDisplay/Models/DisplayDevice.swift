import Foundation

struct DisplayDevice: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let modelID: String
  let kind: DisplayDeviceKind

  init(id: String, name: String, modelID: String = "") {
    self.id = id
    self.name = name
    self.modelID = modelID
    kind = DisplayDeviceKind.resolve(modelID: modelID, name: name)
  }
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
