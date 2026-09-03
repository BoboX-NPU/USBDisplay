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

  @Test
  func automaticallySelectsOnlyDevice() {
    let device = DisplayDevice(id: "one", name: "One iPad")
    let selectedID = DeviceSelectionPolicy.selectedID(
      devices: [device],
      currentID: nil,
      lastSelectedID: nil
    )

    #expect(selectedID == device.id)
  }

  @Test
  func preservesCurrentSelectionWithMultipleDevices() {
    let devices = [
      DisplayDevice(id: "one", name: "One iPhone"),
      DisplayDevice(id: "two", name: "One iPad"),
    ]

    #expect(
      DeviceSelectionPolicy.selectedID(
        devices: devices,
        currentID: "two",
        lastSelectedID: "one"
      ) == "two")
  }

  @Test
  func reconnectsLastSelectedDeviceWhenItReturns() {
    let devices = [
      DisplayDevice(id: "one", name: "One iPhone"),
      DisplayDevice(id: "two", name: "One iPad"),
    ]

    #expect(
      DeviceSelectionPolicy.selectedID(
        devices: devices,
        currentID: nil,
        lastSelectedID: "two"
      ) == "two")
  }

  @Test
  func requiresSelectionForUnknownMultipleDevices() {
    let devices = [
      DisplayDevice(id: "one", name: "One iPhone"),
      DisplayDevice(id: "two", name: "Two iPhone"),
    ]

    #expect(
      DeviceSelectionPolicy.selectedID(
        devices: devices,
        currentID: nil,
        lastSelectedID: nil
      ) == nil)
  }

  @Test
  func repeatedEmptyRefreshDoesNotInventAnInterruption() {
    #expect(
      DeviceAbsenceStatusPolicy.status(
        previousSelectedName: nil,
        currentStatus: .noDevice
      ) == .noDevice)
  }

  @Test
  func interruptedStatePersistsWhileWaitingForReconnect() {
    #expect(
      DeviceAbsenceStatusPolicy.status(
        previousSelectedName: nil,
        currentStatus: .interrupted(deviceName: "Test iPhone")
      ) == .interrupted(deviceName: "Test iPhone"))
  }
}
