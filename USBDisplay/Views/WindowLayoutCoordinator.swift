import AppKit
import SwiftUI

struct WindowLayoutCoordinator: NSViewRepresentable {
  let title: String
  let aspectRatio: Double?
  let sidebarWidth: Double
  let sidebarIsVisible: Bool

  func makeNSView(context: Context) -> WindowLayoutHostView {
    WindowLayoutHostView(
      configuration: configuration
    )
  }

  func updateNSView(_ nsView: WindowLayoutHostView, context: Context) {
    nsView.updateConfiguration(configuration)
  }

  static func dismantleNSView(_ nsView: WindowLayoutHostView, coordinator: Void) {
    nsView.prepareForRemoval()
  }

  private var configuration: WindowLayoutConfiguration {
    WindowLayoutConfiguration(
      title: title,
      aspectRatio: aspectRatio,
      sidebarWidth: sidebarWidth,
      sidebarIsVisible: sidebarIsVisible
    )
  }
}

private struct WindowLayoutConfiguration: Equatable {
  let title: String
  let aspectRatio: Double?
  let sidebarWidth: Double
  let sidebarIsVisible: Bool
}

@MainActor
final class WindowLayoutHostView: NSView {
  private var configuration: WindowLayoutConfiguration
  private weak var observedWindow: NSWindow?
  private weak var chromeTrackingView: NSView?
  private var chromeTrackingArea: NSTrackingArea?
  private var revealRegionInWindow = CGRect.zero
  private var observers: [NSObjectProtocol] = []
  private var lastFrame: CGRect?
  private var lastContentSize: CGSize?
  private var isApplyingFrame = false
  private var hideChromeWorkItem: DispatchWorkItem?
  private var chromeVisibilityState: WindowChromeVisibilityState
  private var mouseEventMonitor: Any?
  private var windowPreviouslyAcceptedMouseMovedEvents = false
  private var measuredTitlebarHeight = 0.0
  private var compactFrameBeforeHover: CGRect?
  private var chromeTransitionGeneration = 0

  fileprivate init(configuration: WindowLayoutConfiguration) {
    self.configuration = configuration
    chromeVisibilityState = WindowChromeVisibilityState(
      sidebarIsVisible: configuration.sidebarIsVisible
    )
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    guard window !== observedWindow else { return }
    detachFromWindow()
    guard let window else { return }

    observedWindow = window
    installObservers(for: window)
    installMouseEventMonitor(for: window)
    measuredTitlebarHeight = currentWindowDecorationHeight(of: window)
    applyChromeMode(
      chromeVisibilityState.mode,
      to: window,
      preservingContentSize: true,
      animated: false
    )
    refreshChromeTrackingArea()
    rememberCurrentGeometry(of: window)
    scheduleProportionalLayout(animated: false)
  }

  fileprivate func updateConfiguration(_ newConfiguration: WindowLayoutConfiguration) {
    let layoutChanged =
      configuration.aspectRatio != newConfiguration.aspectRatio
      || abs(configuration.sidebarWidth - newConfiguration.sidebarWidth) >= 0.5
      || configuration.sidebarIsVisible != newConfiguration.sidebarIsVisible

    let sidebarVisibilityChanged =
      configuration.sidebarIsVisible != newConfiguration.sidebarIsVisible
    configuration = newConfiguration
    guard let window = observedWindow else { return }
    window.title = newConfiguration.title
    window.titleVisibility = .hidden

    if sidebarVisibilityChanged {
      cancelPendingChromeHide()
      chromeVisibilityState.updateSidebarVisibility(newConfiguration.sidebarIsVisible)
      applyChromeMode(
        chromeVisibilityState.mode,
        to: window,
        preservingContentSize: true,
        animated: true
      )
    }

    if layoutChanged {
      scheduleProportionalLayout(animated: false)
    }
  }

  fileprivate func prepareForRemoval() {
    detachFromWindow()
  }

