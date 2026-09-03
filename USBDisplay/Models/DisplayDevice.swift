import Foundation

struct DisplayDevice: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
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
