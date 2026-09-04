import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct DisplayCornerProfileTests {
  @Test
  func resolvesDeviceKindFromModelBeforeDisplayName() {
    let phone = DisplayDevice(id: "phone", name: "Personal Device", productType: "iPhone17,1")
    let tablet = DisplayDevice(id: "tablet", name: "Studio Screen", productType: "iPad16,6")

    #expect(phone.kind == .iPhone)
    #expect(tablet.kind == .iPad)
  }

  @Test
  func fallsBackToLocalizedNameForDeviceKind() {
    let phone = DisplayDevice(id: "phone", name: "Booo's iPhone")
    let tablet = DisplayDevice(id: "tablet", name: "Drawing iPad")
    let unknown = DisplayDevice(id: "unknown", name: "External Screen")

    #expect(phone.kind == .iPhone)
    #expect(tablet.kind == .iPad)
    #expect(unknown.kind == .unknown)
  }

  @Test
  func modernIPhoneUsesRoundedProfileInEitherOrientation() {
    let phone = DisplayDevice(id: "phone", name: "Phone", productType: "iPhone17,1")

    let portrait = DisplayCornerProfileResolver.automaticFraction(
      for: phone,
      aspectRatio: 9.0 / 19.5
    )
    let landscape = DisplayCornerProfileResolver.automaticFraction(
      for: phone,
      aspectRatio: 19.5 / 9.0
    )

    #expect(portrait == 62.0 / 402.0)
    #expect(landscape == 62.0 / 402.0)
  }

  @Test
  func classicIPhoneUsesSquareProfile() {
    let phone = DisplayDevice(id: "phone", name: "Phone", productType: "iPhone10,4")

    let fraction = DisplayCornerProfileResolver.automaticFraction(
      for: phone,
      aspectRatio: 9.0 / 16.0
    )

    #expect(fraction == 0)
  }

  @Test
  func iPadUsesTabletProfile() {
    let tablet = DisplayDevice(id: "tablet", name: "Tablet", productType: "iPad16,6")

    let fraction = DisplayCornerProfileResolver.automaticFraction(
      for: tablet,
      aspectRatio: 3.0 / 4.0
    )

    #expect(fraction == 30.0 / 1032.0)
  }

  @Test
  func unknownDeviceUsesSquareProfile() {
    let unknown = DisplayDevice(id: "unknown", name: "External Screen")

    #expect(
      DisplayCornerProfileResolver.automaticFraction(
        for: unknown,
        aspectRatio: 9.0 / 19.5
      ) == 0
    )
  }

  @Test
  func onlyExactModelIdentifiersSelectProfiles() {
    for modelID in ["", "iPhone", "iPhone99,1", "iPad16,999", "prefix-iPhone17,1"] {
      let device = DisplayDevice(id: "test", name: "iPhone 16 Pro", productType: modelID)
      let profile = DisplayCornerProfileResolver.automaticProfile(for: device)
      #expect(profile.source == .unmatched)
      #expect(profile.fraction == 0)
      #expect(profile.modelName == nil)
    }
  }

  @Test
  func matchedProfileContainsNameAndMeasurementSource() {
    let device = DisplayDevice(id: "test", name: "Renamed iPad", productType: "iPhone17,1")
    let profile = DisplayCornerProfileResolver.automaticProfile(for: device)
    #expect(profile.source == .modelMatch)
    #expect(profile.modelName == "iPhone 16 Pro")
    #expect(profile.reference != nil)
    #expect(abs(profile.fraction - 62.0 / 402.0) < 0.000001)
    #expect(DisplayCornerProfileResolver.clampedFraction(.nan) == 0)
    #expect(DisplayCornerProfileResolver.clampedFraction(.infinity) == 0)
  }

  @Test
  func clampsFractionAndScalesRadiusFromShortSide() {
    #expect(DisplayCornerProfileResolver.clampedFraction(-0.1) == 0)
    #expect(DisplayCornerProfileResolver.clampedFraction(0.5) == 0.2)
    let radius = DisplayCornerProfileResolver.cornerRadius(shortSide: 400, fraction: 0.14)
    #expect(abs(radius - 56) < 0.000_001)
    #expect(DisplayCornerProfileResolver.cornerRadius(shortSide: 0, fraction: 0.14) == 0)
  }

  @Test func bundledCatalogIncludesCorroboratedVariantsAndOldSquareDisplays() {
    let profiles = DisplayCornerProfileResolver.modelProfiles
    #expect(profiles.count == 164)
    #expect(profiles.keys.filter { $0.hasPrefix("iPhone") }.count == 60)
    #expect(profiles.keys.filter { $0.hasPrefix("iPad") }.count == 104)
    for identifiers in [
      ["iPhone10,3", "iPhone10,6"], ["iPhone11,4", "iPhone11,6"],
      ["iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11"],
      ["iPad16,3", "iPad16,4"], ["iPad16,5", "iPad16,6"],
      ["iPad15,3", "iPad15,4"], ["iPad15,5", "iPad15,6"],
    ] {
      let reference = profiles[identifiers[0]]
      #expect(reference != nil)
      for identifier in identifiers {
        #expect(profiles[identifier]?.fraction == reference?.fraction)
        #expect(profiles[identifier]?.name == reference?.name)
      }
    }
    for identifier in ["iPhone6,1", "iPhone7,2", "iPad4,7", "iPad6,7"] {
      let profile = DisplayCornerProfileResolver.automaticProfile(
        for: DisplayDevice(id: "fixture", name: "Renamed device", productType: identifier))
      #expect(profile.source == .modelMatch)
      #expect(profile.fraction == 0)
    }
  }

  @Test func reviewedConflictsCannotReintroduceIncorrectIPadCorners() {
    let profiles = DisplayCornerProfileResolver.modelProfiles
    for identifier in ["iPad11,3", "iPad11,4"] {
      #expect(profiles[identifier]?.fraction == 0)
      #expect(profiles[identifier]?.name == "iPad Air (3rd generation)")
    }
    for identifier in ["iPad16,8", "iPad16,9"] {
      #expect(profiles[identifier]?.fraction == 18.0 / 820)
      #expect(profiles[identifier]?.name == "iPad Air (11-inch) (M4)")
    }
    #expect(profiles["iPhone13,2"]?.fraction == 47.0 / 390)
    #expect(profiles["iPhone13,3"]?.fraction == 47.0 / 390)
    #expect(profiles["iPhone13,4"]?.fraction == 53.0 / 428)
    for identifier in ["iPad13,12", "iPad16,7"] {
      #expect(profiles[identifier] == nil)
    }
  }

  @Test func everyBundledProfileNormalizesInBothOrientations() {
    for reference in DisplayCornerProfileResolver.modelProfiles.values {
      let device = DisplayDevice(id: "fixture", name: "Renamed", productType: reference.productType)
      let portrait = DisplayCornerProfileResolver.automaticFraction(for: device, aspectRatio: 0.5)
      let landscape = DisplayCornerProfileResolver.automaticFraction(for: device, aspectRatio: 2)
      #expect(portrait == landscape)
      #expect(portrait.isFinite && (0...0.2).contains(portrait))
      #expect(
        DisplayCornerProfileResolver.cornerRadius(shortSide: 300, fraction: portrait)
          == 300 * reference.fraction)
    }
  }

  @Test func rejectsBrokenCatalogVersionsDuplicatesAndGeometry() throws {
    let valid: [String: Any] = [
      "productType": "iPhone17,1", "name": "iPhone 16 Pro", "radius": 62,
      "shortSide": 402, "reference": "Test reference",
    ]
    func data(_ profiles: [[String: Any]], version: Int = 1) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["schemaVersion": version, "profiles": profiles])
    }
    #expect(try DisplayCornerProfileResolver.loadProfiles(from: data([valid])).count == 1)
    for bytes in try [data([valid], version: 2), data([]), data([valid, valid])] {
      #expect(throws: DeviceCornerCatalogError.self) {
        try DisplayCornerProfileResolver.loadProfiles(from: bytes)
      }
    }
    for (key, value) in [
      ("productType", "iPhone" as Any), ("radius", -1), ("radius", 500),
      ("shortSide", 0), ("shortSide", NSNull()), ("name", ""), ("reference", ""),
    ] {
      var invalid = valid
      invalid[key] = value
      let bytes = try data([invalid])
      #expect(throws: DeviceCornerCatalogError.self) {
        try DisplayCornerProfileResolver.loadProfiles(from: bytes)
      }
    }
  }
}
