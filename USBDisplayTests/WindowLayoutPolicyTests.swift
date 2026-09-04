import AppKit
import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct WindowLayoutPolicyTests {
  @Test
  func rejectsInvalidAspectRatios() {
    #expect(WindowLayoutPolicy.validAspectRatio(width: 0, height: 10) == nil)
    #expect(WindowLayoutPolicy.validAspectRatio(width: 10, height: 0) == nil)
    #expect(WindowLayoutPolicy.validAspectRatio(width: .infinity, height: 10) == nil)
  }

  @Test
  func portraitPreviewFillsVisibleDetailAtExactRatio() {
    let size = WindowLayoutPolicy.contentSize(
      previewHeight: 640,
      aspectRatio: 9.0 / 16.0,
      sidebarWidth: 220,
      sidebarIsVisible: true
    )

    #expect(size == WindowContentSize(width: 581, height: 640))
  }

  @Test
  func landscapePreviewFillsVisibleDetailAtExactRatio() {
    let size = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 16.0 / 9.0,
      sidebarWidth: 220,
      sidebarIsVisible: true
    )

    #expect(size == WindowContentSize(width: 1287.6666666666665, height: 600))
  }

  @Test
  func hiddenSidebarRemovesItsEntireContribution() {
    let size = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: false
    )

    #expect(size == WindowContentSize(width: 800, height: 600))
  }

  @Test
  func showingSidebarAddsWidthWithoutChangingPreviewSize() {
    let hiddenSize = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: false
    )
    let visibleSize = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: true
    )

    #expect(hiddenSize == WindowContentSize(width: 800, height: 600))
    #expect(visibleSize == WindowContentSize(width: 1021, height: 600))
  }

  @Test
  func changingSidebarWidthChangesOnlyOuterWidth() {
    let narrowSize = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 180,
      sidebarIsVisible: true
    )
    let wideSize = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 280,
      sidebarIsVisible: true
    )

    #expect(narrowSize == WindowContentSize(width: 981, height: 600))
    #expect(wideSize == WindowContentSize(width: 1081, height: 600))
  }

  @Test
  func deviceChangePreservesHeightWhenItFits() {
    let size = WindowLayoutPolicy.sizePreservingHeight(
      currentHeight: 600,
      aspectRatio: 9.0 / 16.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 1400, height: 900)
    )

    #expect(size == WindowContentSize(width: 558.5, height: 600))
  }

  @Test
  func deviceChangeShrinksToVisibleBounds() {
    let size = WindowLayoutPolicy.sizePreservingHeight(
      currentHeight: 900,
      aspectRatio: 16.0 / 9.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 1200, height: 700)
    )

    #expect(abs((size?.width ?? 0) - 1200) < 0.001)
    #expect(abs((size?.height ?? 0) - 550.6875) < 0.001)
  }

  @Test
  func visibleBoundsOverrideNominalMinimumPreviewHeight() {
    let size = WindowLayoutPolicy.sizePreservingHeight(
      currentHeight: WindowLayoutPolicy.minimumPreviewHeight,
      aspectRatio: 16.0 / 9.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 700, height: 600)
    )

    #expect(abs((size?.width ?? 0) - 700) < 0.001)
    #expect(abs((size?.height ?? 0) - 269.4375) < 0.001)
  }

  @Test
  func widthDrivenResizeAdjustsHeight() {
    let size = WindowLayoutPolicy.constrainedResize(
      proposedSize: WindowContentSize(width: 1021, height: 600),
      previousSize: WindowContentSize(width: 821, height: 600),
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 1600, height: 1000)
    )

    #expect(size == WindowContentSize(width: 1021, height: 600))
  }

  @Test
  func heightDrivenResizeAdjustsWidth() {
    let size = WindowLayoutPolicy.constrainedResize(
      proposedSize: WindowContentSize(width: 821, height: 700),
      previousSize: WindowContentSize(width: 821, height: 600),
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 1600, height: 1000)
    )

    #expect(abs((size?.width ?? 0) - 1154.3333333333333) < 0.001)
    #expect(size?.height == 700)
  }

  @Test
  func fullScreenDoesNotConstrainWindow() {
    #expect(!WindowLayoutPolicy.shouldConstrainWindow(isFullScreen: true, aspectRatio: 4.0 / 3.0))
    #expect(!WindowLayoutPolicy.shouldConstrainWindow(isFullScreen: false, aspectRatio: nil))
    #expect(WindowLayoutPolicy.shouldConstrainWindow(isFullScreen: false, aspectRatio: 4.0 / 3.0))
  }

  @Test
  func expandedSidebarUsesPersistentNativeChrome() {
    var state = WindowChromeVisibilityState(sidebarIsVisible: true)

    #expect(state.mode == .sidebarVisible)
    #expect(state.showsTitlebar)
    let shouldScheduleHide = state.pointerExitedRevealRegion()
    #expect(!shouldScheduleHide)
    #expect(state.mode == .sidebarVisible)
  }

  @Test
  func collapsedSidebarStartsWithCompactChrome() {
    let state = WindowChromeVisibilityState(sidebarIsVisible: false)

    #expect(state.mode == .compact)
    #expect(!state.showsTitlebar)
  }

  @Test
  func enteringTopRegionRevealsNativeChromeImmediately() {
    var state = WindowChromeVisibilityState(sidebarIsVisible: false)

    state.pointerEnteredTopRegion()

    #expect(state.mode == .hoverRevealed)
    #expect(state.showsTitlebar)
    #expect(!state.hideIsPending)
  }

  @Test
  func exitingRevealRegionKeepsChromeUntilDelayElapses() {
    var state = WindowChromeVisibilityState(sidebarIsVisible: false)
    state.pointerEnteredTopRegion()

    let shouldScheduleHide = state.pointerExitedRevealRegion()
    #expect(shouldScheduleHide)
    #expect(state.hideIsPending)
    #expect(state.mode == .hoverRevealed)

    state.hideDelayElapsed()

    #expect(!state.hideIsPending)
    #expect(state.mode == .compact)
    #expect(!state.showsTitlebar)
  }

  @Test
  func reenteringRevealRegionCancelsPendingHide() {
    var state = WindowChromeVisibilityState(sidebarIsVisible: false)
    state.pointerEnteredTopRegion()
    _ = state.pointerExitedRevealRegion()

    state.pointerEnteredTopRegion()

    #expect(!state.hideIsPending)
    #expect(state.mode == .hoverRevealed)
  }

  @Test
  func expandingSidebarCancelsPendingHideAndKeepsChromeVisible() {
    var state = WindowChromeVisibilityState(sidebarIsVisible: false)
    state.pointerEnteredTopRegion()
    _ = state.pointerExitedRevealRegion()

    state.updateSidebarVisibility(true)

    #expect(!state.hideIsPending)
    #expect(state.mode == .sidebarVisible)
    #expect(state.showsTitlebar)
  }

  @Test
  func rapidlyLeavingAndReenteringKeepsHoverChromeRevealed() {
    var state = WindowChromeVisibilityState(sidebarIsVisible: false)
    state.pointerEnteredTopRegion()
    _ = state.pointerExitedRevealRegion()
    state.pointerEnteredTopRegion()
    _ = state.pointerExitedRevealRegion()
    state.pointerEnteredTopRegion()

    #expect(!state.hideIsPending)
    #expect(state.mode == .hoverRevealed)
  }

}

