import AppKit

@MainActor
final class WindowResizeDelegate: NSObject, NSWindowDelegate {
  nonisolated(unsafe) weak var originalDelegate: (any NSWindowDelegate)?
  var fullScreenFailed: ((NSWindow) -> Void)?
  var constrain: ((NSWindow, NSSize) -> NSSize)?

  override func responds(to selector: Selector!) -> Bool {
    super.responds(to: selector) || originalDelegate?.responds(to: selector) == true
  }

  override func forwardingTarget(for selector: Selector!) -> Any? {
    if originalDelegate?.responds(to: selector) == true { return originalDelegate }
    return super.forwardingTarget(for: selector)
  }

  func window(
    _ window: NSWindow,
    willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions
  ) -> NSApplication.PresentationOptions {
    var options =
      originalDelegate?.window?(
        window, willUseFullScreenPresentationOptions: proposedOptions) ?? proposedOptions
    options.remove(.hideMenuBar)
    options.formUnion([.fullScreen, .autoHideMenuBar, .autoHideToolbar])
    if !options.contains(.hideDock) { options.insert(.autoHideDock) }
    // AppKit must see the toolbar before detaching it into its auto-hide surface.
    window.toolbar?.isVisible = true
    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      window.standardWindowButton(type)?.isHidden = false
      window.standardWindowButton(type)?.alphaValue = 1
    }
    return options
  }

  func windowDidFailToEnterFullScreen(_ window: NSWindow) {
    originalDelegate?.windowDidFailToEnterFullScreen?(window)
    fullScreenFailed?(window)
  }

  func windowDidFailToExitFullScreen(_ window: NSWindow) {
    originalDelegate?.windowDidFailToExitFullScreen?(window)
    fullScreenFailed?(window)
  }

  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    let proposed = originalDelegate?.windowWillResize?(sender, to: frameSize) ?? frameSize
    return constrain?(sender, proposed) ?? proposed
  }
}

enum WindowEvent {
  case becameKey, beganResize, endedResize, resized, moved
  case willEnterFullScreen, enteredFullScreen, willExitFullScreen, exitedFullScreen
  case screenChanged, contentLayoutChanged
}

/// AppKit subscriptions and delegate forwarding have no layout state of their own.
@MainActor
final class WindowEventBridge {
  private var proxy: WindowResizeDelegate?
  private weak var window: NSWindow?
  private var observers: [NSObjectProtocol] = []
  private var contentLayoutObservation: NSKeyValueObservation?
  private var mouseMonitor: Any?
  var onEvent: ((WindowEvent) -> Void)?
  var onMouse: ((NSEvent) -> Void)?
  var constrain: ((NSWindow, NSSize) -> NSSize)?
  var fullScreenFailed: ((NSWindow) -> Void)?

  func attach(to window: NSWindow) {
    detach()
    self.window = window
    installDelegate(in: window)
    let events: [(Notification.Name, WindowEvent)] = [
      (NSWindow.didBecomeKeyNotification, .becameKey),
      (NSWindow.willStartLiveResizeNotification, .beganResize),
      (NSWindow.didEndLiveResizeNotification, .endedResize),
      (NSWindow.didResizeNotification, .resized),
      (NSWindow.didMoveNotification, .moved),
      (NSWindow.willEnterFullScreenNotification, .willEnterFullScreen),
      (NSWindow.didEnterFullScreenNotification, .enteredFullScreen),
      (NSWindow.willExitFullScreenNotification, .willExitFullScreen),
      (NSWindow.didExitFullScreenNotification, .exitedFullScreen),
      (NSWindow.didChangeScreenNotification, .screenChanged),
    ]
    for (name, event) in events {
      observers.append(
        NotificationCenter.default.addObserver(
          forName: name, object: window, queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.onEvent?(event) }
        })
    }
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.onEvent?(.screenChanged) }
      })
    contentLayoutObservation = window.observe(\.contentLayoutRect, options: [.new]) {
      [weak self] _, _ in
      MainActor.assumeIsolated { self?.onEvent?(.contentLayoutChanged) }
    }
    mouseMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]
    ) { [weak self] event in
      MainActor.assumeIsolated { self?.onMouse?(event) }
      return event
    }
  }

  func installDelegate(in window: NSWindow) {
    if window.delegate === proxy, proxy != nil { return }
    let proxy = proxy ?? WindowResizeDelegate()
    proxy.originalDelegate = window.delegate
    proxy.constrain = { [weak self] window, size in self?.constrain?(window, size) ?? size }
    proxy.fullScreenFailed = { [weak self] window in self?.fullScreenFailed?(window) }
    self.proxy = proxy
    window.delegate = proxy
  }

  func detach() {
    contentLayoutObservation?.invalidate()
    contentLayoutObservation = nil
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    mouseMonitor = nil
    if let window, window.delegate === proxy { window.delegate = proxy?.originalDelegate }
    window = nil
    proxy = nil
  }
}
