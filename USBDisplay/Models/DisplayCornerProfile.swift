import Foundation

enum DisplayCornerSource: String, Equatable, Sendable {
  case modelMatch
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
    guard let productType = device.productType, let reference = modelProfiles[productType] else {
      return DisplayCornerProfile(modelName: nil, fraction: 0, source: .unmatched, reference: nil)
    }
    return DisplayCornerProfile(
      modelName: reference.name,
      fraction: reference.fraction,
      source: .modelMatch,
      reference: reference.reference
    )
  }

  static func clampedFraction(_ fraction: Double) -> Double {
    guard fraction.isFinite else { return 0 }
    return min(max(fraction, 0), maximumFraction)
  }

  static func cornerRadius(shortSide: Double, fraction: Double) -> Double {
    guard shortSide.isFinite, shortSide > 0 else { return 0 }
    return shortSide * clampedFraction(fraction)
  }

  static let modelProfiles: [String: DeviceCornerReference] = {
    guard let url = Bundle.main.url(forResource: "device-corner-profiles", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let profiles = try? loadProfiles(from: data)
    else {
      AppLogger.interface.error("Bundled device corner catalog is missing or invalid")
      return [:]
    }
    return profiles
  }()

  static func loadProfiles(from data: Data) throws -> [String: DeviceCornerReference] {
    let catalog = try JSONDecoder().decode(DeviceCornerCatalog.self, from: data)
    guard catalog.schemaVersion == 1, !catalog.profiles.isEmpty else {
      throw DeviceCornerCatalogError.invalidCatalog
    }
    var profiles: [String: DeviceCornerReference] = [:]
    for profile in catalog.profiles {
      guard
        profile.productType.range(
          of: #"^(iPhone|iPad)[1-9][0-9]*,[1-9][0-9]*$"#, options: .regularExpression) != nil,
        !profile.name.isEmpty, !profile.reference.isEmpty,
        profile.radius.isFinite, profile.radius >= 0,
        profile.shortSide.map({ $0.isFinite && $0 > 0 }) ?? (profile.radius == 0),
        profile.fraction <= maximumFraction,
        profiles[profile.productType] == nil
      else {
        throw DeviceCornerCatalogError.invalidCatalog
      }
      profiles[profile.productType] = profile
    }
    return profiles
  }
}

struct DeviceCornerReference: Decodable, Sendable {
  let productType: String
  let name: String
  let radius: Double
  let shortSide: Double?
  let reference: String

  var fraction: Double { radius == 0 ? 0 : radius / (shortSide ?? 1) }
}

private struct DeviceCornerCatalog: Decodable {
  let schemaVersion: Int
  let profiles: [DeviceCornerReference]
}

enum DeviceCornerCatalogError: Error {
  case invalidCatalog
}
