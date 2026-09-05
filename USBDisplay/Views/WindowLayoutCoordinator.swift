@preconcurrency import AVFoundation
import AppKit
import SwiftUI

struct WindowLayoutCoordinator: NSViewRepresentable {
  let configuration: WindowLayoutConfiguration
  let session: AVCaptureSession
  let sidebar: AnyView
  let status: AnyView
  let statusIsVisible: Bool
  let onAspectRatioChanged: @MainActor (Double, Double) -> Void
  let onSidebarChanged: (Bool) -> Void

  func makeNSView(context: Context) -> WindowLayoutHostView {
    let view = WindowLayoutHostView(configuration: configuration, session: session)
    updateNSView(view, context: context)
    return view
  }

  func updateNSView(_ view: WindowLayoutHostView, context: Context) {
    view.onSidebarChanged = onSidebarChanged
    view.preview.onAspectRatioChanged = onAspectRatioChanged
    view.preview.setSession(session)
    view.updateContent(sidebar: sidebar, status: status, statusIsVisible: statusIsVisible)
    view.updateConfiguration(configuration)
  }

  static func dismantleNSView(_ view: WindowLayoutHostView, coordinator: Void) {
    view.prepareForRemoval()
  }
}

struct WindowLayoutConfiguration: Equatable {
  let title: String
  let aspectRatio: Double?
  let sidebarWidth: Double
  let sidebarIsVisible: Bool
  let cornerRadiusFraction: Double

  func showingSidebar(_ visible: Bool) -> Self {
    Self(
      title: title, aspectRatio: aspectRatio, sidebarWidth: sidebarWidth,
      sidebarIsVisible: visible, cornerRadiusFraction: cornerRadiusFraction)
  }
}

@MainActor
private final class SidebarToolbarDelegate: NSObject, NSToolbarDelegate {
  nonisolated static let identifier = NSToolbarItem.Identifier("USBDisplay.SidebarToggle")
  private let item = NSToolbarItem(itemIdentifier: identifier)
  let button = NSButton()
  var toggle: (() -> Void)?

  override init() {
    super.init()
    button.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: nil)
    button.bezelStyle = .texturedRounded
    button.imagePosition = .imageOnly
    button.frame.size = CGSize(width: 32, height: 28)
    button.wantsLayer = true
    button.target = self
    button.action = #selector(toggleSidebar)
    item.view = button
    item.isNavigational = true
  }

  @objc private func toggleSidebar() { toggle?() }

  func update(visible: Bool) {
    let label = visible ? "Hide Sidebar" : "Show Sidebar"
    item.label = label
    item.paletteLabel = label
    item.toolTip = label
    button.toolTip = label
    button.setAccessibilityLabel(label)
  }

  nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
  { [Self.identifier] }
  nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
  { [Self.identifier] }
  nonisolated func toolbar(
    _ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    MainActor.assumeIsolated { identifier == Self.identifier ? item : nil }
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
    return constrain?(sender, proposed) ?? proposed
  }
}

