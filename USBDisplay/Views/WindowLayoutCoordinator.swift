@preconcurrency import AVFoundation
import AppKit
import SwiftUI

struct WindowLayoutCoordinator: NSViewRepresentable {
  let configuration: WindowLayoutConfiguration
  let session: AVCaptureSession
  let source: PreviewSource?
  let sidebar: AnyView
  let status: AnyView
  let statusIsVisible: Bool
  let onAspectRatioChanged: @MainActor (PreviewSource, Double, Double) -> Void
  let onSidebarChanged: (Bool) -> Void
  let onSidebarWidthChanged: (Double) -> Void

  func makeNSView(context: Context) -> WindowLayoutHostView {
    let view = WindowLayoutHostView(configuration: configuration, session: session)
    updateNSView(view, context: context)
    return view
  }

  func updateNSView(_ view: WindowLayoutHostView, context: Context) {
    view.onSidebarChanged = onSidebarChanged
    view.onSidebarWidthChanged = onSidebarWidthChanged
    view.preview.onAspectRatioChanged = onAspectRatioChanged
    view.preview.setSession(session)
    view.preview.setSource(source)
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
  let sidebarWidth: Double?
  let sidebarIsVisible: Bool
  let cornerRadiusFraction: Double

  func showingSidebar(_ visible: Bool) -> Self {
    Self(
      title: title, aspectRatio: aspectRatio, sidebarWidth: sidebarWidth,
      sidebarIsVisible: visible, cornerRadiusFraction: cornerRadiusFraction)
  }

  func resizingSidebar(to width: Double) -> Self {
    Self(
      title: title, aspectRatio: aspectRatio, sidebarWidth: width,
      sidebarIsVisible: sidebarIsVisible, cornerRadiusFraction: cornerRadiusFraction)
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
  private let sidebarSplit = SidebarSplitView()
  private var sidebarResizeLayout: WindowSurfaceLayout?
  private var sidebarResizeConfiguration: WindowLayoutConfiguration?
  private var sidebarResizeGeometry: WindowGeometryState?
  private var configuration: WindowLayoutConfiguration
  private var chrome: WindowChromeVisibilityState
  private var geometry = WindowGeometryState()
  private var placeholderFrame: CGRect?
  private(set) var surfaceLayout: WindowSurfaceLayout?
  private var lastWindowFrame: CGRect?
  private var lastSettledWindowSize: CGSize?
  private weak var observedWindow: NSWindow?
  private let events = WindowEventBridge()
  private let toolbarDelegate = SidebarToolbarDelegate()
  private var toolbar: NSToolbar { toolbarDelegate.toolbar }
  private var originalToolbar: NSToolbar?
  private var originalToolbarStyle: NSWindow.ToolbarStyle = .automatic
  private var originalBackground: NSColor?
  private var originalOpaque = true
  private var originalFullSize = false
  private var originalShadow = true
  private var originalMouseMoved = false
  private var tracking: NSTrackingArea?
  private let hoverScheduler: WindowHoverScheduler
  private var setupWork: DispatchWorkItem?
  private var measuredTitlebar = 0.0
  private var applyingGeometry = false
  private var pendingScreenChange = false
  private var lastLayoutScreen: CGRect?
  private let screenFrameProvider: (NSWindow) -> CGRect
  private let isFullScreen: (NSWindow) -> Bool
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
  private var fullScreenSidebarVisible = false
  var onSidebarChanged: (Bool) -> Void = { _ in }
  var onSidebarWidthChanged: (Double) -> Void = { _ in }
  // Tests observe every committed presentation, including synchronous chrome changes.
  var onLayoutCommitted: ((WindowSurfaceLayout) -> Void)?

  init(
    configuration: WindowLayoutConfiguration, session: AVCaptureSession = AVCaptureSession(),
    animatesChrome: Bool = true, animationClock: @escaping () -> TimeInterval = CACurrentMediaTime,
    hoverScheduler: WindowHoverScheduler = WindowHoverScheduler(),
    screenFrame: @escaping (NSWindow) -> CGRect = {
      $0.screen?.visibleFrame ?? CGRect(x: -5000, y: -5000, width: 10000, height: 10000)
    },
    isFullScreen: @escaping (NSWindow) -> Bool = { $0.styleMask.contains(.fullScreen) }
  ) {
    self.configuration = configuration
    self.hoverScheduler = hoverScheduler
    screenFrameProvider = screenFrame
    self.isFullScreen = isFullScreen
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
    sidebarSplit.addArrangedSubview(sidebar)
    sidebarSplit.addArrangedSubview(SplitPassthroughView())
    for view in [preview, status, sidebarSplit, titlebar] { addSubview(view) }
    for view in [sidebarSplit, titlebar] { view.wantsLayer = true }
    refreshAppearance()
    status.isHidden = true
    toolbarDelegate.toggle = { [weak self] in self?.toggleSidebar() }
    sidebarSplit.onBeginResize = { [weak self] in self?.beginSidebarResize() }
    sidebarSplit.onWidthChanged = { [weak self] width in self?.resizeSidebar(to: width) }
    sidebarSplit.onEndResize = { [weak self] in self?.endSidebarResize() }
    events.constrain = { [weak self] window, size in self?.constrain(window, size: size) ?? size }
    events.fullScreenFailed = { [weak self] window in self?.recoverFullScreenFailure(in: window) }
    events.onEvent = { [weak self] event in self?.handleWindowEvent(event) }
    events.onMouse = { [weak self] event in self?.handleMouseEvent(event) }
    chromeAnimator.onUpdate = { [weak self] _ in self?.applyChromePresentation() }
    chromeAnimator.onCompletion = { [weak self] in self?.finishChromeTransition() }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }
  override var isOpaque: Bool { false }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    refreshAppearance()
  }

  private func refreshAppearance() {
    effectiveAppearance.performAsCurrentDrawingAppearance {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      titlebar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
      CATransaction.commit()
    }
  }

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
    originalToolbarStyle = window.toolbarStyle
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
    window.toolbarStyle = .unified
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
    events.attach(to: window)
    refreshAppearance()
    if let ratio = configuration.aspectRatio {
      geometry.orient(aspectRatio: ratio)
    }
    commitChrome()
    // SwiftUI finishes assigning its delegate/toolbar after attaching content.
    let setup = DispatchWorkItem { [weak self, weak window] in
      guard let self, let window, self.observedWindow === window else { return }
      self.events.installDelegate(in: window)
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
    let hotZone = WindowChromeVisibilityState.compactHotZoneHeight
    let height = chrome.showsTitlebar ? measuredTitlebar + hotZone : hotZone
    let tracking = NSTrackingArea(
      rect: fullScreen
        ? bounds
        : CGRect(
          x: 0, y: max(0, bounds.height - height), width: bounds.width, height: height),
      options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: self, userInfo: nil)
    addTrackingArea(tracking)
    self.tracking = tracking
  }

  override func mouseEntered(with event: NSEvent) {
    if fullScreen { updatePointer(event.locationInWindow) } else { revealTitlebar() }
  }
  override func mouseMoved(with event: NSEvent) { updatePointer(event.locationInWindow) }
  override func mouseExited(with event: NSEvent) {
    if fullScreen, let window = observedWindow {
      updatePointer(window.convertPoint(fromScreen: NSEvent.mouseLocation))
    } else {
      scheduleHide()
    }
  }

  func updateConfiguration(_ next: WindowLayoutConfiguration) {
    let previous = configuration
    configuration = next
    observedWindow?.title = next.title
    guard previous != next, !isResizing, !fullScreenTransition, sidebarResizeLayout == nil else {
      return
    }
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
    if fullScreen {
      cancelHide()
      fullScreenSidebarVisible.toggle()
      transitionChrome()
      return
    }
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
    sidebarResizeConfiguration
      ?? (isResizing ? (resizeConfiguration ?? configuration) : configuration)
  }

  private func beginSidebarResize() {
    guard !isResizing, !fullScreenTransition else { return }
    cancelHide()
    if chromeAnimator.isRunning {
      chromeAnimator.reset(to: desiredChrome)
      finishChromeTransition()
    }
    sidebarResizeLayout = surfaceLayout
    sidebarResizeConfiguration = configuration
    sidebarResizeGeometry = geometry
    preview.isGeometryChanging = true
  }

  private func resizeSidebar(to proposedWidth: Double) {
    guard proposedWidth.isFinite, !isResizing, !fullScreenTransition,
      let current = surfaceLayout
    else { return }
    let start = sidebarResizeLayout ?? current
    let maximum: Double
    if !fullScreen, !usesPlaceholderLayout, start.externalSidebar > 0 {
      maximum =
        screenFrame.maxX - start.frame.minX - start.preview.width - sidebarSplit.dividerThickness
    } else {
      maximum =
        start.frame.width - WindowLayoutPolicy.minimumSidebarWidth - sidebarSplit.dividerThickness
    }
    let width = min(
      max(proposedWidth, min(WindowLayoutPolicy.minimumSidebarWidth, maximum)),
      min(WindowLayoutPolicy.maximumSidebarWidth, maximum))
    if !fullScreen, !usesPlaceholderLayout, start.externalSidebar > 0 {
      if let initial = sidebarResizeGeometry { geometry = initial }
      geometry.move(
        by: CGSize(width: width + sidebarSplit.dividerThickness - start.sidebar.width, height: 0))
    }
    configuration = configuration.resizingSidebar(to: width)
    sidebarResizeConfiguration = sidebarResizeConfiguration?.resizingSidebar(to: width)
    commitChrome()
    if sidebarResizeLayout == nil { onSidebarWidthChanged(width) }
  }

  private func endSidebarResize() {
    let previous = sidebarResizeConfiguration
    if let width = previous?.sidebarWidth {
      configuration = configuration.resizingSidebar(to: width)
    }
    sidebarResizeLayout = nil
    sidebarResizeConfiguration = nil
    sidebarResizeGeometry = nil
    if previous?.aspectRatio != configuration.aspectRatio { preparePreviewGeometry() }
    chrome.updateSidebarVisibility(configuration.sidebarIsVisible)
    transitionChrome()
    preview.isGeometryChanging = chromeAnimator.isRunning || fullScreenTransition
    if let width = configuration.sidebarWidth { onSidebarWidthChanged(width) }
    if pendingScreenChange { screenChanged() }
  }
  private var usesPlaceholderLayout: Bool { layoutConfiguration.aspectRatio == nil }
  private var sidebarWidth: Double {
    if usesPlaceholderLayout {
      let width = Double(observedWindow?.frame.width ?? 0)
      let preferred =
        layoutConfiguration.sidebarWidth.map { $0 + sidebarSplit.dividerThickness }
        ?? WindowLayoutPolicy.placeholderSidebar(width: width, isVisible: true)
      return min(preferred, max(0, width - WindowLayoutPolicy.minimumSidebarWidth))
        * (isResizing ? resizePlaceholderSidebar : chromeAnimator.presentation.sidebar)
    }
    return WindowLayoutPolicy.sidebarContribution(
      width: layoutConfiguration.sidebarWidth ?? WindowLayoutPolicy.defaultSidebarWidth,
      isVisible: reservedSidebar)
  }
  private var titlebarHeight: Double {
    if fullScreen, let window = observedWindow {
      return min(window.frame.height, max(0, window.frame.height - window.contentLayoutRect.maxY))
    }
    return reservedTitlebar ? measuredTitlebar : 0
  }
  private var screenFrame: CGRect {
    observedWindow.map(screenFrameProvider) ?? .zero
  }

  private func preparePreviewGeometry() {
    guard let ratio = configuration.aspectRatio else { return }
    if geometry.previewRect == nil, let frame = placeholderFrame ?? observedWindow?.frame {
      let layout = WindowSurfaceLayout.placeholder(
        frame: frame, sidebarIsVisible: configuration.sidebarIsVisible,
        titlebar: chrome.showsTitlebar ? measuredTitlebar : 0)
      geometry.rememberPreview(layout.previewOnScreen)
    }
    if !fullScreen { geometry.orient(aspectRatio: ratio) }
  }

  private var desiredChrome: ChromePresentation {
    ChromePresentation(
      sidebar: fullScreen ? fullScreenSidebarVisible : configuration.sidebarIsVisible,
      titlebar: chrome.showsTitlebar || fullScreen)
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
    sidebarSplit.alphaValue = value.sidebar
    sidebarSplit.layer?.transform = CATransform3DMakeTranslation(
      -travel * (1 - value.sidebar), 0, 0)
    titlebar.alphaValue = fullScreen ? 0 : value.titlebar
    titlebar.layer?.transform = CATransform3DMakeTranslation(0, travel * (1 - value.titlebar), 0)
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
        externalSidebar: 0, externalTitlebar: 0)
    } else if usesPlaceholderLayout {
      target = .resizing(
        frame: WindowLayoutPolicy.placeholderFrame(
          placeholderFrame ?? window.frame, screen: screenFrame),
        sidebar: sidebarWidth, titlebar: titlebarHeight,
        externalSidebar: sidebarWidth, externalTitlebar: titlebarHeight)
    } else {
      target = geometry.layout(
        sidebar: sidebarWidth, titlebar: titlebarHeight, screen: screenFrame,
        overlaysTitlebar: !reservedSidebar)
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
    toolbarDelegate.update(
      visible: fullScreen ? fullScreenSidebarVisible : configuration.sidebarIsVisible)
    // Full-screen toolbar visibility and traffic-light animation belong to AppKit.
    // Ordinary-window compact controls still use the app's existing reveal behavior.
    if !fullScreen {
      let showsToolbar = reservedTitlebar
      // Deferred native toolbar layout must always measure visible window buttons.
      // Fading them to zero can make AppKit place the sidebar item over them.
      for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(type)?.isHidden = !showsToolbar
      }
      if toolbar.isVisible != showsToolbar { toolbar.isVisible = showsToolbar }
    }
    surfaceLayout = target
    // No run-loop yield, intermediate outer frame, or forced display is allowed here.
    if !fullScreen, window.frame != target.frame { window.setFrame(target.frame, display: false) }
    // AppKit quantizes the requested frame. Using the fractional request here
    // leaves an uncovered strip until a later layout catches up.
    surfaceLayout = .resizing(
      frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
      externalSidebar: fullScreen
        ? 0 : (usesPlaceholderLayout ? sidebarWidth : target.externalSidebar),
      externalTitlebar: target.externalTitlebar)
    if usesPlaceholderLayout, !fullScreen { placeholderFrame = window.frame }
    layoutSurface()
    applyChromePresentation()
    CATransaction.commit()
    lastWindowFrame = window.frame
    lastLayoutScreen = screenFrame
    lastSettledWindowSize = window.frame.size
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
    } else if fullScreen {
      layout = .resizing(
        frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
        externalSidebar: 0, externalTitlebar: 0)
      surfaceLayout = layout
    } else if usesPlaceholderLayout {
      layout = .resizing(
        frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
        externalSidebar: sidebarWidth, externalTitlebar: titlebarHeight)
      surfaceLayout = layout
    } else {
      layout = .resizing(
        frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
        externalSidebar: current.externalSidebar,
        externalTitlebar: current.externalTitlebar)
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
    layoutControls(layout)
    CATransaction.commit()
  }

  private func layoutControls(_ layout: WindowSurfaceLayout) {
    let origin = convert(CGPoint.zero, from: nil)
    func local(_ rect: CGRect) -> CGRect { rect.offsetBy(dx: origin.x, dy: origin.y) }
    sidebarSplit.applyGeometry(
      frame: local(CGRect(x: 0, y: 0, width: layout.frame.width, height: layout.sidebar.height)),
      sidebarWidth: max(0, layout.sidebar.width - sidebarSplit.dividerThickness))
    sidebarSplit.isHidden = !reservedSidebar
    titlebar.frame = local(layout.titlebar)
    titlebar.isHidden = fullScreen || layout.titlebar.height == 0
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

  private func handleMouseEvent(_ event: NSEvent) {
    guard let window = observedWindow else { return }
    if event.type == .leftMouseUp {
      resizePointer = nil
      sidebarSplit.endResize()
    }
    if event.window === window {
      if event.type == .leftMouseDown {
        resizePointer = window.convertPoint(toScreen: event.locationInWindow)
        if sidebarSplit.containsDivider(at: sidebarSplit.convert(event.locationInWindow, from: nil))
        {
          sidebarSplit.beginResize()
        }
      } else if event.type == .mouseMoved || event.type == .leftMouseDragged {
        updatePointer(event.locationInWindow)
      }
    } else if fullScreen, event.type == .mouseMoved, let eventWindow = event.window {
      // The native auto-hide toolbar lives in a separate AppKit window.
      updatePointer(
        window.convertPoint(
          fromScreen:
            eventWindow.convertPoint(toScreen: event.locationInWindow)))
    }
  }

  private func handleWindowEvent(_ event: WindowEvent) {
    switch event {
    case .contentLayoutChanged:
      guard fullScreen, !fullScreenTransition, !applyingGeometry else {
        return
      }
      guard reservedSidebar, let window = observedWindow else { return }
      let layout = WindowSurfaceLayout.resizing(
        frame: window.frame, sidebar: sidebarWidth, titlebar: titlebarHeight,
        externalSidebar: 0, externalTitlebar: 0)
      surfaceLayout = layout
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      layoutControls(layout)
      CATransaction.commit()
      onLayoutCommitted?(layout)
    case .becameKey:
      if let window = observedWindow { events.installDelegate(in: window) }
    case .beganResize: beginResize()
    case .endedResize: endResize()
    case .resized: resized()
    case .moved: moved()
    case .willEnterFullScreen:
      cancelHide()
      fullScreenTransition = true
      chromeAnimator.reset(to: desiredChrome)
      reservedSidebar = configuration.sidebarIsVisible
      reservedTitlebar = chrome.showsTitlebar
      pendingReservationRelease = false
      preview.isGeometryChanging = true
      sidebarBeforeFullScreen = configuration.sidebarIsVisible
      layoutSurface()
    case .enteredFullScreen:
      fullScreenTransition = false
      pendingScreenChange = false
      fullScreen = true
      fullScreenSidebarVisible = false
      reservedSidebar = false
      preparePreviewGeometry()
      chromeAnimator.reset(to: desiredChrome)
      commitChrome()
      preview.isGeometryChanging = false
    case .willExitFullScreen:
      fullScreenTransition = true
      preview.isGeometryChanging = true
      chromeAnimator.reset(to: desiredChrome)
    case .exitedFullScreen:
      fullScreenTransition = false
      pendingScreenChange = false
      fullScreen = false
      fullScreenSidebarVisible = false
      cancelHide()
      let visible = sidebarBeforeFullScreen ?? configuration.sidebarIsVisible
      sidebarBeforeFullScreen = nil
      configuration = configuration.showingSidebar(visible)
      chrome.updateSidebarVisibility(visible)
      reservedSidebar = visible
      reservedTitlebar = chrome.showsTitlebar
      chromeAnimator.reset(to: desiredChrome)
      preparePreviewGeometry()
      commitChrome()
      preview.isGeometryChanging = false
      onSidebarChanged(visible)
    case .screenChanged: screenChanged()
    }
  }

  private func screenChanged() {
    pendingScreenChange = true
    guard !isResizing, !fullScreenTransition, sidebarResizeLayout == nil else { return }
    pendingScreenChange = false
    commitChrome()
  }

  private func recoverFullScreenFailure(in window: NSWindow) {
    guard window === observedWindow else { return }
    cancelHide()
    fullScreenTransition = false
    fullScreen = isFullScreen(window)
    pendingReservationRelease = false
    if fullScreen {
      reservedSidebar = fullScreenSidebarVisible
      reservedTitlebar = true
    } else {
      fullScreenSidebarVisible = false
      let visible = sidebarBeforeFullScreen ?? configuration.sidebarIsVisible
      sidebarBeforeFullScreen = nil
      configuration = configuration.showingSidebar(visible)
      chrome.updateSidebarVisibility(visible)
      reservedSidebar = visible
      reservedTitlebar = chrome.showsTitlebar
      preparePreviewGeometry()
      onSidebarChanged(visible)
    }
    chromeAnimator.reset(to: desiredChrome)
    pendingScreenChange = false
    commitChrome()
    preview.isGeometryChanging = false
    updatePointer(window.convertPoint(fromScreen: NSEvent.mouseLocation))
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
    if pendingScreenChange { screenChanged() }
    preview.isGeometryChanging = chromeAnimator.isRunning || fullScreenTransition
    AppLogger.interface.debug(
      "Live resize ended after \(self.resizeProposalCount) constrained proposals")
  }

  private func resized() {
    guard !applyingGeometry else { return }
    // Screen adaptation must never become the user's new preferred size.
    if !fullScreen, !fullScreenTransition, lastLayoutScreen != screenFrame {
      screenChanged()
      if !isResizing { return }
    }
    if usesPlaceholderLayout, !fullScreen, !fullScreenTransition, let window = observedWindow {
      placeholderFrame = WindowLayoutPolicy.placeholderFrame(window.frame, screen: screenFrame)
      if !isResizing, placeholderFrame != window.frame {
        commitChrome()
        return
      }
    }
    layoutSurface()
    if !isResizing, !fullScreen, !fullScreenTransition,
      !pendingScreenChange, let layout = surfaceLayout, let ratio = configuration.aspectRatio,
      layout.frame.size != lastSettledWindowSize,
      abs(layout.preview.width - layout.preview.height * ratio) <= 2
    {
      geometry.rememberPreview(layout.previewOnScreen)
    }
    if let window = observedWindow {
      lastWindowFrame = window.frame
      if !fullScreenTransition { lastSettledWindowSize = window.frame.size }
    }
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

  func updatePointer(_ point: CGPoint) {
    guard let window = observedWindow, !isResizing, !window.inLiveResize,
      !fullScreenTransition, sidebarResizeLayout == nil
    else { return }
    if fullScreen {
      let inside =
        point.x >= 0 && point.x <= window.frame.width
        && point.y >= 0 && point.y <= window.frame.height
      let hotZone = WindowChromeVisibilityState.compactHotZoneHeight
      if inside && point.x <= hotZone {
        cancelHide()
        if !fullScreenSidebarVisible {
          fullScreenSidebarVisible = true
          transitionChrome()
        }
      } else if inside && fullScreenSidebarVisible
        && (point.x <= sidebarWidth + hotZone
          || point.y >= window.frame.height - measuredTitlebar - 32)
      {
        cancelHide()
      } else {
        scheduleHide()
      }
      return
    }
    let hotZone = WindowChromeVisibilityState.compactHotZoneHeight
    let height = chrome.showsTitlebar ? titlebarHeight + hotZone : hotZone
    if point.y >= window.frame.height - height && point.y <= window.frame.height {
      revealTitlebar()
    } else if chrome.mode == .hoverRevealed {
      scheduleHide()
    }
  }

  private func scheduleHide() {
    guard !isResizing, !fullScreenTransition else { return }
    if fullScreen {
      guard fullScreenSidebarVisible else { return }
      hoverScheduler.schedule { [weak self] in self?.hideFullScreenSidebar() }
    } else if chrome.pointerExitedRevealRegion() {
      hoverScheduler.schedule { [weak self] in self?.hideTitlebar() }
    }
  }

  private func hideFullScreenSidebar() {
    cancelHide()
    guard fullScreen, !fullScreenTransition else { return }
    fullScreenSidebarVisible = false
    transitionChrome()
  }

  private func cancelHide() {
    hoverScheduler.cancel()
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
    sidebarResizeLayout = nil
    sidebarResizeConfiguration = nil
    sidebarResizeGeometry = nil
    isResizing = false
    pendingReservationRelease = false
    preview.isGeometryChanging = false
    setupWork?.cancel()
    setupWork = nil
    events.detach()
    if let window = observedWindow {
      if window.toolbar === toolbar { window.toolbar = originalToolbar }
      window.toolbarStyle = originalToolbarStyle
      for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(type)?.isHidden = false
      }
      window.isOpaque = originalOpaque
      window.hasShadow = originalShadow
      if let originalBackground { window.backgroundColor = originalBackground }
      if !originalFullSize { window.styleMask.remove(.fullSizeContentView) }
      window.acceptsMouseMovedEvents = originalMouseMoved
    }
    observedWindow = nil
    lastSettledWindowSize = nil
    lastLayoutScreen = nil
    pendingScreenChange = false
  }
}
