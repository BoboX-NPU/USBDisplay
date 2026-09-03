@preconcurrency import AVFoundation
import Testing

@testable import iPhoneUSBDisplay

struct CaptureQualityTests {
  @Test
  func automaticUsesHighQuality() {
    let preset = CaptureQualityPolicy.firstSupportedPreset(for: .automatic) { _ in true }

    #expect(preset == .high)
  }

  @Test
  func explicitQualitiesPreferRequestedResolution() {
    let fullHD = CaptureQualityPolicy.firstSupportedPreset(for: .fullHD) { _ in true }
    let ultraHD = CaptureQualityPolicy.firstSupportedPreset(for: .ultraHD) { _ in true }

    #expect(fullHD == .hd1920x1080)
    #expect(ultraHD == .hd4K3840x2160)
  }

  @Test
  func explicitQualitiesFallBackWithoutInventingSupport() {
    let fullHD = CaptureQualityPolicy.firstSupportedPreset(for: .fullHD) {
      $0 == .high
    }
    let ultraHD = CaptureQualityPolicy.firstSupportedPreset(for: .ultraHD) {
      $0 == .hd1920x1080 || $0 == .high
    }

    #expect(fullHD == .high)
    #expect(ultraHD == .hd1920x1080)
  }
}
