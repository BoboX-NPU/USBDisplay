import CryptoKit
import Foundation
import Observation

@MainActor
@Observable
final class CornerRadiusPreferences {
  static let storageKey = "displayCornerRadiusOverrides"

  private let defaults: UserDefaults
  private(set) var overrides: [String: Double]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    overrides =
      defaults.dictionary(forKey: Self.storageKey)?.reduce(into: [:]) { result, entry in
        if let value = entry.value as? Double {
          result[entry.key] = DisplayCornerProfileResolver.clampedFraction(value)
        }
      } ?? [:]
  }

  func resolvedFraction(for device: DisplayDevice, aspectRatio: Double?) -> Double {
    overrideFraction(for: device.id)
      ?? DisplayCornerProfileResolver.automaticFraction(
        for: device,
        aspectRatio: aspectRatio
      )
  }

  func overrideFraction(for deviceID: String) -> Double? {
    overrides[Self.preferenceKey(for: deviceID)]
  }

  func setOverrideFraction(_ fraction: Double, for deviceID: String) {
    overrides[Self.preferenceKey(for: deviceID)] =
      DisplayCornerProfileResolver.clampedFraction(fraction)
    persist()
  }

  func resetOverride(for deviceID: String) {
    overrides.removeValue(forKey: Self.preferenceKey(for: deviceID))
    persist()
  }

  static func preferenceKey(for deviceID: String) -> String {
    let digest = SHA256.hash(data: Data(deviceID.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private func persist() {
    defaults.set(overrides, forKey: Self.storageKey)
  }
}
