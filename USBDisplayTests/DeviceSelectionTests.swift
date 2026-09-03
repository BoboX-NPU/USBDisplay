import Testing

@testable import iPhoneUSBDisplay

struct DeviceSelectionTests {
  @Test
  func filtersForAppleMuxedExternalDevices() {
    let eligible = CaptureDeviceDescriptor(
      isExternal: true,
      hasMuxedMedia: true,
      manufacturer: "Apple Inc."
    )

    #expect(CaptureDeviceFilter.isEligible(eligible))
    #expect(
      !CaptureDeviceFilter.isEligible(
        .init(
          isExternal: false,
          hasMuxedMedia: true,
          manufacturer: "Apple Inc."
        )))
    #expect(
      !CaptureDeviceFilter.isEligible(
        .init(
          isExternal: true,
          hasMuxedMedia: false,
          manufacturer: "Apple Inc."
        )))
    #expect(
      !CaptureDeviceFilter.isEligible(
        .init(
          isExternal: true,
          hasMuxedMedia: true,
          manufacturer: "Third Party"
        )))
  }

}
