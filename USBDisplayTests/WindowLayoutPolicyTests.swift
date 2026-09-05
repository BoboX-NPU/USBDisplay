import AppKit
import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct WindowLayoutPolicyTests {
  @Test
  func placeholderKeepsThirtySeventySplitAndFitsSmallScreens() {
    let screen = CGRect(x: -1440, y: 25, width: 1440, height: 900)
    for width in [238.0, 720, 980, 1200.5, 1600] {
      let proposed = CGRect(x: screen.minX + 100, y: 700, width: width, height: 300)
      let frame = WindowLayoutPolicy.placeholderFrame(proposed, screen: screen)
      let layout = WindowSurfaceLayout.placeholder(
        frame: frame, sidebarIsVisible: true, titlebar: 52)
      #expect(screen.contains(frame))
      #expect(frame.width >= 720)
      #expect(frame.height >= 480)
      #expect(abs(layout.sidebar.width - frame.width * 0.3) <= 0.5)
      #expect(abs(layout.preview.width - frame.width * 0.7) <= 0.5)
      #expect(layout.sidebar.maxX == layout.preview.minX)
      #expect(layout.preview.maxX == frame.width)
      let hidden = WindowSurfaceLayout.placeholder(
        frame: frame, sidebarIsVisible: false, titlebar: 0)
      #expect(hidden.preview.size == frame.size)
    }
    let smallScreen = CGRect(x: 100, y: 50, width: 600, height: 400)
    #expect(WindowLayoutPolicy.placeholderFrame(.zero, screen: smallScreen) == smallScreen)
  }

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
    var session = ResizeSession(
      frame: CGRect(x: 0, y: 0, width: 821, height: 600), aspectRatio: 4.0 / 3.0,
      externalSidebar: 221, externalTitlebar: 0, strategy: .width)
    let size = session.constrain(
      CGSize(width: 1021, height: 600),
      maximumSize: CGSize(width: 1600, height: 1000))
    #expect(size == CGSize(width: 1021, height: 600))
  }

  @Test
  func heightDrivenResizeAdjustsWidth() {
    var session = ResizeSession(
      frame: CGRect(x: 0, y: 0, width: 821, height: 600), aspectRatio: 4.0 / 3.0,
      externalSidebar: 221, externalTitlebar: 0, strategy: .height)
    let size = session.constrain(
      CGSize(width: 821, height: 700),
      maximumSize: CGSize(width: 1600, height: 1000))
    #expect(abs(size.width - 1154.3333333333333) < 0.001)
    #expect(size.height == 700)
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

  @Test func chromeAddsSpaceWithoutChangingPreview() throws {
    var state = WindowGeometryState()
    let preview = CGRect(x: 400, y: 100, width: 300, height: 600)
    state.rememberPreview(preview)
    for _ in 0..<20 {
      for sidebar in [0.0, 221.0] {
        for titlebar in [0.0, 52.0] {
          let layout = try #require(
            state.layout(sidebar: sidebar, titlebar: titlebar, screen: screen))
          #expect(layout.previewOnScreen == preview)
          #expect(
            layout.frame
              == CGRect(x: 400 - sidebar, y: 100, width: 300 + sidebar, height: 600 + titlebar))
        }
      }
    }
  }

  @Test func edgeTranslationAndOverlayNeverScalePreview() throws {
    let screens = [screen, CGRect(x: -600, y: -100, width: 600, height: 650)]
    for screen in screens {
      for size in [
        CGSize(width: 300, height: 600), CGSize(width: screen.width, height: screen.height),
      ] {
        for origin in [
          screen.origin, CGPoint(x: screen.maxX - size.width, y: screen.maxY - size.height),
        ] {
          var state = WindowGeometryState()
          let preview = CGRect(origin: origin, size: size)
          state.rememberPreview(preview)
          let layout = try #require(state.layout(sidebar: 221, titlebar: 52, screen: screen))
          #expect(layout.preview.size == size)
          #expect(screen.contains(layout.frame))
          if size.width + 221 > screen.width { #expect(layout.externalSidebar == 0) }
          if size.height + 52 > screen.height { #expect(layout.externalTitlebar == 0) }
          #expect(state.layout(sidebar: 0, titlebar: 0, screen: screen)?.previewOnScreen == preview)
        }
      }
    }
  }

  @Test func rotationRetainsPreferredHeightAndWindowsRemainIndependent() throws {
    var phone = WindowGeometryState()
    phone.rememberPreview(CGRect(x: 300, y: 100, width: 300, height: 600))
    var tablet = phone
    tablet.rememberPreview(CGRect(x: 500, y: 200, width: 400, height: 400))
    phone.orient(aspectRatio: 3, screen: screen)
    #expect(phone.previewRect?.size == CGSize(width: 1440, height: 480))
    phone.orient(aspectRatio: 0.5, screen: screen)
    #expect(phone.previewRect?.size == CGSize(width: 300, height: 600))
    #expect(tablet.previewRect?.height == 400)
    phone.move(by: CGSize(width: 40, height: 10))
    #expect(phone.previewRect?.origin == CGPoint(x: 340, y: 110))
  }
}

@Suite(.serialized)
@MainActor
struct WindowLayoutIntegrationTests {
  private func configuration(
    sidebar: Bool, fraction: Double = 0, aspectRatio: Double? = 0.5
  ) -> WindowLayoutConfiguration {
    WindowLayoutConfiguration(
      title: "Layout Test", aspectRatio: aspectRatio, sidebarWidth: 220,
      sidebarIsVisible: sidebar, cornerRadiusFraction: fraction)
  }

  private func makeWindow(aspectRatio: Double? = 0.5) -> (NSWindow, WindowLayoutHostView) {
    let screen = NSScreen.main!.visibleFrame
    let window = NSWindow(
      contentRect: CGRect(x: screen.midX - 200, y: screen.minY + 100, width: 471, height: 500),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let host = WindowLayoutHostView(
      configuration: configuration(sidebar: true, aspectRatio: aspectRatio), animatesChrome: false)
    window.contentView = host
    return (window, host)
  }

  private func screenRect(_ host: WindowLayoutHostView) -> CGRect {
    host.window!.convertToScreen(host.preview.convert(host.preview.bounds, to: nil))
  }

  @Test func emptyWindowRepairsNarrowRestorationAndResizesWithBalancedContent() async throws {
    let (window, host) = makeWindow(aspectRatio: nil)
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    #expect(window.frame.width >= 720)
    #expect(window.minSize.width == WindowLayoutPolicy.minimumPlaceholderSize.width)
    #expect(window.minSize.height >= WindowLayoutPolicy.minimumPlaceholderSize.height)

    // SwiftUI restoration can arrive after the native host attaches.
    window.setFrame(
      CGRect(x: window.frame.minX, y: window.frame.minY, width: 238, height: 516), display: false)
    #expect(window.frame.width >= 720)
    NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: window)
    for proposal in [
      CGSize(width: 900, height: 600), CGSize(width: 800, height: 700),
      CGSize(width: 760, height: 500),
    ] {
      let accepted = try #require(window.delegate?.windowWillResize?(window, to: proposal))
      #expect(accepted == proposal)
      window.setFrame(CGRect(origin: window.frame.origin, size: accepted), display: false)
      let layout = try #require(host.surfaceLayout)
      #expect(abs(layout.sidebar.width / window.frame.width - 0.3) < 0.001)
      #expect(abs(screenRect(host).width / window.frame.width - 0.7) < 0.001)
    }
    let released = window.frame
    NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
    #expect(window.frame == released)
    host.updateConfiguration(configuration(sidebar: false, aspectRatio: nil))
    #expect(screenRect(host).size == window.frame.size)
    host.updateConfiguration(configuration(sidebar: true, aspectRatio: nil))
    #expect(window.frame == released)
  }

  @Test func emptyAndConnectedWindowsRetainIndependentSizes() async throws {
    let (window, host) = makeWindow(aspectRatio: nil)
    let (otherWindow, otherHost) = makeWindow(aspectRatio: nil)
    defer {
      host.prepareForRemoval()
      otherHost.prepareForRemoval()
      window.close()
      otherWindow.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let empty = window.frame
    let other = otherWindow.frame
    host.updateConfiguration(configuration(sidebar: true))
    let connected = window.frame
    let preview = screenRect(host)
    #expect(abs(preview.width / preview.height - 0.5) < 0.001)
    #expect(window.minSize.width < 720)
    #expect(host.surfaceLayout?.sidebar.width == 221)
    for _ in 0..<5 {
      host.updateConfiguration(configuration(sidebar: true, aspectRatio: nil))
      #expect(window.frame == empty)
      #expect(abs(screenRect(host).width / window.frame.width - 0.7) < 0.001)
      host.updateConfiguration(configuration(sidebar: true))
      #expect(window.frame == connected)
      #expect(screenRect(host) == preview)
      #expect(otherWindow.frame == other)
    }
  }

  @Test func deviceConnectingDuringEmptyResizeWaitsForRelease() async throws {
    let (window, host) = makeWindow(aspectRatio: nil)
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: window)
    let empty = window.frame
    host.updateConfiguration(configuration(sidebar: true))
    #expect(window.frame == empty)
    let proposal = CGSize(width: 900, height: 600)
    let accepted = try #require(window.delegate?.windowWillResize?(window, to: proposal))
    #expect(accepted == proposal)
    window.setFrame(CGRect(origin: empty.origin, size: accepted), display: false)
    #expect(abs(screenRect(host).width / window.frame.width - 0.7) < 0.001)
    NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
    let preview = screenRect(host)
    #expect(abs(preview.width / preview.height - 0.5) < 0.001)
    host.updateConfiguration(configuration(sidebar: true, aspectRatio: nil))
    #expect(window.frame.size == proposal)
  }

  @Test func emptyFullScreenRoundTripRestoresOrdinarySizeIncludingDeviceArrival() async throws {
    let (window, host) = makeWindow(aspectRatio: nil)
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let empty = window.frame
    for connectDuringTransition in [false, true] {
      NotificationCenter.default.post(
        name: NSWindow.willEnterFullScreenNotification, object: window)
      window.setFrame(CGRect(x: 0, y: 0, width: 1000, height: 800), display: false)
      if connectDuringTransition { host.updateConfiguration(configuration(sidebar: true)) }
      NotificationCenter.default.post(name: NSWindow.didEnterFullScreenNotification, object: window)
      NotificationCenter.default.post(name: NSWindow.willExitFullScreenNotification, object: window)
      NotificationCenter.default.post(name: NSWindow.didExitFullScreenNotification, object: window)
      if connectDuringTransition {
        let preview = screenRect(host)
        #expect(abs(preview.width / preview.height - 0.5) < 0.001)
        #expect(window.frame.height == empty.height)
        host.updateConfiguration(configuration(sidebar: true, aspectRatio: nil))
      }
      #expect(window.frame == empty)
      #expect(abs(screenRect(host).width / window.frame.width - 0.7) < 0.001)
    }
  }

  @Test func everyChromeLayoutKeepsActualPreviewRectAndLayerIdentity() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let expected = screenRect(host)
    let layer = host.preview.layer?.sublayers?.first
    var samples: [CGRect] = []
    host.preview.onGeometryApplied = { samples.append(screenRect(host)) }
    for _ in 0..<20 {
      host.updateConfiguration(configuration(sidebar: false))
      host.layoutSubtreeIfNeeded()
      host.revealTitlebar()
      host.layoutSubtreeIfNeeded()
      host.hideTitlebar()
      host.updateConfiguration(configuration(sidebar: true))
      host.layoutSubtreeIfNeeded()
      await Task.yield()
    }
    #expect(samples.count >= 80)
    for sample in samples { #expect(sample == expected) }
    #expect(host.preview.layer?.sublayers?.first === layer)
    host.preview.onGeometryApplied = nil
  }

  @Test func eightResizeDirectionsAreProportionalAtEveryStepWithoutReleaseCorrection() async throws
  {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    for visible in [true, false] {
      host.updateConfiguration(configuration(sidebar: visible))
      for delta in [
        CGSize(width: 2, height: 0), CGSize(width: -2, height: 0),
        CGSize(width: 0, height: 4), CGSize(width: 0, height: -4),
        CGSize(width: 2, height: 4), CGSize(width: -2, height: 4),
        CGSize(width: 2, height: -4), CGSize(width: -2, height: -4),
      ] {
        NotificationCenter.default.post(
          name: NSWindow.willStartLiveResizeNotification, object: window)
        for _ in 0..<10 {
          let proposal = CGSize(
            width: window.frame.width + delta.width, height: window.frame.height + delta.height)
          let insets = try #require(host.surfaceLayout)
          let size = try #require(window.delegate?.windowWillResize?(window, to: proposal))
          #expect(
            abs(
              (size.width - insets.externalSidebar)
                / (size.height - insets.externalTitlebar) - 0.5) < 0.00001)
          window.setFrame(CGRect(origin: window.frame.origin, size: size), display: false)
          host.layoutSubtreeIfNeeded()
          let rect = screenRect(host)
          // AppKit rounds a fractional diagonal projection to backing pixels.
          #expect(abs(rect.width - rect.height * 0.5) <= 1 / window.backingScaleFactor + 0.00001)
        }
        let released = window.frame
        NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
        #expect(window.frame == released)
        await Task.yield()
        #expect(window.frame == released)
      }
    }
  }

  @Test func resizeTakesOverImmediatelyAndSuspendsHover() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    host.updateConfiguration(configuration(sidebar: false))
    NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: window)
    let frame = window.frame
    host.revealTitlebar()
    #expect(window.frame == frame)
    let desired = try #require(
      window.delegate?.windowWillResize?(window, to: CGSize(width: 240, height: 480)))
    window.setFrame(CGRect(origin: frame.origin, size: desired), display: false)
    NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
    let released = window.frame
    try await Task.sleep(for: .milliseconds(200))
    #expect(window.frame == released)
    host.updateConfiguration(configuration(sidebar: true))
    host.updateConfiguration(configuration(sidebar: false))
    #expect(window.frame == released)
  }

  @Test func fullScreenRestoresOrdinaryGeometryAndSidebarState() async throws {
    for visible in [false, true] {
      let (window, host) = makeWindow()
      defer {
        host.prepareForRemoval()
        window.close()
      }
      try await Task.sleep(for: .milliseconds(100))
      host.updateConfiguration(configuration(sidebar: visible))
      let normal = window.frame
      NotificationCenter.default.post(
        name: NSWindow.willEnterFullScreenNotification, object: window)
      window.setFrame(CGRect(x: 0, y: 0, width: 1000, height: 800), display: false)
      NotificationCenter.default.post(name: NSWindow.didEnterFullScreenNotification, object: window)
      #expect(host.surfaceLayout?.preview.height == window.frame.height)
      #expect(host.surfaceLayout?.titlebar.height == 0)
      host.updateConfiguration(configuration(sidebar: !visible))
      NotificationCenter.default.post(name: NSWindow.willExitFullScreenNotification, object: window)
      NotificationCenter.default.post(name: NSWindow.didExitFullScreenNotification, object: window)
      #expect(window.frame == normal)

      // A source can rotate while full screen has suspended ordinary geometry.
      NotificationCenter.default.post(
        name: NSWindow.willEnterFullScreenNotification, object: window)
      window.setFrame(CGRect(x: 0, y: 0, width: 1000, height: 800), display: false)
      NotificationCenter.default.post(name: NSWindow.didEnterFullScreenNotification, object: window)
      host.updateConfiguration(
        WindowLayoutConfiguration(
          title: "Rotated source", aspectRatio: 2,
          sidebarWidth: 220, sidebarIsVisible: !visible, cornerRadiusFraction: 0))
      NotificationCenter.default.post(name: NSWindow.willExitFullScreenNotification, object: window)
      NotificationCenter.default.post(name: NSWindow.didExitFullScreenNotification, object: window)
      let rotated = try #require(host.surfaceLayout?.preview)
      #expect(abs(rotated.width / rotated.height - 2) < 0.00001)
    }
  }

  @Test func separateWindowsNeverSharePreviewGeometryOrChrome() async throws {
    let (firstWindow, first) = makeWindow()
    let (secondWindow, second) = makeWindow()
    defer {
      first.prepareForRemoval()
      second.prepareForRemoval()
      firstWindow.close()
      secondWindow.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let secondFrame = secondWindow.frame
    let secondPreview = screenRect(second)
    for _ in 0..<5 {
      first.updateConfiguration(configuration(sidebar: false))
      first.revealTitlebar()
      first.hideTitlebar()
      first.updateConfiguration(configuration(sidebar: true))
    }
    #expect(secondWindow.frame == secondFrame)
    #expect(screenRect(second) == secondPreview)
    #expect(first.preview !== second.preview)
  }

  @Test func compactMaskBelongsToPreviewAndWindowRemainsTransparent() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    host.updateConfiguration(configuration(sidebar: false, fraction: 62.0 / 402))
    #expect(!window.isOpaque)
    #expect(window.backgroundColor == .clear)
    #expect(host.layer?.cornerRadius == 0)
    #expect(host.preview.layer?.masksToBounds == true)
    #expect(host.preview.displayCornerRadius > 0)
    #expect(host.preview.layer?.cornerRadius == 0)
    #expect(host.preview.layer?.mask is CAShapeLayer)
    #expect(window.titlebarAppearsTransparent)
    host.revealTitlebar()
    #expect(host.preview.layer?.cornerRadius == 0)
    #expect(host.preview.layer?.mask == nil)
    #expect(!window.isOpaque)
  }

  @Test func proxyForwardsOriginalLifecycleAndResizeDecisions() throws {
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
