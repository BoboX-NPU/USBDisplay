import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct DeviceWindowRoutingTests {
  @Test
  func firstDeviceSwitchesIntoUnassignedWindow() {
    #expect(
      DeviceWindowRoutingPolicy.route(
        currentDeviceID: nil,
        selectedDeviceID: "iphone",
        selectedDeviceIsClaimedElsewhere: false
      ) == .switchCurrentWindow(deviceID: "iphone")
    )
  }

  @Test
  func currentDeviceKeepsItsWindow() {
    #expect(
      DeviceWindowRoutingPolicy.route(
        currentDeviceID: "iphone",
        selectedDeviceID: "iphone",
        selectedDeviceIsClaimedElsewhere: false
      ) == .keepCurrentWindow
    )
  }

  @Test
  func unclaimedDeviceSwitchesInCurrentWindow() {
    #expect(
      DeviceWindowRoutingPolicy.route(
        currentDeviceID: "iphone",
        selectedDeviceID: "ipad",
        selectedDeviceIsClaimedElsewhere: false
      ) == .switchCurrentWindow(deviceID: "ipad")
    )
  }

  @Test
  func claimedDeviceFocusesExistingWindow() {
    #expect(
      DeviceWindowRoutingPolicy.route(
        currentDeviceID: "iphone",
        selectedDeviceID: "ipad",
        selectedDeviceIsClaimedElsewhere: true
      ) == .focusExistingWindow(deviceID: "ipad")
    )
  }

  @Test @MainActor
  func oneDeviceCanOnlyBeClaimedByOneWindow() {
    let registry = DeviceWindowRegistry()
    let firstWindow = UUID()
    let secondWindow = UUID()

    #expect(registry.claim(deviceID: "iphone", windowID: firstWindow))
    #expect(!registry.claim(deviceID: "iphone", windowID: secondWindow))
    #expect(registry.isClaimed("iphone", byAnotherWindowThan: secondWindow))
    #expect(!registry.isClaimed("iphone", byAnotherWindowThan: firstWindow))

    registry.release(deviceID: "iphone", windowID: firstWindow)
    #expect(registry.claim(deviceID: "iphone", windowID: secondWindow))
  }

  @Test @MainActor
  func transferClaimsNewDeviceAndReleasesOldDevice() {
    let registry = DeviceWindowRegistry()
    let window = UUID()
    let otherWindow = UUID()

    #expect(registry.claim(deviceID: "iphone", windowID: window))
    #expect(
      registry.transfer(
        from: "iphone",
        to: "ipad",
        windowID: window
      ))
    #expect(!registry.isClaimed("iphone", byAnotherWindowThan: otherWindow))
    #expect(registry.isClaimed("ipad", byAnotherWindowThan: otherWindow))
  }

  @Test @MainActor
  func failedTransferPreservesCurrentDeviceOwnership() {
    let registry = DeviceWindowRegistry()
    let firstWindow = UUID()
    let secondWindow = UUID()

    #expect(registry.claim(deviceID: "iphone", windowID: firstWindow))
    #expect(registry.claim(deviceID: "ipad", windowID: secondWindow))
    #expect(
      !registry.transfer(
        from: "iphone",
        to: "ipad",
        windowID: firstWindow
      ))
    #expect(registry.isClaimed("iphone", byAnotherWindowThan: secondWindow))
  }
}