struct WindowGeometryStateTests {
  private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

  @Test
  func repeatedChromeChangesPreservePreviewAndRestoreOriginalFrame() throws {
    var state = WindowGeometryState()
    let compact = CGRect(x: 400, y: 100, width: 300, height: 600)
    state.rememberUserGeometry(frame: compact, sidebar: 0, titlebar: 0)
    for _ in 0..<20 {
      let expanded = try #require(
        state.frame(aspectRatio: 0.5, sidebar: 221, titlebar: 52, visibleFrame: screen))
      #expect(expanded == CGRect(x: 179, y: 100, width: 521, height: 652))
      let hover = state.frame(aspectRatio: 0.5, sidebar: 0, titlebar: 52, visibleFrame: screen)
      #expect(hover == CGRect(x: 400, y: 100, width: 300, height: 652))
      #expect(
        state.frame(aspectRatio: 0.5, sidebar: 0, titlebar: 0, visibleFrame: screen) == compact)
    }
  }

  @Test
  func screenFittingDoesNotOverwriteUserSize() throws {
    var state = WindowGeometryState()
    let smallScreen = CGRect(x: -600, y: 0, width: 600, height: 700)
    let compact = CGRect(x: -600, y: 0, width: 600, height: 600)
    state.rememberUserGeometry(frame: compact, sidebar: 0, titlebar: 0)
    let expanded = try #require(
      state.frame(aspectRatio: 1, sidebar: 221, titlebar: 52, visibleFrame: smallScreen))
    #expect(expanded.width == 600)
    #expect(expanded.height == 431)
    #expect(
      state.frame(aspectRatio: 1, sidebar: 0, titlebar: 0, visibleFrame: smallScreen) == compact)
    state.rememberUserGeometry(frame: expanded, sidebar: 221, titlebar: 52)
    #expect(
      state.frame(aspectRatio: 1, sidebar: 0, titlebar: 0, visibleFrame: smallScreen)?.height == 379
    )
  }

  @Test
  func orientationAndIndependentWindowsKeepIntendedHeight() throws {
    var phone = WindowGeometryState()
    phone.rememberUserGeometry(
      frame: CGRect(x: 300, y: 100, width: 300, height: 600), sidebar: 0, titlebar: 0)
    var tablet = phone
    tablet.rememberUserGeometry(
      frame: CGRect(x: 500, y: 200, width: 400, height: 400), sidebar: 0, titlebar: 0)
    let landscape = try #require(
      phone.frame(aspectRatio: 2, sidebar: 0, titlebar: 0, visibleFrame: screen))
    #expect(landscape.height == 600)
    #expect(landscape.width == 1200)
    #expect(tablet.previewRect?.height == 400)
    #expect(phone.previewRect?.height == 600)
  }

  @Test
  func movingAConstrainedWindowPreservesItsPreferredScale() {
    var state = WindowGeometryState()
    state.rememberUserGeometry(
      frame: CGRect(x: 300, y: 100, width: 300, height: 600), sidebar: 0, titlebar: 0)
    state.move(by: CGSize(width: 40, height: 10))
    #expect(state.previewRect == CGRect(x: 340, y: 110, width: 300, height: 600))
  }
}

