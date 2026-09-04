import AppKit
import SwiftUI

struct WindowLayoutCoordinator: NSViewRepresentable {
  let title: String
  let aspectRatio: Double?
  let sidebarWidth: Double
  let sidebarIsVisible: Bool
  let cornerRadiusFraction: Double
  let onRestoreSidebarAfterFullScreen: (Bool) -> Void
  let onCompactPresentationChanged: (Bool) -> Void

  func makeNSView(context: Context) -> WindowLayoutHostView {
    WindowLayoutHostView(
      configuration: configuration,
      onRestoreSidebarAfterFullScreen: onRestoreSidebarAfterFullScreen,
      onCompactPresentationChanged: onCompactPresentationChanged
    )
  }

  func updateNSView(_ nsView: WindowLayoutHostView, context: Context) {
    nsView.updateRestoreSidebarAction(onRestoreSidebarAfterFullScreen)
    nsView.onCompactPresentationChanged = onCompactPresentationChanged
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
      sidebarIsVisible: sidebarIsVisible,
      cornerRadiusFraction: cornerRadiusFraction
    )
  }
}

struct WindowLayoutConfiguration: Equatable {
  let title: String
  let aspectRatio: Double?
  let sidebarWidth: Double
  let sidebarIsVisible: Bool
  let cornerRadiusFraction: Double
}

private struct WindowPresentationSnapshot {
  let isOpaque: Bool
  let backgroundColor: NSColor
  let contentViewWantsLayer: Bool
  let contentLayerCornerRadius: CGFloat
  let contentLayerMasksToBounds: Bool
  let contentLayerCornerCurve: CALayerCornerCurve?
}

@MainActor
private final class SidebarToolbarDelegate: NSObject, NSToolbarDelegate {
  nonisolated static let itemIdentifier = NSToolbarItem.Identifier(
    "USBDisplay.SidebarToggle"
  )

  private let sidebarItem: NSToolbarItem

  init(sidebarIsVisible: Bool) {
    sidebarItem = NSToolbarItem(itemIdentifier: Self.itemIdentifier)
    super.init()
    sidebarItem.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: nil)
    sidebarItem.isBordered = true
    sidebarItem.isNavigational = true
    sidebarItem.target = nil
    sidebarItem.action = #selector(NSSplitViewController.toggleSidebar(_:))
    update(sidebarIsVisible: sidebarIsVisible)
  }

  func update(sidebarIsVisible: Bool) {
    let label = sidebarIsVisible ? "Hide Sidebar" : "Show Sidebar"
    sidebarItem.label = label
    sidebarItem.paletteLabel = label
    sidebarItem.toolTip = label
  }

  nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
  {
    [Self.itemIdentifier]
  }

  nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
  {
    [Self.itemIdentifier]
  }

  nonisolated func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    MainActor.assumeIsolated {
      itemIdentifier == Self.itemIdentifier ? sidebarItem : nil
    }
  }
}

@MainActor
final class WindowResizeDelegate: NSObject, NSWindowDelegate {
  nonisolated(unsafe) weak var originalDelegate: (any NSWindowDelegate)?
  var constrain: ((NSWindow, NSSize) -> NSSize)?

  override func responds(to selector: Selector!) -> Bool {
    super.responds(to: selector) || originalDelegate?.responds(to: selector) == true
  }

