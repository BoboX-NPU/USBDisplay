import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct ControlAutoHidePolicyTests {
  @Test
  func controlsHideAfterThreeConnectedSeconds() {
    let policy = ControlAutoHidePolicy()
    let activity = Date(timeIntervalSince1970: 100)

    #expect(
      !policy.shouldHideControls(
        lastActivity: activity,
        now: Date(timeIntervalSince1970: 102.99),
        isConnected: true
      ))
    #expect(
      policy.shouldHideControls(
        lastActivity: activity,
        now: Date(timeIntervalSince1970: 103),
        isConnected: true
      ))
    #expect(
      !policy.shouldHideControls(
        lastActivity: activity,
        now: Date(timeIntervalSince1970: 110),
        isConnected: false
      ))
  }

  @Test
  func cursorOnlyHidesWithConnectedFullScreenControls() {
    let policy = ControlAutoHidePolicy()

    #expect(
      policy.shouldHideCursor(
        controlsHidden: true,
        isConnected: true,
        isFullScreen: true
      ))
    #expect(
      !policy.shouldHideCursor(
        controlsHidden: true,
        isConnected: true,
        isFullScreen: false
      ))
    #expect(
      !policy.shouldHideCursor(
        controlsHidden: false,
        isConnected: true,
        isFullScreen: true
      ))
  }
}
