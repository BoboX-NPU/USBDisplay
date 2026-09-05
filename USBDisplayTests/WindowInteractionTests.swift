import AppKit
import Testing

@testable import iPhoneUSBDisplay

struct ResizeSessionTests {
  private let frame = CGRect(x: 200, y: 100, width: 300, height: 600)
  private let maximum = CGSize(width: 1600, height: 1000)

  @Test func rawWidthSequenceNeverFeedsAcceptedHeightBackIntoAxisChoice() {
    for (sidebar, titlebar) in [(0.0, 0.0), (221.0, 0.0), (0.0, 52.0), (221.0, 52.0)] {
      var session = ResizeSession(
        frame: CGRect(x: 200, y: 100, width: 300 + sidebar, height: 600 + titlebar),
        aspectRatio: 0.5, externalSidebar: sidebar, externalTitlebar: titlebar)
      for width in 301...360 {
        let accepted = session.constrain(
          CGSize(width: Double(width) + sidebar, height: 600 + titlebar), maximumSize: maximum)
        #expect(abs(Double(accepted.width) - Double(width) - sidebar) < 0.000001)
        #expect(abs(Double(accepted.height) - Double(width * 2) - titlebar) < 0.000001)
        #expect(session.strategy == .width)
      }
    }
  }

  @Test func eightHandlesChooseOnceAndRemainProportionalWithNoise() {
    let handles: [(CGPoint, ResizeSession.Strategy)] = [
      (CGPoint(x: frame.minX, y: frame.midY), .width),
      (CGPoint(x: frame.maxX, y: frame.midY), .width),
      (CGPoint(x: frame.midX, y: frame.minY), .height),
      (CGPoint(x: frame.midX, y: frame.maxY), .height),
      (CGPoint(x: frame.minX, y: frame.minY), .corner),
      (CGPoint(x: frame.maxX, y: frame.minY), .corner),
      (CGPoint(x: frame.minX, y: frame.maxY), .corner),
      (CGPoint(x: frame.maxX, y: frame.maxY), .corner),
    ]
    for (point, strategy) in handles {
      #expect(ResizeSession.Strategy.at(pointer: point, frame: frame) == strategy)
      for direction in [-1.0, 1] {
        var session = ResizeSession(
          frame: frame, aspectRatio: 0.5, externalSidebar: 0, externalTitlebar: 0,
          strategy: strategy)
        var previous = frame.size
        for step in 1...50 {
          let delta = Double(step) * direction
          let noise = step.isMultiple(of: 2) ? 0.1 : -0.1
          let proposed = CGSize(
            width: frame.width + (strategy == .height ? noise : delta),
            height: frame.height + (strategy == .width ? noise : delta * 3))
          let accepted = session.constrain(proposed, maximumSize: maximum)
          #expect(abs(accepted.width / accepted.height - 0.5) < 0.000001)
          #expect((accepted.width - previous.width) * direction > 0)
          #expect(session.strategy == strategy)
          previous = accepted
        }
      }
    }
    #expect(ResizeSession.Strategy.at(pointer: CGPoint(x: 350, y: 400), frame: frame) == nil)
  }

  @Test func diagonalProjectionLimitsAndReversalHaveNoHysteresis() {
    var session = ResizeSession(
      frame: frame, aspectRatio: 0.5, externalSidebar: 0, externalTitlebar: 0, strategy: .corner)
    let proposed = CGSize(width: 350, height: 660)
    let accepted = session.constrain(proposed, maximumSize: maximum)
    #expect(abs(Double(accepted.height) - (350 * 0.5 + 660) / 1.25) < 0.000001)
    #expect(
      session.constrain(CGSize(width: 4000, height: 4000), maximumSize: maximum).height == 1000)
    #expect(session.constrain(proposed, maximumSize: maximum) == accepted)
    #expect(session.constrain(.zero, maximumSize: maximum).height == 320)
    #expect(session.constrain(proposed, maximumSize: maximum) == accepted)
    let small = session.constrain(proposed, maximumSize: CGSize(width: 120, height: 240))
    #expect(small == CGSize(width: 120, height: 240))
  }

  @Test func fallbackIgnoresSubpixelNoiseAndSessionsAreIndependent() {
    var width = ResizeSession(
      frame: frame, aspectRatio: 0.5, externalSidebar: 0, externalTitlebar: 0)
    var height = width
    _ = width.constrain(CGSize(width: 301, height: 600.1), maximumSize: maximum)
    _ = height.constrain(CGSize(width: 300.1, height: 601), maximumSize: maximum)
    #expect(width.strategy == .width)
    #expect(height.strategy == .height)
    #expect(width.constrain(CGSize(width: 320, height: 450), maximumSize: maximum).height == 640)
    #expect(height.constrain(CGSize(width: 450, height: 640), maximumSize: maximum).width == 320)
  }

  @Test func ratioChangesNeedTwoStableSamplesAndResetAcrossGeometryChanges() {
    var filter = StableAspectRatio()
    var results = [
      filter.observe(0.5), filter.observe(0.5002), filter.observe(2),
      filter.observe(0.5), filter.observe(2),
    ]
    #expect(results == [true, false, false, false, false])
    filter.discardCandidate()
    results = [filter.observe(2), filter.observe(2.0001), filter.observe(.nan)]
    #expect(results == [false, true, false])
    filter = StableAspectRatio()
    let firstSample = filter.observe(0.75)
    #expect(firstSample)
  }
}

