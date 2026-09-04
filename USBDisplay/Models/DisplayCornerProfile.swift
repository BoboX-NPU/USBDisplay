import Foundation

enum DisplayCornerProfileResolver {
  static let modernIPhoneFraction = 0.14
  static let iPadFraction = 0.03
  static let minimumModernIPhoneLongAspect = 1.9
  static let maximumFraction = 0.20

  static func automaticFraction(
    for device: DisplayDevice,
    aspectRatio: Double?
  ) -> Double {
    switch device.kind {
    case .iPhone:
      guard let longAspect = normalizedLongAspect(aspectRatio) else {
        return modernIPhoneFraction
      }
      return longAspect >= minimumModernIPhoneLongAspect ? modernIPhoneFraction : 0

    case .iPad:
      return iPadFraction

    case .unknown:
      return 0
    }
  }

  static func normalizedLongAspect(_ aspectRatio: Double?) -> Double? {
    guard
      let aspectRatio,
      let validRatio = WindowLayoutPolicy.validAspectRatio(width: aspectRatio, height: 1)
    else {
      return nil
    }
    return max(validRatio, 1 / validRatio)
  }

  static func clampedFraction(_ fraction: Double) -> Double {
    min(max(fraction, 0), maximumFraction)
  }

  static func cornerRadius(shortSide: Double, fraction: Double) -> Double {
    guard shortSide.isFinite, shortSide > 0 else { return 0 }
    return shortSide * clampedFraction(fraction)
  }
}
