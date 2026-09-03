import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct DeviceWindowRoutingTests {
  @Test
  func firstDeviceUsesUnassignedWindow() {
    #expect(
      DeviceWindowRoutingPolicy.route(
        currentDeviceID: nil,
        selectedDeviceID: "iphone"
      ) == .assignCurrentWindow(deviceID: "iphone")
    )
  }

  @Test
  func currentDeviceKeepsItsWindow() {
    #expect(
      DeviceWindowRoutingPolicy.route(
        currentDeviceID: "iphone",
        selectedDeviceID: "iphone"
      ) == .keepCurrentWindow
    )
  }

  @Test
  func anotherDeviceOpensItsOwnWindow() {
    #expect(
      DeviceWindowRoutingPolicy.route(
        currentDeviceID: "iphone",
        selectedDeviceID: "ipad"
      ) == .openDeviceWindow(deviceID: "ipad")
    )
  }

  @Test @MainActor
  func oneDeviceCanOnlyBeClaimedByOneWindow() {
    let registry = DeviceWindowRegistry()
    let firstWindow = UUID()
    let secondWindow = UUID()

    #expect(registry.claim(deviceID: "iphone", windowID: firstWindow))
    #expect(!registry.claim(deviceID: "iphone", windowID: secondWindow))
    #expect(registry.isClaimed("iphone"))

    registry.release(deviceID: "iphone", windowID: firstWindow)
    #expect(registry.claim(deviceID: "iphone", windowID: secondWindow))
  }
}