@Suite(.serialized)
@MainActor
struct WindowChromeInteractionTests {
  private func configuration(sidebar: Bool, ratio: Double? = 0.5) -> WindowLayoutConfiguration {
    WindowLayoutConfiguration(
      title: "Animated fixture", aspectRatio: ratio, sidebarWidth: 220,
      sidebarIsVisible: sidebar, cornerRadiusFraction: 62.0 / 402)
  }

  private func makeWindow(
    ratio: Double? = 0.5, clock: @escaping () -> TimeInterval = CACurrentMediaTime
  ) -> (NSWindow, WindowLayoutHostView) {
    let screen = NSScreen.main!.visibleFrame
    let window = ToolbarLayoutWindow(
      contentRect: CGRect(x: screen.midX - 200, y: screen.minY + 100, width: 471, height: 500),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let host = WindowLayoutHostView(
      configuration: configuration(sidebar: true, ratio: ratio), animationClock: clock)
    window.contentView = host
    return (window, host)
  }

  private func previewRect(_ host: WindowLayoutHostView) -> CGRect {
    host.window!.convertToScreen(host.preview.convert(host.preview.bounds, to: nil))
  }

  private func finish(_ host: WindowLayoutHostView) {
    if let start = host.chromeAnimator.startedAt {
      host.chromeAnimator.advance(to: start + WindowChromeAnimator.duration)
    }
  }

  @Test func unifiedToolbarToggleStaysClearOfWindowButtons() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    // Match the real SwiftUI scene; the default fixture uses expanded chrome.
    window.toolbarStyle = .unifiedCompact
    window.orderFront(nil)
    try await Task.sleep(for: .milliseconds(100))
    func checkPlacement() throws {
      guard window.toolbar?.isVisible == true else { return }
      window.contentView?.superview?.layoutSubtreeIfNeeded()
      let toggle = try #require(window.toolbar?.items.first?.view)
      let rect = toggle.convert(toggle.bounds, to: nil)
      for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        let button = try #require(window.standardWindowButton(type))
        let control = button.convert(button.bounds, to: nil)
        #expect(!rect.intersects(control))
        #expect(rect.minX >= control.maxX + 8)
        #expect(abs(button.alphaValue - host.chromeAnimator.presentation.titlebar) < 0.00001)
      }
    }
    func checkAnimation() throws {
      if let start = host.chromeAnimator.startedAt {
        for progress in [0.0, 0.25, 0.5, 0.75, 1] {
          host.chromeAnimator.advance(to: start + progress * WindowChromeAnimator.duration)
          try checkPlacement()
        }
      } else {
        try checkPlacement()
      }
    }
    for _ in 0..<5 {
      host.updateConfiguration(configuration(sidebar: true))
      try checkAnimation()
      host.updateConfiguration(configuration(sidebar: false))
      try checkAnimation()
      host.revealTitlebar()
      try checkAnimation()
      host.hideTitlebar()
      try checkAnimation()
      host.revealTitlebar()
      try checkAnimation()
    }
  }

  @Test func twentyCyclesKeepPreviewFixedAtEveryAnimationSample() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let rect = previewRect(host)
    let video = host.preview.layer?.sublayers?.first
    for _ in 0..<20 {
      for visible in [false, true] {
        let oldFrame = window.frame
        host.updateConfiguration(configuration(sidebar: visible))
        let start = try #require(host.chromeAnimator.startedAt)
        let reservedFrame = window.frame
        if !visible { #expect(reservedFrame == oldFrame) }
        for progress in [0.0, 0.25, 0.5, 0.75] {
          host.chromeAnimator.advance(to: start + progress * WindowChromeAnimator.duration)
          #expect(window.frame == reservedFrame)
          #expect(previewRect(host) == rect)
          #expect(host.preview.layer?.sublayers?.first === video)
          let value = host.chromeAnimator.presentation
          #expect(value.sidebar == value.titlebar)
          #expect(
            abs(host.preview.displayCornerRadius - rect.width * 62 / 402 * value.compact) < 0.0001)
        }
        finish(host)
        #expect(previewRect(host) == rect)
        #expect(!host.chromeAnimator.isRunning)
        #expect(window.toolbar?.isVisible == visible)
        #expect(window.hasShadow == visible)
      }
    }
  }

  @Test func retargetKeepsPresentationAndMetadataDoesNotRestartAnimation() async throws {
    var time = 0.0
    let (window, host) = makeWindow(clock: { time })
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    host.updateConfiguration(configuration(sidebar: false))
    let started = try #require(host.chromeAnimator.startedAt)
    time = 0.06
    host.chromeAnimator.advance(to: time)
    let before = host.chromeAnimator.presentation
    host.updateConfiguration(configuration(sidebar: true))
    let after = host.chromeAnimator.presentation
    #expect(abs(before.sidebar - after.sidebar) < 0.05)
    #expect(after.sidebar > 0 && after.sidebar < 1)
    let reversedStart = try #require(host.chromeAnimator.startedAt)
    #expect(reversedStart > started)
    host.updateConfiguration(
      WindowLayoutConfiguration(
        title: "Renamed fixture", aspectRatio: 0.5, sidebarWidth: 220,
        sidebarIsVisible: true, cornerRadiusFraction: 0.15))
    #expect(host.chromeAnimator.startedAt == reversedStart)
    finish(host)
    try await Task.sleep(for: .milliseconds(250))
    #expect(host.chromeAnimator.presentation == ChromePresentation(sidebar: true, titlebar: true))
    #expect(window.toolbar?.isVisible == true)
  }

  @Test func dragFreezesReservationUntilAnimationFinishesAndReleasePreservesVideo() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    host.updateConfiguration(configuration(sidebar: false))
    let start = try #require(host.chromeAnimator.startedAt)
    host.chromeAnimator.advance(to: start + 0.05)
    let initial = window.frame
    let insets = try #require(host.surfaceLayout)
    NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: window)
    finish(host)
    #expect(window.frame == initial)
    #expect(host.surfaceLayout?.externalSidebar == insets.externalSidebar)
    host.revealTitlebar()
    #expect(host.chromeAnimator.target.titlebar == 0)
    var previousWidth = initial.width
    for delta in 1...30 {
      let accepted = try #require(
        window.delegate?.windowWillResize?(
          window,
          to: CGSize(width: initial.width + Double(delta), height: initial.height)))
      #expect(accepted.width > previousWidth)
      window.setFrame(CGRect(origin: initial.origin, size: accepted), display: false)
      previousWidth = accepted.width
    }
    let resizedPreview = previewRect(host)
    NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
    #expect(previewRect(host) == resizedPreview)
    #expect(host.surfaceLayout?.externalSidebar == 0)
    #expect(host.surfaceLayout?.externalTitlebar == 0)
    let released = window.frame
    try await Task.sleep(for: .milliseconds(250))
    #expect(window.frame == released)
  }

  @Test func hoverAnimationAndWindowStatesStayIndependent() async throws {
    let (window, host) = makeWindow()
    let (otherWindow, other) = makeWindow()
    defer {
      host.prepareForRemoval()
      other.prepareForRemoval()
      window.close()
      otherWindow.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let otherFrame = otherWindow.frame
    host.updateConfiguration(configuration(sidebar: false))
    finish(host)
    let compact = window.frame
    let rect = previewRect(host)
    host.revealTitlebar()
    let start = try #require(host.chromeAnimator.startedAt)
    host.chromeAnimator.advance(to: start + 0.1)
    #expect(host.chromeAnimator.presentation.titlebar > 0)
    #expect(host.chromeAnimator.presentation.titlebar < 1)
    #expect(previewRect(host) == rect)
    finish(host)
    host.hideTitlebar()
    #expect(window.frame != compact)
    finish(host)
    #expect(window.frame == compact)
    #expect(otherWindow.frame == otherFrame)
    #expect(!other.chromeAnimator.isRunning)
  }

  @Test func emptySplitAnimatesAndEndsAtThirtySeventy() async throws {
    let (window, host) = makeWindow(ratio: nil)
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    host.updateConfiguration(configuration(sidebar: false, ratio: nil))
    let start = try #require(host.chromeAnimator.startedAt)
    host.chromeAnimator.advance(to: start + 0.1)
    let width = try #require(host.surfaceLayout?.sidebar.width)
    #expect(width > 0 && width < window.frame.width * 0.3)
    finish(host)
    #expect(host.surfaceLayout?.sidebar.width == 0)
    host.updateConfiguration(configuration(sidebar: true, ratio: nil))
    finish(host)
    #expect(abs((host.surfaceLayout?.sidebar.width ?? 0) / window.frame.width - 0.3) < 0.001)
  }

  @Test func sourceChangesDuringDragWaitForReleaseAndRetainUserHeight() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    host.updateConfiguration(configuration(sidebar: false))
    finish(host)
    NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: window)
    let initial = window.frame
    let accepted = try #require(
      window.delegate?.windowWillResize?(
        window,
        to: CGSize(width: initial.width + 10, height: initial.height)))
    window.setFrame(CGRect(origin: initial.origin, size: accepted), display: false)
    let video = previewRect(host)
    host.updateConfiguration(configuration(sidebar: false, ratio: nil))
    #expect(previewRect(host) == video)
    NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
    #expect(window.frame.width >= 720)
    host.updateConfiguration(configuration(sidebar: false, ratio: 0.5))
    #expect(previewRect(host).size == video.size)
    NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: window)
    host.updateConfiguration(configuration(sidebar: false, ratio: 1))
    #expect(previewRect(host).size == video.size)
    NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
    #expect(previewRect(host).height == video.height)
    #expect(previewRect(host).width == video.height)
  }

  @Test func fullScreenEdgeSidebarOverlaysVideoAndRestoresOrdinaryControls() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let ordinary = previewRect(host)
    let delegate = try #require(window.delegate as? WindowResizeDelegate)
    let options = delegate.window(
      window, willUseFullScreenPresentationOptions: [.fullScreen, .hideMenuBar, .hideDock])
    #expect(options.contains([.fullScreen, .autoHideMenuBar, .autoHideToolbar, .hideDock]))
    #expect(!options.contains(.hideMenuBar))
    #expect(!options.contains(.autoHideDock))
    NotificationCenter.default.post(name: NSWindow.willEnterFullScreenNotification, object: window)
    window.setFrame(NSScreen.main!.frame, display: false)
    NotificationCenter.default.post(name: NSWindow.didEnterFullScreenNotification, object: window)
    let video = previewRect(host)
    let nativeToolbar = try #require(window.toolbar)
    var visibilityChanges = 0
    let observation = nativeToolbar.observe(\.isVisible, options: [.new]) { _, _ in
      MainActor.assumeIsolated { visibilityChanges += 1 }
    }
    defer { observation.invalidate() }
    #expect(nativeToolbar.isVisible)
    host.updatePointer(CGPoint(x: window.frame.width / 2, y: window.frame.height - 1))
    #expect(window.toolbar?.isVisible == true)
    host.updatePointer(CGPoint(x: window.frame.width / 2, y: window.frame.height / 2))
    try await Task.sleep(for: .milliseconds(650))
    #expect(nativeToolbar.isVisible)
    #expect(visibilityChanges == 0)
    #expect(host.surfaceLayout?.sidebar.width == 0)
    let layoutWindow = try #require(window as? ToolbarLayoutWindow)
    host.toggleSidebar()
    finish(host)
    let outerFrame = window.frame
    for inset in [0.0, 20.0, 42.0, 60.0, 20.0, 0.0] {
      layoutWindow.setUnobscuredContent(
        CGRect(x: 0, y: 0, width: window.frame.width, height: window.frame.height - inset))
      #expect(abs(host.surfaceLayout!.sidebar.maxY - (window.frame.height - inset)) < 0.000001)
      #expect(host.surfaceLayout?.sidebar.minY == 0)
      #expect(previewRect(host) == video)
      #expect(window.frame == outerFrame)
    }
    host.toggleSidebar()
    finish(host)
    for _ in 0..<3 {
      host.updatePointer(CGPoint(x: 1, y: window.frame.height / 2))
      finish(host)
      #expect(host.surfaceLayout!.sidebar.width > 0)
      #expect(nativeToolbar.isVisible)
      #expect(visibilityChanges == 0)
      #expect(previewRect(host) == video)
      host.updatePointer(CGPoint(x: window.frame.width / 2, y: window.frame.height / 2))
      try await Task.sleep(for: .milliseconds(650))
      finish(host)
      #expect(host.surfaceLayout?.sidebar.width == 0)
      #expect(previewRect(host) == video)
    }
    host.toggleSidebar()
    finish(host)
    #expect(host.surfaceLayout!.sidebar.width > 0)
    host.toggleSidebar()
    finish(host)
    #expect(host.surfaceLayout?.sidebar.width == 0)
    #expect(visibilityChanges == 0)
    observation.invalidate()
    NotificationCenter.default.post(name: NSWindow.willExitFullScreenNotification, object: window)
    NotificationCenter.default.post(name: NSWindow.didExitFullScreenNotification, object: window)
    #expect(window.toolbar?.isVisible == true)
    #expect(host.surfaceLayout!.sidebar.width > 0)
    #expect(previewRect(host) == ordinary)
  }

  @Test func fullScreenCancelsOldAnimationCallbacksAndRestoresOrdinaryVideo() async throws {
    let (window, host) = makeWindow()
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let video = previewRect(host)
    host.updateConfiguration(configuration(sidebar: false))
    NotificationCenter.default.post(name: NSWindow.willEnterFullScreenNotification, object: window)
    window.setFrame(NSScreen.main!.frame, display: false)
    NotificationCenter.default.post(name: NSWindow.didEnterFullScreenNotification, object: window)
    #expect(!host.chromeAnimator.isRunning)
    #expect(host.surfaceLayout?.preview.height == window.frame.height)
    host.updateConfiguration(configuration(sidebar: true))
    finish(host)
    NotificationCenter.default.post(name: NSWindow.willExitFullScreenNotification, object: window)
    NotificationCenter.default.post(name: NSWindow.didExitFullScreenNotification, object: window)
    #expect(previewRect(host) == video)
    #expect(host.surfaceLayout?.sidebar.width == 0)
    let restored = window.frame
    try await Task.sleep(for: .milliseconds(250))
    #expect(window.frame == restored)
  }

  @Test func screenEdgeAnimationOverlaysControlsWithoutShrinkingVideo() async throws {
    let (window, host) = makeWindow(ratio: 2)
    defer {
      host.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    host.updateConfiguration(configuration(sidebar: false, ratio: 2))
    finish(host)
    let screen = NSScreen.main!.visibleFrame
    NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: window)
    let accepted = try #require(
      window.delegate?.windowWillResize?(
        window,
        to: CGSize(width: screen.width - 10, height: (screen.width - 10) / 2)))
    window.setFrame(CGRect(origin: screen.origin, size: accepted), display: false)
    NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
    let video = previewRect(host)
    host.updateConfiguration(configuration(sidebar: true, ratio: 2))
    let start = try #require(host.chromeAnimator.startedAt)
    for progress in [0.0, 0.25, 0.5, 0.75, 1] {
      host.chromeAnimator.advance(to: start + progress * WindowChromeAnimator.duration)
      #expect(previewRect(host).size == video.size)
      #expect(host.surfaceLayout?.externalSidebar == 0)
    }
    host.updateConfiguration(configuration(sidebar: false, ratio: 2))
    finish(host)
    #expect(previewRect(host) == video)
  }
}

@MainActor
private final class ToolbarLayoutWindow: NSWindow {
  private var unobscuredContent: CGRect?

  override var contentLayoutRect: NSRect { unobscuredContent ?? super.contentLayoutRect }

  func setUnobscuredContent(_ rect: CGRect) {
    willChangeValue(forKey: "contentLayoutRect")
    unobscuredContent = rect
    didChangeValue(forKey: "contentLayoutRect")
  }
}