  private func installObservers(for window: NSWindow) {
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: NSWindow.didResizeNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.handleWindowResize()
        }
      },
      center.addObserver(
        forName: NSWindow.didMoveNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.handleWindowMove()
        }
      },
      center.addObserver(
        forName: NSWindow.didEnterFullScreenNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.handleDidEnterFullScreen()
        }
      },
      center.addObserver(
        forName: NSWindow.didExitFullScreenNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.handleDidExitFullScreen()
          self?.scheduleProportionalLayout(animated: false)
        }
      },
      center.addObserver(
        forName: NSWindow.didChangeScreenNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.refreshChromeTrackingArea()
          self?.scheduleProportionalLayout(animated: false)
        }
      },
    ]
  }

  private func detachFromWindow() {
    cancelPendingChromeHide()
    chromeTransitionGeneration += 1
    if let observedWindow {
      restoreNativeChrome(in: observedWindow)
      observedWindow.acceptsMouseMovedEvents = windowPreviouslyAcceptedMouseMovedEvents
    }
    removeMouseEventMonitor()
    removeChromeTrackingArea()
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    observedWindow = nil
    lastFrame = nil
    lastContentSize = nil
    compactFrameBeforeHover = nil
  }

  override func mouseEntered(with event: NSEvent) {
    guard event.trackingArea === chromeTrackingArea, let window = observedWindow else {
      super.mouseEntered(with: event)
      return
    }

    revealChromeIfNeeded(in: window)
  }

  override func mouseExited(with event: NSEvent) {
    guard event.trackingArea === chromeTrackingArea, let window = observedWindow else {
      super.mouseExited(with: event)
      return
    }

    scheduleChromeHideIfNeeded(in: window)
  }

  private func scheduleProportionalLayout(animated: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.applyProportionalLayoutPreservingHeight(animated: animated)
    }
  }

  private func applyProportionalLayoutPreservingHeight(animated: Bool) {
    if isApplyingFrame {
      DispatchQueue.main.asyncAfter(
        deadline: .now() + WindowChromeVisibilityState.animationDuration
      ) { [weak self] in
        self?.applyProportionalLayoutPreservingHeight(animated: animated)
      }
      return
    }

    guard
      let window = observedWindow,
      let aspectRatio = configuration.aspectRatio,
      WindowLayoutPolicy.shouldConstrainWindow(
        isFullScreen: window.styleMask.contains(.fullScreen),
        aspectRatio: aspectRatio
      ),
      let contentSize = currentContentSize(of: window),
      let desiredSize = WindowLayoutPolicy.sizePreservingHeight(
        currentHeight: contentSize.height,
        aspectRatio: aspectRatio,
        sidebarWidth: configuration.sidebarWidth,
        sidebarIsVisible: configuration.sidebarIsVisible,
        maximumSize: maximumContentSize(for: window)
      )
    else {
      return
    }

    updateMinimumSize(of: window, aspectRatio: aspectRatio)
    apply(
      desiredContentSize: desiredSize,
      to: window,
      anchoringAgainst: nil,
      animated: animated
    )
  }

  private func handleWindowResize() {
    guard let window = observedWindow, !isApplyingFrame else { return }
    refreshChromeTrackingArea()
    guard
      let aspectRatio = configuration.aspectRatio,
      WindowLayoutPolicy.shouldConstrainWindow(
        isFullScreen: window.styleMask.contains(.fullScreen),
        aspectRatio: aspectRatio
      ),
      let proposedSize = currentContentSize(of: window)
    else {
      rememberCurrentGeometry(of: window)
      updateCompactFrameForCurrentHoverGeometry(of: window)
      return
    }

    let previousSize = lastContentSize ?? proposedSize
    guard
      let desiredSize = WindowLayoutPolicy.constrainedResize(
        proposedSize: WindowContentSize(
          width: proposedSize.width,
          height: proposedSize.height
        ),
        previousSize: WindowContentSize(
          width: previousSize.width,
          height: previousSize.height
        ),
        aspectRatio: aspectRatio,
        sidebarWidth: configuration.sidebarWidth,
        sidebarIsVisible: configuration.sidebarIsVisible,
        maximumSize: maximumContentSize(for: window)
      )
    else {
      return
    }

    if abs(desiredSize.width - proposedSize.width) < 1,
      abs(desiredSize.height - proposedSize.height) < 1
    {
      rememberCurrentGeometry(of: window)
      updateCompactFrameForCurrentHoverGeometry(of: window)
      return
    }

    apply(
      desiredContentSize: desiredSize,
      to: window,
      anchoringAgainst: lastFrame,
      animated: false
    )
    updateCompactFrameForCurrentHoverGeometry(of: window)
  }

  private func handleWindowMove() {
    guard let window = observedWindow, !isApplyingFrame else { return }
    updateCompactFrameForCurrentHoverGeometry(of: window)
    rememberCurrentGeometry(of: window)
  }

  private func apply(
    desiredContentSize: WindowContentSize,
    to window: NSWindow,
    anchoringAgainst previousFrame: CGRect?,
    animated: Bool
  ) {
    guard let currentContentSize = currentContentSize(of: window) else { return }

    var frame = window.frame
    let widthDifference = desiredContentSize.width - currentContentSize.width
    let heightDifference = desiredContentSize.height - currentContentSize.height
    frame.size.width += widthDifference
    frame.size.height += heightDifference

    if let previousFrame {
      let leftEdgeMoved =
        abs(window.frame.minX - previousFrame.minX)
        > abs(window.frame.maxX - previousFrame.maxX)
      let bottomEdgeMoved =
        abs(window.frame.minY - previousFrame.minY)
        > abs(window.frame.maxY - previousFrame.maxY)

      if leftEdgeMoved {
        frame.origin.x = window.frame.maxX - frame.width
      }
      if bottomEdgeMoved {
        frame.origin.y = window.frame.maxY - frame.height
      }
    } else {
      frame.origin.x -= widthDifference / 2
      frame.origin.y -= heightDifference / 2
    }

    frame = clamped(frame: frame, to: window.screen?.visibleFrame)
    isApplyingFrame = true
    window.setFrame(frame, display: true, animate: animated)
    isApplyingFrame = false
    rememberCurrentGeometry(of: window)
  }

  private func handleDidEnterFullScreen() {
    cancelPendingChromeHide()
    chromeTransitionGeneration += 1
    removeChromeTrackingArea()
  }

  private func handleDidExitFullScreen() {
    guard let window = observedWindow else { return }
    chromeVisibilityState.updateSidebarVisibility(configuration.sidebarIsVisible)
    applyChromeMode(
      chromeVisibilityState.mode,
      to: window,
      preservingContentSize: true,
      animated: false
    )
    refreshChromeTrackingArea()
  }

  private func updatePointerLocation(_ location: CGPoint, in window: NSWindow) {
    guard !configuration.sidebarIsVisible, !window.styleMask.contains(.fullScreen) else {
      return
    }

    if revealRegionInWindow.contains(location) {
      revealChromeIfNeeded(in: window)
    } else if chromeVisibilityState.mode == .hoverRevealed {
      scheduleChromeHideIfNeeded(in: window)
    }
  }

  private func revealChromeIfNeeded(in window: NSWindow) {
    guard
      !configuration.sidebarIsVisible,
      !window.styleMask.contains(.fullScreen)
    else {
      return
    }

    cancelPendingChromeHide()
    guard chromeVisibilityState.mode == .compact else { return }
    chromeVisibilityState.pointerEnteredTopRegion()
    applyChromeMode(
      chromeVisibilityState.mode,
      to: window,
      preservingContentSize: true,
      animated: true
    )
  }

  private func scheduleChromeHideIfNeeded(in window: NSWindow) {
    guard chromeVisibilityState.pointerExitedRevealRegion() else { return }
    cancelPendingChromeHide()

    let workItem = DispatchWorkItem { [weak self, weak window] in
      guard let self, let window else { return }
      MainActor.assumeIsolated {
        self.hideChromeWorkItem = nil
        guard
          !self.configuration.sidebarIsVisible,
          !self.revealRegionInWindow.contains(window.mouseLocationOutsideOfEventStream)
        else {
          self.chromeVisibilityState.pointerEnteredTopRegion()
          return
        }

        self.chromeVisibilityState.hideDelayElapsed()
        self.applyChromeMode(
          self.chromeVisibilityState.mode,
          to: window,
          preservingContentSize: true,
          animated: true
        )
      }
    }
    hideChromeWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + WindowChromeVisibilityState.hideDelay,
      execute: workItem
    )
  }

  private func cancelPendingChromeHide() {
    hideChromeWorkItem?.cancel()
    hideChromeWorkItem = nil
  }

  private func applyChromeMode(
    _ mode: WindowChromeMode,
    to window: NSWindow,
    preservingContentSize: Bool,
    animated: Bool
  ) {
    guard !window.styleMask.contains(.fullScreen) else { return }
    let originalFrame = window.frame
    let wasCompact = window.styleMask.contains(.fullSizeContentView)

    if !wasCompact {
      measuredTitlebarHeight = max(
        currentWindowDecorationHeight(of: window),
        measuredTitlebarHeight
      )
    }

    if mode == .hoverRevealed {
      compactFrameBeforeHover = originalFrame
    } else if mode == .sidebarVisible {
      compactFrameBeforeHover = nil
    }

    window.title = configuration.title
    window.titleVisibility = .hidden
    switch mode {
    case .sidebarVisible, .hoverRevealed:
      window.styleMask.remove(.fullSizeContentView)
      window.titlebarAppearsTransparent = false
      window.titlebarSeparatorStyle = .automatic
      window.toolbar?.isVisible = true
      window.toolbar?.showsBaselineSeparator = true
      setTitlebarButtons(hidden: false, in: window)

    case .compact:
      window.styleMask.insert(.fullSizeContentView)
      window.titlebarAppearsTransparent = true
      window.titlebarSeparatorStyle = .none
      window.toolbar?.showsBaselineSeparator = false
      window.toolbar?.isVisible = false
      setTitlebarButtons(hidden: true, in: window)
    }

    window.contentView?.layoutSubtreeIfNeeded()
    window.contentView?.superview?.layoutSubtreeIfNeeded()

    guard preservingContentSize else {
      refreshChromeTrackingArea()
      return
    }

    var targetFrame = originalFrame
    if mode == .compact, !wasCompact {
      targetFrame.size.height = max(originalFrame.height - measuredTitlebarHeight, 1)
    } else if mode != .compact, wasCompact {
      targetFrame.size.height += measuredTitlebarHeight
    }

    if mode == .hoverRevealed {
      targetFrame =
        WindowLayoutPolicy.frameByRevealingTitlebar(
          compactFrame: originalFrame,
          titlebarHeight: measuredTitlebarHeight,
          visibleFrame: window.screen?.visibleFrame
        ) ?? targetFrame
    } else if mode == .compact, let compactFrameBeforeHover {
      targetFrame.origin = compactFrameBeforeHover.origin
      self.compactFrameBeforeHover = nil
    }

    applyChromeFrame(targetFrame, to: window, animated: animated)
  }

  private func applyChromeFrame(_ frame: CGRect, to window: NSWindow, animated: Bool) {
    chromeTransitionGeneration += 1
    let generation = chromeTransitionGeneration
    isApplyingFrame = true

    guard animated else {
      window.setFrame(frame, display: true)
      isApplyingFrame = false
      rememberCurrentGeometry(of: window)
      refreshChromeTrackingArea()
      return
    }

    NSAnimationContext.runAnimationGroup { context in
      context.duration = WindowChromeVisibilityState.animationDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      window.animator().setFrame(frame, display: true)
    } completionHandler: { [weak self, weak window] in
      guard let self, let window else { return }
      MainActor.assumeIsolated {
        guard generation == self.chromeTransitionGeneration else { return }
        self.isApplyingFrame = false
        self.rememberCurrentGeometry(of: window)
        self.refreshChromeTrackingArea()
      }
    }
  }

  private func restoreNativeChrome(in window: NSWindow) {
    window.styleMask.remove(.fullSizeContentView)
    window.titlebarAppearsTransparent = false
    window.titlebarSeparatorStyle = .automatic
    window.toolbar?.isVisible = true
    window.toolbar?.showsBaselineSeparator = true
    setTitlebarButtons(hidden: false, in: window)
  }

  private func setTitlebarButtons(hidden: Bool, in window: NSWindow) {
    let buttons: [NSWindow.ButtonType] = [
      .closeButton,
      .miniaturizeButton,
      .zoomButton,
      .toolbarButton,
    ]
    for buttonType in buttons {
      window.standardWindowButton(buttonType)?.isHidden = hidden
    }
  }

  private func installMouseEventMonitor(for window: NSWindow) {
    removeMouseEventMonitor()
    windowPreviouslyAcceptedMouseMovedEvents = window.acceptsMouseMovedEvents
    window.acceptsMouseMovedEvents = true

    mouseEventMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
    ) { [weak self, weak window] event in
      guard let self, let window, event.window === window else { return event }
      MainActor.assumeIsolated {
        self.updatePointerLocation(event.locationInWindow, in: window)
      }
      return event
    }
  }

  private func removeMouseEventMonitor() {
    if let mouseEventMonitor {
      NSEvent.removeMonitor(mouseEventMonitor)
    }
    mouseEventMonitor = nil
  }

  private func refreshChromeTrackingArea() {
    guard let window = observedWindow, !window.styleMask.contains(.fullScreen) else {
      removeChromeTrackingArea()
      return
    }
    installChromeTrackingArea(for: window)
  }

  private func installChromeTrackingArea(for window: NSWindow) {
    removeChromeTrackingArea()
    guard !configuration.sidebarIsVisible else { return }
    guard let frameView = window.contentView?.superview else { return }

    let frameBoundsInWindow = frameView.convert(frameView.bounds, to: nil)
    switch chromeVisibilityState.mode {
    case .compact:
      revealRegionInWindow = CGRect(
        x: frameBoundsInWindow.minX,
        y: frameBoundsInWindow.maxY - WindowChromeVisibilityState.compactHotZoneHeight,
        width: frameBoundsInWindow.width,
        height: WindowChromeVisibilityState.compactHotZoneHeight
      )

    case .hoverRevealed:
      let regionBottom = max(
        frameBoundsInWindow.minY,
        window.contentLayoutRect.maxY - WindowChromeVisibilityState.compactHotZoneHeight
      )
      revealRegionInWindow = CGRect(
        x: frameBoundsInWindow.minX,
        y: regionBottom,
        width: frameBoundsInWindow.width,
        height: frameBoundsInWindow.maxY - regionBottom
      )

    case .sidebarVisible:
      return
    }
    guard revealRegionInWindow.height > 0 else { return }

    let trackingArea = NSTrackingArea(
      rect: frameView.convert(revealRegionInWindow, from: nil),
      options: [.mouseEnteredAndExited, .activeAlways, .enabledDuringMouseDrag],
      owner: self,
      userInfo: nil
    )
    frameView.addTrackingArea(trackingArea)
    chromeTrackingView = frameView
    chromeTrackingArea = trackingArea
  }

  private func removeChromeTrackingArea() {
    if let chromeTrackingArea {
      chromeTrackingView?.removeTrackingArea(chromeTrackingArea)
    }
    chromeTrackingArea = nil
    chromeTrackingView = nil
    revealRegionInWindow = .zero
  }

  private func currentWindowDecorationHeight(of window: NSWindow) -> Double {
    let contentDecoration =
      currentContentSize(of: window).map {
        max(window.frame.height - $0.height, 0)
      } ?? 0
    guard let frameView = window.contentView?.superview else { return contentDecoration }
    let frameBoundsInWindow = frameView.convert(frameView.bounds, to: nil)
    let layoutDecoration = max(
      frameBoundsInWindow.height - window.contentLayoutRect.height,
      0
    )
    return max(contentDecoration, layoutDecoration)
  }

  private func updateCompactFrameForCurrentHoverGeometry(of window: NSWindow) {
    guard chromeVisibilityState.mode == .hoverRevealed else { return }
    var compactFrame = window.frame
    compactFrame.size.height = max(compactFrame.height - measuredTitlebarHeight, 1)
    compactFrameBeforeHover = compactFrame
  }

  private func updateMinimumSize(of window: NSWindow, aspectRatio: Double) {
    guard
      let minimumSize = WindowLayoutPolicy.sizePreservingHeight(
        currentHeight: WindowLayoutPolicy.minimumPreviewHeight,
        aspectRatio: aspectRatio,
        sidebarWidth: configuration.sidebarWidth,
        sidebarIsVisible: configuration.sidebarIsVisible,
        maximumSize: maximumContentSize(for: window)
      )
    else {
      return
    }

    window.contentMinSize = CGSize(width: minimumSize.width, height: minimumSize.height)
  }

  private func maximumContentSize(for window: NSWindow) -> WindowContentSize {
    guard let screenFrame = window.screen?.visibleFrame,
      let contentSize = currentContentSize(of: window)
    else {
      return WindowContentSize(width: 10_000, height: 10_000)
    }

    let horizontalDecoration = max(window.frame.width - contentSize.width, 0)
    let verticalDecoration = max(window.frame.height - contentSize.height, 0)
    let reservedTitlebarHeight =
      chromeVisibilityState.mode == .compact ? measuredTitlebarHeight : 0
    return WindowContentSize(
      width: max(screenFrame.width - horizontalDecoration, 1),
      height: max(screenFrame.height - verticalDecoration - reservedTitlebarHeight, 1)
    )
  }

  private func currentContentSize(of window: NSWindow) -> CGSize? {
    window.contentView?.bounds.size
  }

  private func rememberCurrentGeometry(of window: NSWindow) {
    lastFrame = window.frame
    lastContentSize = currentContentSize(of: window)
  }

  private func clamped(frame: CGRect, to visibleFrame: CGRect?) -> CGRect {
    guard let visibleFrame else { return frame }

    var frame = frame
    frame.size.width = min(frame.width, visibleFrame.width)
    frame.size.height = min(frame.height, visibleFrame.height)
    frame.origin.x = min(max(frame.minX, visibleFrame.minX), visibleFrame.maxX - frame.width)
    frame.origin.y = min(max(frame.minY, visibleFrame.minY), visibleFrame.maxY - frame.height)
    return frame
  }
}