@Suite(.serialized)
@MainActor
struct WindowLayoutIntegrationTests {
  private func configuration(sidebar: Bool) -> WindowLayoutConfiguration {
    WindowLayoutConfiguration(
      title: "Layout Test", aspectRatio: 0.5, sidebarWidth: 220,
      sidebarIsVisible: sidebar, cornerRadiusFraction: 0
    )
  }

  private func makeWindow() -> (NSWindow, WindowLayoutHostView) {
    let window = NSWindow(
      contentRect: CGRect(x: 450, y: 200, width: 521, height: 600),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
    )
    window.isReleasedWhenClosed = false
    let host = WindowLayoutHostView(
      configuration: configuration(sidebar: true), onRestoreSidebarAfterFullScreen: { _ in })
    window.contentView?.addSubview(host)
    return (window, host)
  }

  private func settle() async throws {
    try await Task.sleep(for: .milliseconds(250))
  }

  @Test
  func sidebarRoundTripsAndRapidInterruptionsKeepStableSize() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await settle()
    let expanded = window.frame
    for _ in 0..<20 {
      host.updateConfiguration(configuration(sidebar: false))
      try await settle()
      host.updateConfiguration(configuration(sidebar: true))
      try await settle()
      #expect(abs(window.frame.width - expanded.width) < 1)
      #expect(abs(window.frame.height - expanded.height) < 1)
    }
    host.updateConfiguration(configuration(sidebar: false))
    NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: window)
    let desired = try #require(
      window.delegate?.windowWillResize?(window, to: CGSize(width: 280, height: 560)))
    window.setFrame(CGRect(origin: window.frame.origin, size: desired), display: false)
    NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
    let released = window.frame
    try await settle()
    #expect(abs(window.frame.width - released.width) < 1)
    #expect(abs(window.frame.height - released.height) < 1)
    host.updateConfiguration(configuration(sidebar: true))
    try await settle()
    host.updateConfiguration(configuration(sidebar: false))
    try await settle()
    #expect(abs(window.frame.width - released.width) < 1)
    #expect(abs(window.frame.height - released.height) < 1)
  }

  @Test
  func resizeDelegateConstrainsAllHandlesWithoutReleaseCorrection() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await settle()
    let titlebar = window.frame.height - window.contentLayoutRect.height
    for delta in [
      CGSize(width: 30, height: 0), CGSize(width: -30, height: 0),
      CGSize(width: 0, height: 40), CGSize(width: 0, height: -40),
      CGSize(width: 30, height: 40), CGSize(width: -30, height: 40),
      CGSize(width: 30, height: -40), CGSize(width: -30, height: -40),
    ] {
      NotificationCenter.default.post(
        name: NSWindow.willStartLiveResizeNotification, object: window)
      let desired = try #require(
        window.delegate?.windowWillResize?(
          window,
          to: CGSize(
            width: window.frame.width + delta.width, height: window.frame.height + delta.height
          )))
      #expect(abs((desired.width - 221) / (desired.height - titlebar) - 0.5) < 0.001)
      window.setFrame(CGRect(origin: window.frame.origin, size: desired), display: false)
      NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
      let released = window.frame
      try await settle()
      #expect(abs(window.frame.width - released.width) < 1)
      #expect(abs(window.frame.height - released.height) < 1)
    }
  }

  @Test
  func compactSafeAreaSignalFollowsChromeAndFullScreen() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    var compact = false
    host.onCompactPresentationChanged = { compact = $0 }
    try await settle()
    host.updateConfiguration(configuration(sidebar: false))
    try await settle()
    #expect(compact)
    let normalFrame = window.frame
    NotificationCenter.default.post(name: NSWindow.willEnterFullScreenNotification, object: window)
    try await settle()
    #expect(!compact)
    window.setFrame(CGRect(x: 0, y: 0, width: 1000, height: 800), display: false)
    NotificationCenter.default.post(name: NSWindow.didExitFullScreenNotification, object: window)
    try await settle()
    #expect(compact)
    #expect(abs(window.frame.width - normalFrame.width) < 1)
    #expect(abs(window.frame.height - normalFrame.height) < 1)
  }

  @Test
  func proxyForwardsOriginalLifecycleAndResizeDecisions() throws {
    let original = OriginalWindowDelegate()
    let proxy = WindowResizeDelegate()
    proxy.originalDelegate = original
    let window = NSWindow()
    window.isReleasedWhenClosed = false
    defer { window.close() }
    proxy.constrain = { _, size in CGSize(width: size.width, height: 400) }
    #expect(
      proxy.windowWillResize(window, to: CGSize(width: 100, height: 100))
        == CGSize(width: 120, height: 400))
    let selector = #selector(NSWindowDelegate.windowShouldClose(_:))
    #expect(proxy.responds(to: selector))
    #expect(proxy.forwardingTarget(for: selector) as AnyObject === original)
  }
}

@MainActor
private final class OriginalWindowDelegate: NSObject, NSWindowDelegate {
  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    CGSize(width: frameSize.width + 20, height: frameSize.height)
  }
  func windowShouldClose(_ sender: NSWindow) -> Bool { false }
}
