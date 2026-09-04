import Foundation

enum DisplayCornerSource: String, Equatable, Sendable {
  case modelMatch
  case manual
  case unmatched
}

struct DisplayCornerProfile: Equatable, Sendable {
  let modelName: String?
  let fraction: Double
  let source: DisplayCornerSource
  let reference: String?
}

enum DisplayCornerProfileResolver {
  static let maximumFraction = 0.20

  static func automaticProfile(for device: DisplayDevice) -> DisplayCornerProfile {
    guard let reference = modelProfiles[device.modelID] else {
      return DisplayCornerProfile(modelName: nil, fraction: 0, source: .unmatched, reference: nil)
    }
    return DisplayCornerProfile(
      modelName: reference.name,
      fraction: reference.radius / reference.shortSide,
      source: .modelMatch,
      reference: "Apple Simulator display profile"
    )
  }

  static func automaticFraction(for device: DisplayDevice, aspectRatio: Double?) -> Double {
    automaticProfile(for: device).fraction
  }

  static func normalizedLongAspect(_ aspectRatio: Double?) -> Double? {
    guard let aspectRatio,
      let validRatio = WindowLayoutPolicy.validAspectRatio(width: aspectRatio, height: 1)
    else { return nil }
    return max(validRatio, 1 / validRatio)
  }

  static func clampedFraction(_ fraction: Double) -> Double {
    guard fraction.isFinite else { return 0 }
    return min(max(fraction, 0), maximumFraction)
  }

  static func cornerRadius(shortSide: Double, fraction: Double) -> Double {
    guard shortSide.isFinite, shortSide > 0 else { return 0 }
    return shortSide * clampedFraction(fraction)
  }

