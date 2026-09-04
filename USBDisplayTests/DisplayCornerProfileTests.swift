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
    for modelID in ["", "iPhone", "iPhone99,1", "iPad16,5", "prefix-iPhone17,1"] {
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
}
