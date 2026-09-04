import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct CornerRadiusPreferencesTests {
  @Test @MainActor
  func manualOverrideWinsAndPersistsWithoutRawDeviceIdentifier() throws {
    let suiteName = "CornerRadiusPreferencesTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer {
      defaults.removePersistentDomain(forName: suiteName)
    }

    let device = DisplayDevice(
      id: "private-physical-device-identifier",
      name: "Test iPhone",
      modelID: "iPhone17,1"
    )
    let preferences = CornerRadiusPreferences(defaults: defaults)

    #expect(preferences.resolvedFraction(for: device, aspectRatio: 9.0 / 19.5) == 0.14)

    preferences.setOverrideFraction(0.075, for: device.id)

    #expect(preferences.resolvedFraction(for: device, aspectRatio: 9.0 / 19.5) == 0.075)
    let storedOverrides = try #require(
      defaults.dictionary(forKey: CornerRadiusPreferences.storageKey)
    )
    #expect(!storedOverrides.keys.contains(device.id))
    #expect(storedOverrides.keys.contains(CornerRadiusPreferences.preferenceKey(for: device.id)))

    let reloadedPreferences = CornerRadiusPreferences(defaults: defaults)
    #expect(reloadedPreferences.overrideFraction(for: device.id) == 0.075)
  }

  @Test @MainActor
  func resetRestoresAutomaticProfile() throws {
    let suiteName = "CornerRadiusPreferencesTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer {
      defaults.removePersistentDomain(forName: suiteName)
    }

    let device = DisplayDevice(id: "tablet", name: "Test iPad", modelID: "iPad16,5")
    let preferences = CornerRadiusPreferences(defaults: defaults)
    preferences.setOverrideFraction(0.09, for: device.id)

    preferences.resetOverride(for: device.id)

    #expect(preferences.overrideFraction(for: device.id) == nil)
    #expect(preferences.resolvedFraction(for: device, aspectRatio: 3.0 / 4.0) == 0.03)
  }

  @Test @MainActor
  func manualOverrideIsClampedToSupportedRange() throws {
    let suiteName = "CornerRadiusPreferencesTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer {
      defaults.removePersistentDomain(forName: suiteName)
    }

    let preferences = CornerRadiusPreferences(defaults: defaults)
    preferences.setOverrideFraction(1, for: "device")

    #expect(
      preferences.overrideFraction(for: "device")
        == DisplayCornerProfileResolver.maximumFraction
    )
  }
}