  // Reference measurements in logical points, never inferred from a device name or aspect ratio.
  // Provenance and source hashes: doc/device-corner-profiles.md.
  private static let modelProfiles: [String: (name: String, radius: Double, shortSide: Double)] = [
    "iPad11,1": ("iPad mini (5th generation)", 0.0, 768.0),
    "iPad11,3": ("iPad Air (3rd generation)", 18.0, 834.0),
    "iPad11,7": ("iPad (8th generation)", 0.0, 810.0),
    "iPad12,2": ("iPad", 0.0, 810.0),
    "iPad13,10": ("iPad Pro (12.9-inch) (5th generation)", 18.0, 1024.0),
    "iPad13,17": ("iPad Air (5th generation)", 18.0, 820.0),
    "iPad13,18": ("iPad (10th generation)", 25.0, 820.0),
    "iPad13,2": ("iPad Air (4th generation)", 18.0, 820.0),
    "iPad13,5": ("iPad Pro (11-inch) (3rd generation)", 18.0, 834.0),
    "iPad14,1": ("iPad mini", 21.5, 744.0),
    "iPad14,11": ("iPad Air 13-inch (M2)", 18.0, 1024.0),
    "iPad14,3": ("iPad Pro (11-inch) (4th generation)", 18.0, 834.0),
    "iPad14,4": ("iPad Pro (11-inch) (4th generation)", 18.0, 834.0),
    "iPad14,5": ("iPad Pro (12.9-inch) (6th generation)", 18.0, 1024.0),
    "iPad14,9": ("iPad Air 11-inch (M2)", 18.0, 820.0),
    "iPad15,3": ("iPad Air 11-inch (M3)", 18.0, 820.0),
    "iPad15,5": ("iPad Air 13-inch (M3)", 18.0, 1024.0),
    "iPad15,7": ("iPad (A16)", 25.0, 820.0),
    "iPad16,11": ("iPad Air 13-inch (M4)", 18.0, 1024.0),
    "iPad16,2": ("iPad mini (A17 Pro)", 21.5, 744.0),
    "iPad16,4": ("iPad Pro 11-inch (M4)", 30.0, 834.0),
    "iPad16,6": ("iPad Pro 13-inch (M4)", 30.0, 1032.0),
    "iPad16,9": ("iPad Air 11-inch (M4)", 18.0, 820.0),
    "iPad17,2": ("iPad Pro 11-inch (M5)", 30.0, 834.0),
    "iPad17,4": ("iPad Pro 13-inch (M5)", 30.0, 1032.0),
    "iPad5,1": ("iPad mini 4", 0.0, 768.0),
    "iPad5,4": ("iPad Air 2", 0.0, 768.0),
    "iPad6,12": ("iPad (5th generation)", 0.0, 768.0),
    "iPad6,4": ("iPad Pro (9.7-inch)", 0.0, 768.0),
    "iPad6,8": ("iPad Pro", 0.0, 1024.0),
    "iPad7,1": ("iPad Pro (12.9-inch) (2nd generation)", 0.0, 1024.0),
    "iPad7,12": ("iPad (7th generation)", 0.0, 810.0),
    "iPad7,3": ("iPad Pro (10.5-inch)", 0.0, 834.0),
    "iPad7,6": ("iPad (6th generation)", 0.0, 768.0),
    "iPad8,1": ("iPad Pro (11-inch) (1st generation)", 18.0, 834.0),
    "iPad8,12": ("iPad Pro (12.9-inch) (4th generation)", 18.0, 1024.0),
    "iPad8,5": ("iPad Pro (12.9-inch) (3rd generation)", 18.0, 1024.0),
    "iPad8,9": ("iPad Pro (11-inch) (2nd generation)", 18.0, 834.0),
    "iPhone10,4": ("iPhone 8", 0.0, 375.0),
    "iPhone10,5": ("iPhone 8 Plus", 0.0, 414.0),
    "iPhone10,6": ("iPhone X", 39.0, 375.0),
    "iPhone11,2": ("iPhone XS", 39.0, 375.0),
    "iPhone11,4": ("iPhone XS Max", 39.0, 414.0),
    "iPhone11,8": ("iPhone XR", 41.5, 414.0),
    "iPhone12,1": ("iPhone 11", 41.5, 414.0),
    "iPhone12,3": ("iPhone 11 Pro", 39.0, 375.0),
    "iPhone12,5": ("iPhone 11 Pro Max", 39.0, 414.0),
    "iPhone12,8": ("iPhone SE", 0.0, 375.0),
    "iPhone13,1": ("iPhone 12 mini", 44.0, 360.0),
    "iPhone13,2": ("iPhone 12", 47.0, 390.0),
    "iPhone13,3": ("iPhone 12 Pro", 47.0, 390.0),
    "iPhone13,4": ("iPhone 12 Pro Max", 53.0, 428.0),
    "iPhone14,2": ("iPhone 13 Pro", 47.33333206176758, 390.0),
    "iPhone14,3": ("iPhone 13 Pro Max", 53.33333206176758, 428.0),
    "iPhone14,4": ("iPhone 13 mini", 44.0, 360.0),
    "iPhone14,5": ("iPhone 13", 47.33333206176758, 390.0),
    "iPhone14,6": ("iPhone SE (3rd generation)", 0.0, 375.0),
    "iPhone14,7": ("iPhone 14", 47.33333206176758, 390.0),
    "iPhone14,8": ("iPhone 14 Plus", 53.33333206176758, 428.0),
    "iPhone15,2": ("iPhone 14 Pro", 55.0, 393.0),
    "iPhone15,3": ("iPhone 14 Pro Max", 55.0, 430.0),
    "iPhone15,4": ("iPhone 15", 55.0, 393.0),
    "iPhone15,5": ("iPhone 15 Plus", 55.0, 430.0),
    "iPhone16,1": ("iPhone 15 Pro", 55.0, 393.0),
    "iPhone16,2": ("iPhone 15 Pro Max", 55.0, 430.0),
    "iPhone17,1": ("iPhone 16 Pro", 62.0, 402.0),
    "iPhone17,2": ("iPhone 16 Pro Max", 62.0, 440.0),
    "iPhone17,3": ("iPhone 16", 55.0, 393.0),
    "iPhone17,4": ("iPhone 16 Plus", 55.0, 430.0),
    "iPhone17,5": ("iPhone 16e", 47.33333206176758, 390.0),
    "iPhone18,1": ("iPhone 17 Pro", 62.0, 402.0),
    "iPhone18,2": ("iPhone 17 Pro Max", 62.0, 440.0),
    "iPhone18,3": ("iPhone 17", 62.0, 402.0),
    "iPhone18,4": ("iPhone Air", 62.0, 420.0),
    "iPhone18,5": ("iPhone 17e", 47.33333206176758, 390.0),
    "iPhone8,1": ("iPhone 6s", 0.0, 375.0),
    "iPhone8,2": ("iPhone 6s Plus", 0.0, 414.0),
    "iPhone8,4": ("iPhone SE", 0.0, 320.0),
    "iPhone9,1": ("iPhone 7", 0.0, 375.0),
    "iPhone9,2": ("iPhone 7 Plus", 0.0, 414.0),
  ]
}