/// SwiftUI owns the window and value state. This container alone owns the stable
/// preview and all child frames; safe-area and toolbar layout cannot resize them.
@MainActor
final class WindowLayoutHostView: NSView {
  let preview: PreviewHostView
  private let sidebar = NSHostingView(rootView: AnyView(EmptyView()))
  private let status = NSHostingView(rootView: AnyView(EmptyView()))
  private let statusMask = RoundedContentMask()
  private let titlebar = NSView()
  private let divider = NSView()
  private var configuration: WindowLayoutConfiguration
  private var chrome: WindowChromeVisibilityState
  private var geometry = WindowGeometryState()
  private var placeholderFrame: CGRect?
  private(set) var surfaceLayout: WindowSurfaceLayout?
  private var lastWindowFrame: CGRect?
  private weak var observedWindow: NSWindow?
  private var resizeDelegate: WindowResizeDelegate?
  private let toolbarDelegate = SidebarToolbarDelegate()
  private let toolbar = NSToolbar(identifier: "USBDisplay.WindowToolbar")
  private var originalToolbar: NSToolbar?
  private var originalBackground: NSColor?
  private var originalOpaque = true
  private var originalFullSize = false
  private var originalShadow = true
  private var originalMouseMoved = false
  private var observers: [NSObjectProtocol] = []
  private var mouseMonitor: Any?
  private var tracking: NSTrackingArea?
  private var hideWork: DispatchWorkItem?
  private var setupWork: DispatchWorkItem?
  private var measuredTitlebar = 0.0
  private var applyingGeometry = false
  private var isResizing = false
  private var resizeSession: ResizeSession?
  private var resizeProposalCount = 0
  private var resizeConfiguration: WindowLayoutConfiguration?
  private var resizePointer: CGPoint?
  private var resizePlaceholderSidebar = 0.0
  private var resizeScreenSize = CGSize.zero
  private var reservedSidebar: Bool
  private var reservedTitlebar: Bool
  private var pendingReservationRelease = false
  private let animatesChrome: Bool
  let chromeAnimator: WindowChromeAnimator
  private var fullScreenTransition = false
  private var fullScreen = false
  private var sidebarBeforeFullScreen: Bool?
  var onSidebarChanged: (Bool) -> Void = { _ in }
  // Tests observe every committed presentation, including synchronous chrome changes.
  var onLayoutCommitted: ((WindowSurfaceLayout) -> Void)?

  init(
    configuration: WindowLayoutConfiguration, session: AVCaptureSession = AVCaptureSession(),
    animatesChrome: Bool = true, animationClock: @escaping () -> TimeInterval = CACurrentMediaTime
  ) {
    self.configuration = configuration
    chrome = WindowChromeVisibilityState(sidebarIsVisible: configuration.sidebarIsVisible)
    reservedSidebar = configuration.sidebarIsVisible
    reservedTitlebar = configuration.sidebarIsVisible
    self.animatesChrome = animatesChrome
    chromeAnimator = WindowChromeAnimator(
      ChromePresentation(sidebar: reservedSidebar, titlebar: reservedTitlebar),
      clock: animationClock)
    preview = PreviewHostView(session: session)
    super.init(frame: .zero)
    wantsLayer = true
    layer = CALayer()
    layer?.backgroundColor = NSColor.clear.cgColor
    autoresizingMask = [.width, .height]
    sidebar.sizingOptions = []
    status.sizingOptions = []
    for view in [preview, status, sidebar, divider, titlebar] { addSubview(view) }
    for view in [sidebar, titlebar, divider] { view.wantsLayer = true }
    titlebar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
    status.isHidden = true
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.displayMode = .iconOnly
    toolbar.delegate = toolbarDelegate
    toolbarDelegate.toggle = { [weak self] in self?.toggleSidebar() }
    chromeAnimator.onUpdate = { [weak self] _ in self?.applyChromePresentation() }
    chromeAnimator.onCompletion = { [weak self] in self?.finishChromeTransition() }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }
  override var isOpaque: Bool { false }

