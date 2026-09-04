import AppKit
import SwiftUI

struct WindowLayoutCoordinator: NSViewRepresentable {
  let title: String
  let aspectRatio: Double?
  let sidebarWidth: Double
  let sidebarIsVisible: Bool
  let cornerRadiusFraction: Double
  let onRestoreSidebarAfterFullScreen: () -> Void

  func makeNSView(context: Context) -> WindowLayoutHostView {
    WindowLayoutHostView(
      configuration: configuration,
      onRestoreSidebarAfterFullScreen: onRestoreSidebarAfterFullScreen
    )
  }

  func updateNSView(_ nsView: WindowLayoutHostView, context: Context) {
    nsView.updateRestoreSidebarAction(onRestoreSidebarAfterFullScreen)
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

private struct WindowLayoutConfiguration: Equatable {
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
  private var layoutTransitionGeneration = 0
  private var proportionalLayoutWorkItem: DispatchWorkItem?
  private var liveResizeStartFrame: CGRect?
  private var liveResizeStartContentSize: CGSize?
  private var originalWindowPresentation: WindowPresentationSnapshot?
  private weak var capturedContentView: NSView?
  private var windowShapeIsRounded = false
  private var managedSidebarToolbar: NSToolbar?
  private var sidebarToolbarDelegate: SidebarToolbarDelegate?
  private var originalWindowToolbar: NSToolbar?
  private var didCaptureOriginalWindowToolbar = false
  private var sidebarWasVisibleBeforeFullScreen: Bool?
  private var sidebarVisibilityChangedDuringFullScreen = false
  private var onRestoreSidebarAfterFullScreen: () -> Void

  fileprivate init(
    configuration: WindowLayoutConfiguration,
    onRestoreSidebarAfterFullScreen: @escaping () -> Void
  ) {
    self.configuration = configuration
    self.onRestoreSidebarAfterFullScreen = onRestoreSidebarAfterFullScreen
    chromeVisibilityState = WindowChromeVisibilityState(
      sidebarIsVisible: configuration.sidebarIsVisible
    )
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  fileprivate func updateRestoreSidebarAction(_ action: @escaping () -> Void) {
    onRestoreSidebarAfterFullScreen = action
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    guard window !== observedWindow else { return }
    detachFromWindow()
    guard let window else { return }

    observedWindow = window
    scheduleManagedSidebarToolbarSetup(in: window)
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
    let sidebarWidthChanged =
      abs(configuration.sidebarWidth - newConfiguration.sidebarWidth) >= 0.5
    let cornerRadiusChanged =
      configuration.cornerRadiusFraction != newConfiguration.cornerRadiusFraction
    configuration = newConfiguration
    guard let window = observedWindow else { return }
    if sidebarVisibilityChanged, window.styleMask.contains(.fullScreen) {
      sidebarVisibilityChangedDuringFullScreen = true
    }
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

    if layoutChanged {
      let delay =
        sidebarVisibilityChanged
        ? WindowChromeVisibilityState.animationDuration
        : (sidebarWidthChanged ? WindowLayoutPolicy.sidebarResizeDebounce : 0)
      scheduleProportionalLayout(
        animated: sidebarVisibilityChanged,
        delay: delay
      )
    }
  }

  fileprivate func prepareForRemoval() {
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
    cancelScheduledProportionalLayout()
    chromeTransitionGeneration += 1
    layoutTransitionGeneration += 1
    if let observedWindow {
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
    lastContentSize = nil
    compactFrameBeforeHover = nil
    liveResizeStartFrame = nil
    liveResizeStartContentSize = nil
    originalWindowPresentation = nil
    capturedContentView = nil
    windowShapeIsRounded = false
    managedSidebarToolbar = nil
    sidebarToolbarDelegate = nil
    originalWindowToolbar = nil
    didCaptureOriginalWindowToolbar = false
    sidebarWasVisibleBeforeFullScreen = nil
    sidebarVisibilityChangedDuringFullScreen = false
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

  private func applyProportionalLayoutPreservingHeight(animated: Bool) {
    if isApplyingFrame {
      scheduleProportionalLayout(
        animated: animated,
        delay: WindowLayoutPolicy.nonInteractiveResizeDebounce
      )
      return
    }

    guard
      let window = observedWindow,
      !window.inLiveResize,
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
    if abs(desiredSize.width - contentSize.width) < 1,
      abs(desiredSize.height - contentSize.height) < 1
    {
      rememberCurrentGeometry(of: window)
      return
    }

    apply(
      desiredContentSize: desiredSize,
      to: window,
      anchoringAgainst: nil,
      animated: animated
    )
  }

  private func handleWindowResize() {
    guard let window = observedWindow else { return }
    refreshChromeTrackingArea()
    updateWindowShape(of: window)

    guard !isApplyingFrame else { return }

    if window.inLiveResize {
      updateCompactFrameForCurrentHoverGeometry(of: window)
      return
    }

    rememberCurrentGeometry(of: window)
    updateCompactFrameForCurrentHoverGeometry(of: window)
    scheduleProportionalLayout(
      animated: false,
      delay: WindowLayoutPolicy.nonInteractiveResizeDebounce
    )
  }

  private func handleWindowWillStartLiveResize() {
    guard let window = observedWindow, !window.styleMask.contains(.fullScreen) else {
      return
    }

    cancelScheduledProportionalLayout()
    layoutTransitionGeneration += 1
    liveResizeStartFrame = window.frame
    liveResizeStartContentSize = currentContentSize(of: window)
  }

  private func handleWindowDidEndLiveResize() {
    guard let window = observedWindow else { return }

    let startFrame = liveResizeStartFrame
    let startContentSize = liveResizeStartContentSize
    liveResizeStartFrame = nil
    liveResizeStartContentSize = nil

    guard
      let aspectRatio = configuration.aspectRatio,
      WindowLayoutPolicy.shouldConstrainWindow(
        isFullScreen: window.styleMask.contains(.fullScreen),
        aspectRatio: aspectRatio
      ),
      let proposedSize = currentContentSize(of: window),
      let previousSize = startContentSize,
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
      rememberCurrentGeometry(of: window)
      return
    }

    updateMinimumSize(of: window, aspectRatio: aspectRatio)
    if abs(desiredSize.width - proposedSize.width) < 1,
      abs(desiredSize.height - proposedSize.height) < 1
    {
      rememberCurrentGeometry(of: window)
      return
    }

    apply(
      desiredContentSize: desiredSize,
      to: window,
      anchoringAgainst: startFrame,
      animated: true
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

    var frame = WindowLayoutPolicy.frameByApplyingContentSize(
      currentFrame: window.frame,
      currentContentSize: WindowContentSize(
        width: currentContentSize.width,
        height: currentContentSize.height
      ),
      desiredContentSize: desiredContentSize,
      anchoringAgainst: previousFrame
    )
    frame = clamped(frame: frame, to: window.screen?.visibleFrame)
    applyLayoutFrame(frame, to: window, animated: animated)
  }

  private func applyLayoutFrame(_ frame: CGRect, to window: NSWindow, animated: Bool) {
    layoutTransitionGeneration += 1
    let generation = layoutTransitionGeneration
    isApplyingFrame = true

    guard animated else {
      window.setFrame(frame, display: true)
      isApplyingFrame = false
      rememberCurrentGeometry(of: window)
      updateWindowShape(of: window, invalidateShadow: true)
      return
    }

    NSAnimationContext.runAnimationGroup { context in
      context.duration = WindowLayoutPolicy.resizeSnapAnimationDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      window.animator().setFrame(frame, display: true)
    } completionHandler: { [weak self, weak window] in
      guard let self, let window else { return }
      MainActor.assumeIsolated {
        guard generation == self.layoutTransitionGeneration else { return }
        self.isApplyingFrame = false
        self.rememberCurrentGeometry(of: window)
        self.updateWindowShape(of: window, invalidateShadow: true)
        self.refreshChromeTrackingArea()
      }
    }
  }

  private func handleDidEnterFullScreen() {
    cancelPendingChromeHide()
    cancelScheduledProportionalLayout()
    chromeTransitionGeneration += 1
    sidebarWasVisibleBeforeFullScreen = configuration.sidebarIsVisible
    sidebarVisibilityChangedDuringFullScreen = false
    removeChromeTrackingArea()
    if let window = observedWindow {
      updateWindowShape(of: window, invalidateShadow: true)
    }
  }

  private func handleDidExitFullScreen() {
    guard let window = observedWindow else { return }
    let shouldRestoreSidebar =
      sidebarWasVisibleBeforeFullScreen == true
      && !sidebarVisibilityChangedDuringFullScreen
    sidebarWasVisibleBeforeFullScreen = nil
    sidebarVisibilityChangedDuringFullScreen = false

    if shouldRestoreSidebar {
      onRestoreSidebarAfterFullScreen()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak window] in
        MainActor.assumeIsolated {
          guard
            let self,
            let window,
            self.observedWindow === window,
            !self.configuration.sidebarIsVisible
          else {
            return
          }
          self.onRestoreSidebarAfterFullScreen()
        }
      }
    }

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

  private func applyChromeFrame(_ frame: CGRect, to window: NSWindow, animated: Bool) {
    chromeTransitionGeneration += 1
    let generation = chromeTransitionGeneration
    isApplyingFrame = true

    guard animated else {
      window.setFrame(frame, display: true)
      isApplyingFrame = false
      rememberCurrentGeometry(of: window)
      updateWindowShape(of: window, invalidateShadow: true)
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
