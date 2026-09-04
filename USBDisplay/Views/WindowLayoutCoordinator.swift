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
  var toggle: (() -> Void)?

  override init() {
    super.init()
    item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: nil)
    item.isBordered = true
    item.isNavigational = true
    item.target = self
    item.action = #selector(toggleSidebar)
  }

  @objc private func toggleSidebar() { toggle?() }

  func update(visible: Bool) {
    let label = visible ? "Hide Sidebar" : "Show Sidebar"
    item.label = label
    item.paletteLabel = label
    item.toolTip = label
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
  private let titlebar = NSView()
  private let divider = NSView()
  private var configuration: WindowLayoutConfiguration
  private var chrome: WindowChromeVisibilityState
  private var geometry = WindowGeometryState()
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
  private var resizeRatio: Double?
  private var resizeProposalCount = 0
  private var resizeConfiguration: WindowLayoutConfiguration?
  private var fullScreenTransition = false
  private var fullScreen = false
  private var sidebarBeforeFullScreen: Bool?
  var onSidebarChanged: (Bool) -> Void = { _ in }
  // Tests observe every committed presentation, including synchronous chrome changes.
  var onLayoutCommitted: ((WindowSurfaceLayout) -> Void)?

  init(configuration: WindowLayoutConfiguration, session: AVCaptureSession = AVCaptureSession()) {
    self.configuration = configuration
    chrome = WindowChromeVisibilityState(sidebarIsVisible: configuration.sidebarIsVisible)
    preview = PreviewHostView(session: session)
    super.init(frame: .zero)
    wantsLayer = true
    layer = CALayer()
    layer?.backgroundColor = NSColor.clear.cgColor
    autoresizingMask = [.width, .height]
    sidebar.sizingOptions = []
    status.sizingOptions = []
    for view in [preview, status, sidebar, divider, titlebar] { addSubview(view) }
    for view in [titlebar, divider] { view.wantsLayer = true }
    titlebar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
    status.isHidden = true
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.displayMode = .iconOnly
    toolbar.delegate = toolbarDelegate
    toolbarDelegate.toggle = { [weak self] in self?.toggleSidebar() }
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
    geometry.rememberPreview(
      CGRect(
        x: window.frame.minX + sidebarWidth, y: window.frame.minY,
        width: max(1, window.frame.width - sidebarWidth),
        height: max(1, window.frame.height - (chrome.showsTitlebar ? measuredTitlebar : 0))))
    installDelegate(in: window)
    installObservers(in: window)
    mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) {
      [weak self] event in
      MainActor.assumeIsolated {
        if event.window === self?.observedWindow { self?.updatePointer(event.locationInWindow) }
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
    if previous.aspectRatio != next.aspectRatio, let ratio = next.aspectRatio, !fullScreen {
      geometry.orient(aspectRatio: ratio, screen: screenFrame)
    }
    commitChrome()
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
    commitChrome()
  }

  func hideTitlebar() {
    guard !isResizing, !fullScreen, !fullScreenTransition, !configuration.sidebarIsVisible else {
      return
    }
    cancelHide()
    chrome.hideDelayElapsed()
    commitChrome()
  }

  private var sidebarWidth: Double {
    WindowLayoutPolicy.sidebarContribution(
      width: configuration.sidebarWidth, isVisible: configuration.sidebarIsVisible)
  }
  private var titlebarHeight: Double { !fullScreen && chrome.showsTitlebar ? measuredTitlebar : 0 }
  private var screenFrame: CGRect {
    observedWindow?.screen?.visibleFrame ?? CGRect(x: -5000, y: -5000, width: 10000, height: 10000)
  }

  private func commitChrome() {
    guard let window = observedWindow, !isResizing, !fullScreenTransition else { return }
    let target: WindowSurfaceLayout?
    if fullScreen {
      target = .resizing(
        frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
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
    window.hasShadow = chrome.mode == .compact && !fullScreen ? false : originalShadow
    toolbarDelegate.update(visible: configuration.sidebarIsVisible)
    toolbar.isVisible = chrome.showsTitlebar || fullScreen
    toolbar.showsBaselineSeparator = false
    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      window.standardWindowButton(type)?.isHidden = !toolbar.isVisible
    }
    surfaceLayout = target
    // No run-loop yield, intermediate outer frame, or forced display is allowed here.
    if !fullScreen, window.frame != target.frame { window.setFrame(target.frame, display: false) }
    layoutSurface()
    CATransaction.commit()
    lastWindowFrame = window.frame
    applyingGeometry = false
    updateMinimumSize()
    window.invalidateShadow()
    updateTrackingAreas()
    onLayoutCommitted?(target)
  }

  private func layoutSurface() {
    guard let window = observedWindow, let current = surfaceLayout else { return }
    let layout: WindowSurfaceLayout
    if applyingGeometry {
      layout = current
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
    let radius =
      !fullScreen && !fullScreenTransition && chrome.mode == .compact
      ? configuration.cornerRadiusFraction : 0
    preview.applyGeometry(frame: local(layout.preview), cornerFraction: radius)
    status.frame = local(layout.preview)
    status.wantsLayer = true
    status.layer?.cornerRadius = preview.layer?.cornerRadius ?? 0
    status.layer?.cornerCurve = .continuous
    status.layer?.masksToBounds = true
    sidebar.frame = local(layout.sidebar)
    sidebar.isHidden = !configuration.sidebarIsVisible
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
    guard !applyingGeometry, !fullScreen, !fullScreenTransition,
      let ratio = resizeRatio ?? configuration.aspectRatio, let layout = surfaceLayout
    else { return size }
    resizeProposalCount += 1
    let maximum = screenFrame.size
    guard
      let result = WindowLayoutPolicy.constrainedResize(
        proposedSize: WindowContentSize(
          width: size.width, height: size.height - layout.externalTitlebar),
        previousSize: WindowContentSize(
          width: window.frame.width, height: window.frame.height - layout.externalTitlebar),
        aspectRatio: ratio, sidebarWidth: max(0, layout.externalSidebar - 1),
        sidebarIsVisible: layout.externalSidebar > 0,
        maximumSize: WindowContentSize(
          width: maximum.width, height: maximum.height - layout.externalTitlebar)
      )
    else { return size }
    return CGSize(width: result.width, height: result.height + layout.externalTitlebar)
  }

  private func updateMinimumSize() {
    guard let window = observedWindow, let layout = surfaceLayout,
      let ratio = configuration.aspectRatio, !fullScreen
    else { return }
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
      host.fullScreenTransition = true
      host.sidebarBeforeFullScreen = host.configuration.sidebarIsVisible
      host.layoutSurface()
    }
    observe(NSWindow.didEnterFullScreenNotification) { host in
      host.fullScreenTransition = false
      host.fullScreen = true
      host.commitChrome()
    }
    observe(NSWindow.willExitFullScreenNotification) { $0.fullScreenTransition = true }
    observe(NSWindow.didExitFullScreenNotification) { host in
      host.fullScreenTransition = false
      host.fullScreen = false
      let visible = host.sidebarBeforeFullScreen ?? host.configuration.sidebarIsVisible
      host.sidebarBeforeFullScreen = nil
      host.configuration = host.configuration.showingSidebar(visible)
      host.chrome.updateSidebarVisibility(visible)
      if let ratio = host.configuration.aspectRatio {
        host.geometry.orient(aspectRatio: ratio, screen: host.screenFrame)
      }
      host.commitChrome()
      host.onSidebarChanged(visible)
    }
    observe(NSWindow.didChangeScreenNotification) { host in
      if !host.isResizing { host.commitChrome() }
    }
  }

  private func beginResize() {
    guard !fullScreen, !fullScreenTransition else { return }
    cancelHide()
    setupWork?.cancel()
    setupWork = nil
    isResizing = true
    resizeProposalCount = 0
    resizeRatio = configuration.aspectRatio
    resizeConfiguration = configuration
    AppLogger.interface.debug("Live resize began")
  }

  private func endResize() {
    guard isResizing, let layout = surfaceLayout else { return }
    geometry.rememberPreview(layout.previewOnScreen)
    isResizing = false
    resizeRatio = nil
    let previous = resizeConfiguration
    resizeConfiguration = nil
    observedWindow?.invalidateShadow()
    updateTrackingAreas()
    if previous?.aspectRatio != configuration.aspectRatio
      || previous?.sidebarIsVisible != configuration.sidebarIsVisible
    {
      chrome.updateSidebarVisibility(configuration.sidebarIsVisible)
      if let ratio = configuration.aspectRatio {
        geometry.orient(aspectRatio: ratio, screen: screenFrame)
      }
      commitChrome()
    }
    AppLogger.interface.debug(
      "Live resize ended after \(self.resizeProposalCount) constrained proposals")
  }

  private func resized() {
    guard !applyingGeometry else { return }
    layoutSurface()
    if let window = observedWindow { lastWindowFrame = window.frame }
    if let layout = surfaceLayout { onLayoutCommitted?(layout) }
    // The resize delegate already chose the size. No delayed correction is queued.
  }

  private func moved() {
    guard !applyingGeometry, !isResizing, !fullScreen, !fullScreenTransition,
      let window = observedWindow
    else { return }
    if let lastWindowFrame {
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
    setupWork?.cancel()
    setupWork = nil
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    mouseMonitor = nil
    if let window = observedWindow {
      if window.delegate === resizeDelegate { window.delegate = resizeDelegate?.originalDelegate }
      if window.toolbar === toolbar { window.toolbar = originalToolbar }
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