  override func forwardingTarget(for selector: Selector!) -> Any? {
    if originalDelegate?.responds(to: selector) == true { return originalDelegate }
    return super.forwardingTarget(for: selector)
  }

  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    let proposed = originalDelegate?.windowWillResize?(sender, to: frameSize) ?? frameSize
    let result = constrain?(sender, proposed) ?? proposed
    AppLogger.interface.debug(
      "Resize proposal \(frameSize.width)x\(frameSize.height), constrained \(result.width)x\(result.height)"
    )
    return result
  }
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
  private var geometry = WindowGeometryState()
  private var resizeDelegate: WindowResizeDelegate?
  private var frameTimer: Timer?
  private var frameTransition: WindowFrameTransition?
  private var fullScreenTransition = false
  private var isUserResizing = false
  private var liveResizeAspectRatio: Double?
  private var liveResizeSidebar = 0.0
  private var liveResizeTitlebar = 0.0
  private var isApplyingFrame = false
  private var hideChromeWorkItem: DispatchWorkItem?
  private var chromeVisibilityState: WindowChromeVisibilityState
  private var mouseEventMonitor: Any?
  private var windowPreviouslyAcceptedMouseMovedEvents = false
  private var measuredTitlebarHeight = 0.0
  private var proportionalLayoutWorkItem: DispatchWorkItem?
  private var originalWindowPresentation: WindowPresentationSnapshot?
  private weak var capturedContentView: NSView?
  private var windowShapeIsRounded = false
  private var managedSidebarToolbar: NSToolbar?
  private var sidebarToolbarDelegate: SidebarToolbarDelegate?
  private var originalWindowToolbar: NSToolbar?
  private var didCaptureOriginalWindowToolbar = false
  private var sidebarWasVisibleBeforeFullScreen: Bool?
  private var onRestoreSidebarAfterFullScreen: (Bool) -> Void
  var onCompactPresentationChanged: (Bool) -> Void

  init(
    configuration: WindowLayoutConfiguration,
    onRestoreSidebarAfterFullScreen: @escaping (Bool) -> Void,
    onCompactPresentationChanged: @escaping (Bool) -> Void = { _ in }
  ) {
    self.configuration = configuration
    self.onRestoreSidebarAfterFullScreen = onRestoreSidebarAfterFullScreen
    self.onCompactPresentationChanged = onCompactPresentationChanged
    chromeVisibilityState = WindowChromeVisibilityState(
      sidebarIsVisible: configuration.sidebarIsVisible
    )
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  fileprivate func updateRestoreSidebarAction(_ action: @escaping (Bool) -> Void) {
    onRestoreSidebarAfterFullScreen = action
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    guard window !== observedWindow else { return }
    detachFromWindow()
    guard let window else { return }

    observedWindow = window
    scheduleManagedSidebarToolbarSetup(in: window)
    installResizeDelegate(in: window)
    installObservers(for: window)
    installMouseEventMonitor(for: window)
    measuredTitlebarHeight = currentWindowDecorationHeight(of: window)
    geometry.rememberUserGeometry(
      frame: window.frame, sidebar: sidebarContribution, titlebar: measuredTitlebarHeight
    )
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

  func updateConfiguration(_ newConfiguration: WindowLayoutConfiguration) {
    let layoutChanged =
      configuration.aspectRatio != newConfiguration.aspectRatio
      || abs(configuration.sidebarWidth - newConfiguration.sidebarWidth) >= 0.5
      || configuration.sidebarIsVisible != newConfiguration.sidebarIsVisible

    let sidebarVisibilityChanged =
      configuration.sidebarIsVisible != newConfiguration.sidebarIsVisible
    let sidebarWidthChanged =
      abs(configuration.sidebarWidth - newConfiguration.sidebarWidth) >= 0.5
    let cornerRadiusChanged =
      configuration.cornerRadiusFraction != newConfiguration.cornerRadiusFraction
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

    if cornerRadiusChanged {
      updateWindowShape(of: window, invalidateShadow: true)
    }

    if layoutChanged && !sidebarVisibilityChanged {
      scheduleProportionalLayout(
        animated: false,
        delay: sidebarWidthChanged ? WindowLayoutPolicy.sidebarResizeDebounce : 0
      )
    }
  }

  func prepareForRemoval() {
    detachFromWindow()
  }

  private func installObservers(for window: NSWindow) {
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: window,
        queue: .main
      ) { [weak self, weak window] _ in
        MainActor.assumeIsolated {
          guard let window else { return }
          self?.installManagedSidebarToolbar(in: window)
          self?.installResizeDelegate(in: window)
        }
      },
      center.addObserver(
        forName: NSWindow.willStartLiveResizeNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.handleWindowWillStartLiveResize()
        }
      },
      center.addObserver(
        forName: NSWindow.didEndLiveResizeNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.handleWindowDidEndLiveResize()
        }
      },
      center.addObserver(
        forName: NSWindow.didResizeNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.handleWindowResize()
        }
      },
      center.addObserver(
        forName: NSWindow.didMoveNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.handleWindowMove() }
      },
      center.addObserver(
        forName: NSWindow.willEnterFullScreenNotification, object: window, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.handleWillEnterFullScreen() }
      },
      center.addObserver(
        forName: NSWindow.willExitFullScreenNotification, object: window, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.fullScreenTransition = true }
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
    cancelScheduledProportionalLayout()
    cancelFrameTransition()
    if let observedWindow {
      if observedWindow.delegate === resizeDelegate {
        observedWindow.delegate = resizeDelegate?.originalDelegate
      }
      restoreNativeChrome(in: observedWindow)
      restoreOriginalToolbar(in: observedWindow)
      observedWindow.acceptsMouseMovedEvents = windowPreviouslyAcceptedMouseMovedEvents
    }
    removeMouseEventMonitor()
    removeChromeTrackingArea()
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    observedWindow = nil
    lastFrame = nil
    geometry = WindowGeometryState()
    resizeDelegate = nil
    isUserResizing = false
    fullScreenTransition = false
    originalWindowPresentation = nil
    capturedContentView = nil
    windowShapeIsRounded = false
    managedSidebarToolbar = nil
    sidebarToolbarDelegate = nil
    originalWindowToolbar = nil
    didCaptureOriginalWindowToolbar = false
    sidebarWasVisibleBeforeFullScreen = nil
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

  private func scheduleProportionalLayout(
    animated: Bool,
    delay: TimeInterval = 0
  ) {
    cancelScheduledProportionalLayout()

    let workItem = DispatchWorkItem { [weak self] in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.proportionalLayoutWorkItem = nil
        self.applyProportionalLayoutPreservingHeight(animated: animated)
      }
    }
    proportionalLayoutWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  private func cancelScheduledProportionalLayout() {
    proportionalLayoutWorkItem?.cancel()
    proportionalLayoutWorkItem = nil
  }

  private var sidebarContribution: Double {
    WindowLayoutPolicy.sidebarContribution(
      width: configuration.sidebarWidth, isVisible: configuration.sidebarIsVisible
    )
  }

  private var titlebarContribution: Double {
    chromeVisibilityState.showsTitlebar ? measuredTitlebarHeight : 0
  }

  private func installResizeDelegate(in window: NSWindow) {
    if let resizeDelegate, window.delegate === resizeDelegate { return }
    let proxy = resizeDelegate ?? WindowResizeDelegate()
    proxy.originalDelegate = window.delegate
    proxy.constrain = { [weak self] window, size in
      self?.constrainResize(of: window, to: size) ?? size
    }
    resizeDelegate = proxy
    window.delegate = proxy
  }

  private func applyProportionalLayoutPreservingHeight(animated: Bool) {
    guard let window = observedWindow,
      !isUserResizing, !window.inLiveResize, !fullScreenTransition,
      !window.styleMask.contains(.fullScreen),
      let aspectRatio = configuration.aspectRatio,
      let frame = geometry.frame(
        aspectRatio: aspectRatio, sidebar: sidebarContribution, titlebar: titlebarContribution,
        visibleFrame: window.screen?.visibleFrame ?? window.frame.insetBy(dx: -5000, dy: -5000)
      )
    else { return }
    updateMinimumSize(of: window, aspectRatio: aspectRatio)
    applyLayoutFrame(frame, to: window, animated: animated)
  }

  private func handleWindowResize() {
    guard let window = observedWindow else { return }
    updateWindowShape(of: window)
    guard !isApplyingFrame, frameTransition == nil, !fullScreenTransition,
      !window.styleMask.contains(.fullScreen)
    else { return }
    if isUserResizing || window.inLiveResize {
      rememberCurrentGeometry(of: window)
      return
    }
    guard window.frame != lastFrame else { return }
    refreshChromeTrackingArea()
    // A resize notification is an observation, never a new user size preference.
    scheduleProportionalLayout(
      animated: false, delay: WindowLayoutPolicy.nonInteractiveResizeDebounce)
  }

  private func handleWindowWillStartLiveResize() {
    guard let window = observedWindow, !fullScreenTransition,
      !window.styleMask.contains(.fullScreen)
    else { return }
    AppLogger.interface.info("Live resize began")
    cancelPendingChromeHide()
    cancelScheduledProportionalLayout()
    cancelFrameTransition()
    isUserResizing = true
    liveResizeAspectRatio = configuration.aspectRatio
    liveResizeSidebar = sidebarContribution
    liveResizeTitlebar = titlebarContribution
    removeChromeTrackingArea()
  }

  private func constrainResize(of window: NSWindow, to proposed: NSSize) -> NSSize {
    guard !isApplyingFrame, !fullScreenTransition, !window.styleMask.contains(.fullScreen),
      isUserResizing || window.inLiveResize,
      let ratio = liveResizeAspectRatio ?? configuration.aspectRatio
    else { return proposed }
    let sidebar = isUserResizing ? liveResizeSidebar : sidebarContribution
    let titlebar = isUserResizing ? liveResizeTitlebar : titlebarContribution
    let maximum = window.screen?.visibleFrame.size ?? CGSize(width: 10000, height: 10000)
    guard
      let size = WindowLayoutPolicy.constrainedResize(
        proposedSize: WindowContentSize(
          width: proposed.width, height: max(proposed.height - titlebar, 1)),
        previousSize: WindowContentSize(
          width: window.frame.width, height: max(window.frame.height - titlebar, 1)),
        aspectRatio: ratio, sidebarWidth: max(sidebar - 1, 0), sidebarIsVisible: sidebar > 0,
        maximumSize: WindowContentSize(
          width: maximum.width, height: max(maximum.height - titlebar, 1))
      )
    else { return proposed }
    return NSSize(width: size.width, height: size.height + titlebar)
  }

  private func handleWindowDidEndLiveResize() {
    guard let window = observedWindow, isUserResizing else { return }
    AppLogger.interface.info("Live resize ended at \(window.frame.width)x\(window.frame.height)")
    geometry.rememberUserGeometry(
      frame: window.frame, sidebar: liveResizeSidebar, titlebar: liveResizeTitlebar
    )
    let hasDeferredLayout =
      liveResizeAspectRatio != configuration.aspectRatio
      || liveResizeSidebar != sidebarContribution || liveResizeTitlebar != titlebarContribution
    isUserResizing = false
    liveResizeAspectRatio = nil
    rememberCurrentGeometry(of: window)
    // Only an actual orientation/sidebar change may request another frame after release.
    if hasDeferredLayout {
      applyChromeMode(
        chromeVisibilityState.mode, to: window, preservingContentSize: true, animated: false)
    }
    updateWindowShape(of: window, invalidateShadow: true)
    refreshChromeTrackingArea()
    updatePointerLocation(window.mouseLocationOutsideOfEventStream, in: window)
  }

  private func handleWindowMove() {
    guard let window = observedWindow, !isApplyingFrame, frameTransition == nil,
      !isUserResizing, !window.inLiveResize, !fullScreenTransition,
      !window.styleMask.contains(.fullScreen)
    else { return }
    if let lastFrame {
      geometry.move(
        by: CGSize(
          width: window.frame.minX - lastFrame.minX, height: window.frame.minY - lastFrame.minY
        ))
    }
    rememberCurrentGeometry(of: window)
  }

  private func cancelFrameTransition() {
    frameTimer?.invalidate()
    frameTimer = nil
    frameTransition = nil
    isApplyingFrame = false
  }

  private func applyLayoutFrame(_ frame: CGRect, to window: NSWindow, animated: Bool) {
    if frameTransition?.target == frame { return }
    cancelFrameTransition()
    guard frame != window.frame else { return }
    guard animated else {
      setManagedFrame(frame, in: window)
      return
    }
    frameTransition = WindowFrameTransition(
      start: window.frame, target: frame, startTime: ProcessInfo.processInfo.systemUptime,
      duration: WindowChromeVisibilityState.animationDuration
    )
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak window] _ in
      MainActor.assumeIsolated {
        guard let self, let window, let transition = self.frameTransition else { return }
        let now = ProcessInfo.processInfo.systemUptime
        self.setManagedFrame(transition.frame(at: now), in: window)
        if now >= transition.startTime + transition.duration {
          self.cancelFrameTransition()
          self.refreshChromeTrackingArea()
          self.updatePointerLocation(window.mouseLocationOutsideOfEventStream, in: window)
        }
      }
    }
    frameTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func setManagedFrame(_ frame: CGRect, in window: NSWindow) {
    isApplyingFrame = true
    window.setFrame(frame, display: true)
    window.contentView?.layoutSubtreeIfNeeded()
    isApplyingFrame = false
    rememberCurrentGeometry(of: window)
    updateWindowShape(of: window, invalidateShadow: true)
    if frameTransition == nil { refreshChromeTrackingArea() }
  }

  private func handleWillEnterFullScreen() {
    fullScreenTransition = true
    publishCompactPresentation(false)
    cancelPendingChromeHide()
    cancelScheduledProportionalLayout()
    cancelFrameTransition()
    sidebarWasVisibleBeforeFullScreen = configuration.sidebarIsVisible
    removeChromeTrackingArea()
  }

  private func handleDidEnterFullScreen() {
    cancelPendingChromeHide()
    cancelScheduledProportionalLayout()
    fullScreenTransition = false
    removeChromeTrackingArea()
    if let window = observedWindow {
      updateWindowShape(of: window, invalidateShadow: true)
    }
  }

  private func handleDidExitFullScreen() {
    guard let window = observedWindow else { return }
    fullScreenTransition = false
    if let sidebarWasVisibleBeforeFullScreen {
      onRestoreSidebarAfterFullScreen(sidebarWasVisibleBeforeFullScreen)
    }
    sidebarWasVisibleBeforeFullScreen = nil

    chromeVisibilityState.updateSidebarVisibility(configuration.sidebarIsVisible)
    applyChromeMode(
      chromeVisibilityState.mode,
      to: window,
      preservingContentSize: true,
      animated: false
    )
    updateWindowShape(of: window, invalidateShadow: true)
    refreshChromeTrackingArea()
  }

  private func updatePointerLocation(_ location: CGPoint, in window: NSWindow) {
    guard !configuration.sidebarIsVisible, !window.styleMask.contains(.fullScreen),
      !isUserResizing, !window.inLiveResize, !fullScreenTransition, frameTransition == nil
    else {
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
      !window.styleMask.contains(.fullScreen), !isUserResizing, !window.inLiveResize,
      !fullScreenTransition, frameTransition == nil
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
    guard !isUserResizing, !window.inLiveResize, !fullScreenTransition,
      frameTransition == nil, chromeVisibilityState.pointerExitedRevealRegion()
    else { return }
    cancelPendingChromeHide()

    let workItem = DispatchWorkItem { [weak self, weak window] in
      guard let self, let window else { return }
      MainActor.assumeIsolated {
        self.hideChromeWorkItem = nil
        guard
          !self.configuration.sidebarIsVisible,
          !self.isUserResizing, !window.inLiveResize, !self.fullScreenTransition,
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
    guard !window.styleMask.contains(.fullScreen), !fullScreenTransition, !isUserResizing else {
      return
    }
    cancelScheduledProportionalLayout()
    cancelFrameTransition()
    isApplyingFrame = true
    if chromeVisibilityState.showsTitlebar, !window.styleMask.contains(.fullSizeContentView) {
      measuredTitlebarHeight = max(
        currentWindowDecorationHeight(of: window), measuredTitlebarHeight)
    }
    // Old expanded minimums must not prevent a compact window from shrinking.
    window.contentMinSize = .zero
    window.title = configuration.title
    window.titleVisibility = .hidden
    installManagedSidebarToolbar(in: window)
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
    updateWindowShape(of: window, invalidateShadow: true)

    if mode != .compact {
      measuredTitlebarHeight = currentWindowDecorationHeight(of: window)
    }
    isApplyingFrame = false
    publishCompactPresentation(mode == .compact)
    if preservingContentSize { applyProportionalLayoutPreservingHeight(animated: animated) }
    refreshChromeTrackingArea()
  }

  private func publishCompactPresentation(_ compact: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.observedWindow != nil else { return }
      self.onCompactPresentationChanged(compact)
    }
  }

  private func scheduleManagedSidebarToolbarSetup(in window: NSWindow) {
    for delay in [0.0, 0.1, 0.5] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak window] in
        MainActor.assumeIsolated {
          guard let self, let window, self.observedWindow === window else { return }
          self.installManagedSidebarToolbar(in: window)
        }
      }
    }
  }

  private func installManagedSidebarToolbar(in window: NSWindow) {
    if !didCaptureOriginalWindowToolbar {
      originalWindowToolbar = window.toolbar
      didCaptureOriginalWindowToolbar = true
    }

    let toolbar: NSToolbar
    if let managedSidebarToolbar {
      toolbar = managedSidebarToolbar
    } else {
      let toolbarDelegate = SidebarToolbarDelegate(
        sidebarIsVisible: configuration.sidebarIsVisible
      )
      toolbar = NSToolbar(identifier: "USBDisplay.WindowToolbar")
      toolbar.allowsUserCustomization = false
      toolbar.autosavesConfiguration = false
      toolbar.displayMode = .iconOnly
      toolbar.sizeMode = .regular
      toolbar.delegate = toolbarDelegate
      sidebarToolbarDelegate = toolbarDelegate
      managedSidebarToolbar = toolbar
    }

    sidebarToolbarDelegate?.update(sidebarIsVisible: configuration.sidebarIsVisible)
    toolbar.isVisible = chromeVisibilityState.mode != .compact
    toolbar.showsBaselineSeparator = chromeVisibilityState.mode != .compact
    if window.toolbar !== toolbar {
      window.toolbar = toolbar
    }
  }

  private func restoreOriginalToolbar(in window: NSWindow) {
    if window.toolbar === managedSidebarToolbar {
      window.toolbar = originalWindowToolbar
    }
  }

  private func restoreNativeChrome(in window: NSWindow) {
    restoreWindowPresentation(in: window, clearSnapshot: true)
    window.styleMask.remove(.fullSizeContentView)
    window.titlebarAppearsTransparent = false
    window.titlebarSeparatorStyle = .automatic
    window.toolbar?.isVisible = true
    window.toolbar?.showsBaselineSeparator = true
    setTitlebarButtons(hidden: false, in: window)
  }

  private func updateWindowShape(
    of window: NSWindow,
    invalidateShadow: Bool = false
  ) {
    guard let contentView = window.contentView else { return }
    captureWindowPresentationIfNeeded(window: window, contentView: contentView)

    let shouldRound =
      chromeVisibilityState.mode == .compact
      && !window.styleMask.contains(.fullScreen)
      && configuration.cornerRadiusFraction > 0

    if shouldRound {
      window.isOpaque = false
      window.backgroundColor = .clear
      contentView.wantsLayer = true
      if let layer = contentView.layer {
        let shortSide = min(contentView.bounds.width, contentView.bounds.height)
        layer.cornerRadius = DisplayCornerProfileResolver.cornerRadius(
          shortSide: shortSide,
          fraction: configuration.cornerRadiusFraction
        )
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
      }
    } else {
      restoreWindowPresentation(in: window, clearSnapshot: false)
    }

    let shapeChanged = windowShapeIsRounded != shouldRound
    windowShapeIsRounded = shouldRound
    if shapeChanged || invalidateShadow {
      window.invalidateShadow()
    }
  }

  private func captureWindowPresentationIfNeeded(
    window: NSWindow,
    contentView: NSView
  ) {
    guard originalWindowPresentation == nil || capturedContentView !== contentView else {
      return
    }

    capturedContentView = contentView
    originalWindowPresentation = WindowPresentationSnapshot(
      isOpaque: window.isOpaque,
      backgroundColor: window.backgroundColor,
      contentViewWantsLayer: contentView.wantsLayer,
      contentLayerCornerRadius: contentView.layer?.cornerRadius ?? 0,
      contentLayerMasksToBounds: contentView.layer?.masksToBounds ?? false,
      contentLayerCornerCurve: contentView.layer?.cornerCurve
    )
  }

  private func restoreWindowPresentation(in window: NSWindow, clearSnapshot: Bool) {
    guard let snapshot = originalWindowPresentation else { return }

    window.isOpaque = snapshot.isOpaque
    window.backgroundColor = snapshot.backgroundColor
    if let contentView = capturedContentView {
      contentView.layer?.cornerRadius = snapshot.contentLayerCornerRadius
      contentView.layer?.masksToBounds = snapshot.contentLayerMasksToBounds
      if let cornerCurve = snapshot.contentLayerCornerCurve {
        contentView.layer?.cornerCurve = cornerCurve
      }
      contentView.wantsLayer = snapshot.contentViewWantsLayer
    }

    if clearSnapshot {
      originalWindowPresentation = nil
      capturedContentView = nil
      windowShapeIsRounded = false
      window.invalidateShadow()
    }
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
    let size = window.screen?.visibleFrame.size ?? CGSize(width: 10000, height: 10000)
    return WindowContentSize(width: size.width, height: max(size.height - titlebarContribution, 1))
  }

  private func currentContentSize(of window: NSWindow) -> CGSize? {
    window.contentView?.bounds.size
  }

  private func rememberCurrentGeometry(of window: NSWindow) {
    lastFrame = window.frame
  }

}
