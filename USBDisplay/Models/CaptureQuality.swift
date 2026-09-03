@preconcurrency import AVFoundation
import Foundation

enum CaptureQuality: String, CaseIterable, Identifiable, Sendable {
  case automatic
  case fullHD
  case ultraHD

  var id: Self { self }

  var title: String {
    switch self {
    case .automatic:
      "Auto"
    case .fullHD:
      "1080p"
    case .ultraHD:
      "4K (Experimental)"
    }
  }

  var accessibilityDescription: String {
    switch self {
    case .automatic:
      "Automatic high quality"
    case .fullHD:
      "Prefer 1080p, then fall back to automatic high quality"
    case .ultraHD:
      "Prefer 4K, then fall back to 1080p or automatic high quality"
    }
  }

  var preferredSessionPresets: [AVCaptureSession.Preset] {
    switch self {
    case .automatic:
      [.high]
    case .fullHD:
      [.hd1920x1080, .high]
    case .ultraHD:
      [.hd4K3840x2160, .hd1920x1080, .high]
    }
  }
}

enum CaptureQualityPolicy {
  static func firstSupportedPreset(
    for quality: CaptureQuality,
    supports: (AVCaptureSession.Preset) -> Bool
  ) -> AVCaptureSession.Preset {
    quality.preferredSessionPresets.first(where: supports) ?? .high
  }
}