  func updateContent(sidebar: AnyView, status: AnyView, statusIsVisible: Bool) {
    self.sidebar.rootView = sidebar
    self.status.rootView = status
    self.status.isHidden = !statusIsVisible
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard window !== observedWindow else { return }
    detach()
    guard let window else { return }
    observedWindow = window
    originalToolbar = window.toolbar
    originalBackground = window.backgroundColor
    originalOpaque = window.isOpaque
    originalFullSize = window.styleMask.contains(.fullSizeContentView)
    originalShadow = window.hasShadow
    originalMouseMoved = window.acceptsMouseMovedEvents
    window.acceptsMouseMovedEvents = true
    // Always use one full-size transparent content coordinate system.
    window.isOpaque = false
    window.backgroundColor = .clear
    window.styleMask.insert(.fullSizeContentView)
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.titlebarSeparatorStyle = .none
    window.toolbar = toolbar
    measuredTitlebar = max(0, window.frame.height - window.contentLayoutRect.height)
    placeholderFrame = WindowLayoutPolicy.placeholderFrame(window.frame, screen: screenFrame)
    if !usesPlaceholderLayout {
      geometry.rememberPreview(
        CGRect(
          x: window.frame.minX + sidebarWidth, y: window.frame.minY,
          width: max(1, window.frame.width - sidebarWidth),
          height: max(1, window.frame.height - (chrome.showsTitlebar ? measuredTitlebar : 0))))
    }
    installDelegate(in: window)
    installObservers(in: window)
    mouseMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]
    ) {
      [weak self] event in
      MainActor.assumeIsolated {
        guard let self, let window = self.observedWindow else { return }
        if event.type == .leftMouseUp { self.resizePointer = nil }
        if event.window === window {
          if event.type == .leftMouseDown {
            self.resizePointer = window.convertPoint(toScreen: event.locationInWindow)
          } else if event.type == .mouseMoved || event.type == .leftMouseDragged {
            self.updatePointer(event.locationInWindow)
          }
        }
      }
      return event
    }
    if let ratio = configuration.aspectRatio {
      geometry.orient(aspectRatio: ratio, screen: screenFrame)
    }
    commitChrome()
    // SwiftUI finishes assigning its delegate/toolbar after attaching content.
    let setup = DispatchWorkItem { [weak self, weak window] in
      guard let self, let window, self.observedWindow === window else { return }
      self.installDelegate(in: window)
      if window.toolbar !== self.toolbar { window.toolbar = self.toolbar }
      self.setupWork = nil
      self.commitChrome()
    }
    setupWork = setup
    DispatchQueue.main.async(execute: setup)
  }

  override func layout() {
    super.layout()
    guard !applyingGeometry else { return }
    layoutSurface()
  }

  override func setFrameOrigin(_ newOrigin: NSPoint) {
    super.setFrameOrigin(newOrigin)
    if !applyingGeometry { layoutSurface() }
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let tracking { removeTrackingArea(tracking) }
    let height = chrome.showsTitlebar ? measuredTitlebar + 8 : 8
    let tracking = NSTrackingArea(
      rect: CGRect(x: 0, y: max(0, bounds.height - height), width: bounds.width, height: height),
      options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
    addTrackingArea(tracking)
    self.tracking = tracking
  }

  override func mouseEntered(with event: NSEvent) { revealTitlebar() }
  override func mouseExited(with event: NSEvent) { scheduleHide() }

  func updateConfiguration(_ next: WindowLayoutConfiguration) {
    let previous = configuration
    configuration = next
    observedWindow?.title = next.title
    guard previous != next, !isResizing, !fullScreenTransition else { return }
    if previous.sidebarIsVisible != next.sidebarIsVisible {
      cancelHide()
      chrome.updateSidebarVisibility(next.sidebarIsVisible)
    }
    if previous.aspectRatio != next.aspectRatio {
      preparePreviewGeometry()
    }
    transitionChrome()
  }

  @objc func toggleSidebar() {
    guard !isResizing, !fullScreenTransition else { return }
    let visible = !configuration.sidebarIsVisible
    updateConfiguration(configuration.showingSidebar(visible))
    onSidebarChanged(visible)
  }

  func revealTitlebar() {
    guard !isResizing, !fullScreen, !fullScreenTransition, !configuration.sidebarIsVisible else {
      return
    }
    cancelHide()
    guard chrome.mode == .compact else { return }
    chrome.pointerEnteredTopRegion()
    transitionChrome()
  }

  func hideTitlebar() {
    guard !isResizing, !fullScreen, !fullScreenTransition, !configuration.sidebarIsVisible else {
      return
    }
    cancelHide()
    chrome.hideDelayElapsed()
    transitionChrome()
  }

  private var layoutConfiguration: WindowLayoutConfiguration {
    isResizing ? (resizeConfiguration ?? configuration) : configuration
  }
  private var usesPlaceholderLayout: Bool { layoutConfiguration.aspectRatio == nil }
  private var sidebarWidth: Double {
    if usesPlaceholderLayout {
      return WindowLayoutPolicy.placeholderSidebar(
        width: Double(observedWindow?.frame.width ?? 0),
        isVisible: true)
        * (isResizing ? resizePlaceholderSidebar : chromeAnimator.presentation.sidebar)
    }
    return WindowLayoutPolicy.sidebarContribution(
      width: layoutConfiguration.sidebarWidth, isVisible: reservedSidebar)
  }
  private var titlebarHeight: Double { !fullScreen && reservedTitlebar ? measuredTitlebar : 0 }
  private var screenFrame: CGRect {
    observedWindow?.screen?.visibleFrame ?? CGRect(x: -5000, y: -5000, width: 10000, height: 10000)
  }

  private func preparePreviewGeometry() {
    guard let ratio = configuration.aspectRatio else { return }
    if geometry.previewRect == nil, let frame = placeholderFrame ?? observedWindow?.frame {
      let layout = WindowSurfaceLayout.placeholder(
        frame: frame, sidebarIsVisible: configuration.sidebarIsVisible,
        titlebar: chrome.showsTitlebar ? measuredTitlebar : 0)
      geometry.rememberPreview(layout.previewOnScreen)
    }
    if !fullScreen { geometry.orient(aspectRatio: ratio, screen: screenFrame) }
  }

  private var desiredChrome: ChromePresentation {
    ChromePresentation(
      sidebar: configuration.sidebarIsVisible, titlebar: chrome.showsTitlebar || fullScreen)
  }

  private func transitionChrome() {
    guard let window = observedWindow, !isResizing, !fullScreenTransition else { return }
    let target = desiredChrome
    guard chromeAnimator.target != target else {
      if pendingReservationRelease && !chromeAnimator.isRunning {
        finishChromeTransition()
      } else {
        commitChrome()
      }
      return
    }
    pendingReservationRelease = false
    reservedSidebar = reservedSidebar || target.sidebar > 0
    reservedTitlebar = reservedTitlebar || target.titlebar > 0
    if animatesChrome {
      preview.isGeometryChanging = true
      chromeAnimator.retarget(target, in: window, animated: true)
      // Reserve all required space before the first visible animation frame.
      commitChrome()
    } else {
      chromeAnimator.reset(to: target)
      finishChromeTransition()
    }
  }

  private func finishChromeTransition() {
    guard !isResizing else {
      pendingReservationRelease = true
      return
    }
    pendingReservationRelease = false
    reservedSidebar = chromeAnimator.target.sidebar > 0
    reservedTitlebar = chromeAnimator.target.titlebar > 0
    commitChrome()
    preview.isGeometryChanging = fullScreenTransition
  }

  private var cornerFraction: Double {
    guard !fullScreen, !fullScreenTransition else { return 0 }
    return layoutConfiguration.cornerRadiusFraction * chromeAnimator.presentation.compact
  }

  private var retainsCornerMask: Bool {
    !fullScreen && !fullScreenTransition && chromeAnimator.isRunning
      && layoutConfiguration.cornerRadiusFraction > 0
  }

  private func applyChromePresentation() {
    guard let window = observedWindow else { return }
    // Empty content may follow the animated 30/70 split; a live preview never does.
    if usesPlaceholderLayout, !isResizing, !applyingGeometry { layoutSurface() }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let value = chromeAnimator.presentation
    let travel = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.0 : 8.0
    sidebar.alphaValue = value.sidebar
    divider.alphaValue = value.sidebar
    sidebar.layer?.transform = CATransform3DMakeTranslation(-travel * (1 - value.sidebar), 0, 0)
    divider.layer?.transform = sidebar.layer?.transform ?? CATransform3DIdentity
    titlebar.alphaValue = fullScreen ? 0 : value.titlebar
    titlebar.layer?.transform = CATransform3DMakeTranslation(0, travel * (1 - value.titlebar), 0)
    // Public button APIs and our own toolbar view avoid traversing native chrome.
    if !fullScreen {
      for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(type)?.alphaValue = value.titlebar
      }
      toolbarDelegate.button.alphaValue = value.titlebar
      toolbarDelegate.button.layer?.transform = CATransform3DMakeTranslation(
        0, travel * (1 - value.titlebar), 0)
    } else {
      toolbarDelegate.button.alphaValue = 1
      toolbarDelegate.button.layer?.transform = CATransform3DIdentity
      for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(type)?.alphaValue = 1
      }
    }
    preview.applyCornerFraction(cornerFraction, retainingMask: retainsCornerMask)
    if let layer = status.layer {
      statusMask.apply(
        to: layer, bounds: status.bounds, radius: preview.displayCornerRadius,
        scale: window.backingScaleFactor, retainingMask: retainsCornerMask)
    }
    CATransaction.commit()
  }

  private func commitChrome() {
    guard let window = observedWindow, !isResizing, !fullScreenTransition else { return }
    let target: WindowSurfaceLayout?
    if fullScreen {
      target = .resizing(
        frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
        externalSidebar: sidebarWidth, externalTitlebar: titlebarHeight)
    } else if usesPlaceholderLayout {
      target = .resizing(
        frame: WindowLayoutPolicy.placeholderFrame(
          placeholderFrame ?? window.frame, screen: screenFrame),
        sidebar: sidebarWidth, titlebar: titlebarHeight,
        externalSidebar: sidebarWidth, externalTitlebar: titlebarHeight)
    } else {
      target = geometry.layout(sidebar: sidebarWidth, titlebar: titlebarHeight, screen: screenFrame)
    }
    guard let target else { return }
    applyingGeometry = true
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    window.contentMinSize = .zero
    window.minSize = .zero
    // The system shadow is outside the preview mask and can reveal the
    // rectangular window behind the rounded picture.
    window.hasShadow = !reservedSidebar && !reservedTitlebar && !fullScreen ? false : originalShadow
    toolbarDelegate.update(visible: configuration.sidebarIsVisible)
    let showsToolbar = reservedTitlebar && !fullScreen
    let isRevealingToolbar = showsToolbar && !toolbar.isVisible
    // AppKit measures navigational items when the toolbar becomes visible.
    // Restore the traffic lights and their measurement opacity first; the
    // current fade is reapplied below, inside this same nonanimated transaction.
    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      window.standardWindowButton(type)?.isHidden = !showsToolbar
      if isRevealingToolbar { window.standardWindowButton(type)?.alphaValue = 1 }
    }
    toolbar.isVisible = showsToolbar
    toolbar.showsBaselineSeparator = false
    surfaceLayout = target
    // No run-loop yield, intermediate outer frame, or forced display is allowed here.
    if !fullScreen, window.frame != target.frame { window.setFrame(target.frame, display: false) }
    // AppKit quantizes the requested frame. Using the fractional request here
    // leaves an uncovered strip until a later layout catches up.
    surfaceLayout = .resizing(
      frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
      externalSidebar: usesPlaceholderLayout ? sidebarWidth : target.externalSidebar,
      externalTitlebar: target.externalTitlebar)
    if usesPlaceholderLayout, !fullScreen { placeholderFrame = window.frame }
    layoutSurface()
    applyChromePresentation()
    CATransaction.commit()
    lastWindowFrame = window.frame
    applyingGeometry = false
    updateMinimumSize()
    window.invalidateShadow()
    updateTrackingAreas()
    if let layout = surfaceLayout { onLayoutCommitted?(layout) }
  }

  private func layoutSurface() {
    guard let window = observedWindow, let current = surfaceLayout else { return }
    let layout: WindowSurfaceLayout
    if applyingGeometry {
      layout = current
    } else if usesPlaceholderLayout {
      layout = .resizing(
        frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
        externalSidebar: sidebarWidth, externalTitlebar: titlebarHeight)
      surfaceLayout = layout
    } else {
      layout = .resizing(
        frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
        externalSidebar: fullScreen ? sidebarWidth : current.externalSidebar,
        externalTitlebar: fullScreen ? titlebarHeight : current.externalTitlebar)
      surfaceLayout = layout
    }
    // Conversion also handles any transient SwiftUI hosting-view origin change.
    let origin = convert(CGPoint.zero, from: nil)
    func local(_ rect: CGRect) -> CGRect { rect.offsetBy(dx: origin.x, dy: origin.y) }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    preview.applyGeometry(
      frame: local(layout.preview), cornerFraction: cornerFraction,
      fillsBounds: !fullScreen && !fullScreenTransition && !usesPlaceholderLayout,
      retainsCornerMask: retainsCornerMask)
    status.frame = local(layout.preview)
    status.wantsLayer = true
    if let layer = status.layer {
      statusMask.apply(
        to: layer, bounds: status.bounds, radius: preview.displayCornerRadius,
        scale: window.backingScaleFactor, retainingMask: retainsCornerMask)
    }
    sidebar.frame = local(layout.sidebar)
    sidebar.isHidden = !reservedSidebar
    divider.frame = local(
      CGRect(x: max(0, layout.sidebar.maxX - 1), y: 0, width: 1, height: layout.sidebar.height))
    divider.isHidden = sidebar.isHidden
    titlebar.frame = local(layout.titlebar)
    titlebar.isHidden = layout.titlebar.height == 0
    CATransaction.commit()
  }

  private func installDelegate(in window: NSWindow) {
    if window.delegate === resizeDelegate, resizeDelegate != nil { return }
    let proxy = resizeDelegate ?? WindowResizeDelegate()
    proxy.originalDelegate = window.delegate
    proxy.constrain = { [weak self] window, size in self?.constrain(window, size: size) ?? size }
    resizeDelegate = proxy
    window.delegate = proxy
  }

  private func constrain(_ window: NSWindow, size: NSSize) -> NSSize {
    guard !applyingGeometry, !fullScreen, !fullScreenTransition else { return size }
    if window.inLiveResize, !isResizing { beginResize() }
    if usesPlaceholderLayout {
      return WindowLayoutPolicy.placeholderSize(size, screen: screenFrame.size)
    }
    guard
      let ratio = resizeSession?.aspectRatio ?? configuration.aspectRatio,
      let layout = surfaceLayout
    else { return size }
    resizeProposalCount += 1
    if let accepted = resizeSession?.constrain(size, maximumSize: resizeScreenSize) {
      return accepted
    }
    // Native Zoom and other non-gesture proposals use a single projection.
    var proposal = ResizeSession(
      frame: window.frame, aspectRatio: ratio, externalSidebar: layout.externalSidebar,
      externalTitlebar: layout.externalTitlebar, strategy: .corner)
    return proposal.constrain(size, maximumSize: screenFrame.size)
  }

  private func updateMinimumSize() {
    guard let window = observedWindow, !fullScreen else { return }
    if usesPlaceholderLayout {
      window.minSize = WindowLayoutPolicy.placeholderSize(.zero, screen: screenFrame.size)
      return
    }
    guard let layout = surfaceLayout, let ratio = configuration.aspectRatio else { return }
    let height = min(
      WindowLayoutPolicy.minimumPreviewHeight, screenFrame.height - layout.externalTitlebar,
      (screenFrame.width - layout.externalSidebar) / ratio)
    window.minSize = CGSize(
      width: height * ratio + layout.externalSidebar, height: height + layout.externalTitlebar)
  }

  private func installObservers(in window: NSWindow) {
    func observe(
      _ name: Notification.Name, action: @escaping @MainActor (WindowLayoutHostView) -> Void
    ) {
      observers.append(
        NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) {
          [weak self] _ in
          MainActor.assumeIsolated { if let self { action(self) } }
        })
    }
    observe(NSWindow.didBecomeKeyNotification) { host in
      if let window = host.observedWindow { host.installDelegate(in: window) }
    }
    observe(NSWindow.willStartLiveResizeNotification) { $0.beginResize() }
    observe(NSWindow.didEndLiveResizeNotification) { $0.endResize() }
    observe(NSWindow.didResizeNotification) { $0.resized() }
    observe(NSWindow.didMoveNotification) { $0.moved() }
    observe(NSWindow.willEnterFullScreenNotification) { host in
      host.cancelHide()
      host.chromeAnimator.reset(to: host.desiredChrome)
      host.reservedSidebar = host.configuration.sidebarIsVisible
      host.reservedTitlebar = host.chrome.showsTitlebar
      host.pendingReservationRelease = false
      host.fullScreenTransition = true
      host.preview.isGeometryChanging = true
      host.sidebarBeforeFullScreen = host.configuration.sidebarIsVisible
      host.layoutSurface()
    }
    observe(NSWindow.didEnterFullScreenNotification) { host in
      host.fullScreenTransition = false
      host.fullScreen = true
      host.preparePreviewGeometry()
      host.chromeAnimator.reset(to: host.desiredChrome)
      host.commitChrome()
      host.preview.isGeometryChanging = false
    }
    observe(NSWindow.willExitFullScreenNotification) {
      $0.fullScreenTransition = true
      $0.preview.isGeometryChanging = true
      $0.chromeAnimator.reset(to: $0.desiredChrome)
    }
    observe(NSWindow.didExitFullScreenNotification) { host in
      host.fullScreenTransition = false
      host.fullScreen = false
      let visible = host.sidebarBeforeFullScreen ?? host.configuration.sidebarIsVisible
      host.sidebarBeforeFullScreen = nil
      host.configuration = host.configuration.showingSidebar(visible)
      host.chrome.updateSidebarVisibility(visible)
      host.reservedSidebar = visible
      host.reservedTitlebar = host.chrome.showsTitlebar
      host.chromeAnimator.reset(to: host.desiredChrome)
      host.preparePreviewGeometry()
      host.commitChrome()
      host.preview.isGeometryChanging = false
      host.onSidebarChanged(visible)
    }
    observe(NSWindow.didChangeScreenNotification) { host in
      if !host.isResizing { host.commitChrome() }
    }
  }

  private func beginResize() {
    guard !isResizing, !fullScreen, !fullScreenTransition, let window = observedWindow else {
      return
    }
    cancelHide()
    setupWork?.cancel()
    setupWork = nil
    isResizing = true
    preview.isGeometryChanging = true
    resizeProposalCount = 0
    resizeConfiguration = configuration
    resizeScreenSize = screenFrame.size
    resizePlaceholderSidebar = chromeAnimator.presentation.sidebar
    if let ratio = configuration.aspectRatio, let layout = surfaceLayout {
      var pointer = resizePointer
      if pointer == nil, window.inLiveResize, let event = NSApp.currentEvent,
        event.window === window, event.type == .leftMouseDown || event.type == .leftMouseDragged
      {
        pointer = window.convertPoint(toScreen: event.locationInWindow)
      }
      resizeSession = ResizeSession(
        frame: window.frame, aspectRatio: ratio, externalSidebar: layout.externalSidebar,
        externalTitlebar: layout.externalTitlebar,
        strategy: pointer.flatMap { ResizeSession.Strategy.at(pointer: $0, frame: window.frame) })
    }
    AppLogger.interface.debug("Live resize began")
  }

  private func endResize() {
    guard isResizing, let layout = surfaceLayout else { return }
    if usesPlaceholderLayout {
      placeholderFrame = layout.frame
    } else {
      geometry.rememberPreview(layout.previewOnScreen)
    }
    isResizing = false
    resizeSession = nil
    resizePointer = nil
    let previous = resizeConfiguration
    resizeConfiguration = nil
    updateTrackingAreas()
    if previous?.aspectRatio != configuration.aspectRatio
      || previous?.sidebarIsVisible != configuration.sidebarIsVisible
    {
      chrome.updateSidebarVisibility(configuration.sidebarIsVisible)
      if previous?.aspectRatio != configuration.aspectRatio { preparePreviewGeometry() }
      transitionChrome()
    } else if pendingReservationRelease {
      finishChromeTransition()
    } else {
      layoutSurface()
      observedWindow?.invalidateShadow()
    }
    preview.isGeometryChanging = chromeAnimator.isRunning || fullScreenTransition
    AppLogger.interface.debug(
      "Live resize ended after \(self.resizeProposalCount) constrained proposals")
  }

  private func resized() {
    guard !applyingGeometry else { return }
    if usesPlaceholderLayout, !fullScreen, !fullScreenTransition, let window = observedWindow {
      placeholderFrame = WindowLayoutPolicy.placeholderFrame(window.frame, screen: screenFrame)
      if !isResizing, placeholderFrame != window.frame {
        commitChrome()
        return
      }
    }
    layoutSurface()
    if let window = observedWindow { lastWindowFrame = window.frame }
    if let layout = surfaceLayout { onLayoutCommitted?(layout) }
    // The resize delegate already chose the size. No delayed correction is queued.
  }

  private func moved() {
    guard !applyingGeometry, !isResizing, !fullScreen, !fullScreenTransition,
      let window = observedWindow
    else { return }
    if usesPlaceholderLayout {
      placeholderFrame = window.frame
    } else if let lastWindowFrame {
      geometry.move(
        by: CGSize(
          width: window.frame.minX - lastWindowFrame.minX,
          height: window.frame.minY - lastWindowFrame.minY))
    }
    lastWindowFrame = window.frame
    layoutSurface()
  }

  private func updatePointer(_ point: CGPoint) {
    guard let window = observedWindow, !isResizing, !window.inLiveResize else { return }
    let height = chrome.showsTitlebar ? titlebarHeight + 8 : 8
    if point.y >= window.frame.height - height && point.y <= window.frame.height {
      revealTitlebar()
    } else if chrome.mode == .hoverRevealed {
      scheduleHide()
    }
  }

  private func scheduleHide() {
    guard !isResizing, !fullScreen, !fullScreenTransition, chrome.pointerExitedRevealRegion(),
      hideWork == nil
    else { return }
    let work = DispatchWorkItem { [weak self] in
      self?.hideWork = nil
      self?.hideTitlebar()
    }
    hideWork = work
    DispatchQueue.main.asyncAfter(
      deadline: .now() + WindowChromeVisibilityState.hideDelay, execute: work)
  }

  private func cancelHide() {
    hideWork?.cancel()
    hideWork = nil
  }

  func prepareForRemoval() {
    detach()
    preview.prepareForRemoval()
  }

  private func detach() {
    cancelHide()
    chromeAnimator.reset(to: chromeAnimator.target)
    resizeSession = nil
    resizeConfiguration = nil
    isResizing = false
    pendingReservationRelease = false
    preview.isGeometryChanging = false
    setupWork?.cancel()
    setupWork = nil
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    mouseMonitor = nil
    if let window = observedWindow {
      if window.delegate === resizeDelegate { window.delegate = resizeDelegate?.originalDelegate }
      if window.toolbar === toolbar { window.toolbar = originalToolbar }
      for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(type)?.alphaValue = 1
        window.standardWindowButton(type)?.isHidden = false
      }
      window.isOpaque = originalOpaque
      window.hasShadow = originalShadow
      if let originalBackground { window.backgroundColor = originalBackground }
      if !originalFullSize { window.styleMask.remove(.fullSizeContentView) }
      window.acceptsMouseMovedEvents = originalMouseMoved
    }
    observedWindow = nil
    resizeDelegate = nil
  }
}
