@preconcurrency import AVFoundation
import AppKit
import SwiftUI

struct PreviewView: NSViewRepresentable {
  let renderer: SampleBufferRenderer
  let fullScreenToggleRequest: Int
  let shouldHideCursor: Bool
  let onActivity: @MainActor () -> Void
  let onFullScreenChanged: @MainActor (Bool) -> Void

  func makeNSView(context: Context) -> PreviewHostView {
    let view = PreviewHostView(renderer: renderer)
    update(view)
    return view
  }

  func updateNSView(_ nsView: PreviewHostView, context: Context) {
    update(nsView)
  }

  static func dismantleNSView(_ nsView: PreviewHostView, coordinator: Void) {
    nsView.prepareForRemoval()
  }

  private func update(_ view: PreviewHostView) {
    view.onActivity = onActivity
    view.onFullScreenChanged = onFullScreenChanged
    view.setRenderer(renderer)
    view.setCursorHidden(shouldHideCursor)
    view.handleFullScreenToggleRequest(fullScreenToggleRequest)
  }
}

@MainActor
final class PreviewHostView: NSView {
  private var renderer: SampleBufferRenderer
  private var trackingAreaReference: NSTrackingArea?
  private var windowObservers: [NSObjectProtocol] = []
  private var cursorHidden = false
  private var handledFullScreenToggleRequest = 0

  var onActivity: (() -> Void)?
  var onFullScreenChanged: ((Bool) -> Void)?

  init(renderer: SampleBufferRenderer) {
    self.renderer = renderer
    super.init(frame: .zero)
    wantsLayer = true
    layer = CALayer()
    layer?.backgroundColor = NSColor.black.cgColor

    renderer.displayLayer.videoGravity = .resizeAspect
    renderer.displayLayer.backgroundColor = NSColor.black.cgColor
    renderer.displayLayer.actions = [
      "bounds": NSNull(),
      "position": NSNull(),
      "frame": NSNull(),
      "contents": NSNull(),
    ]
    layer?.addSublayer(renderer.displayLayer)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    renderer.displayLayer.frame = bounds
    CATransaction.commit()
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let trackingAreaReference {
      removeTrackingArea(trackingAreaReference)
    }

    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    trackingAreaReference = trackingArea
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    removeWindowObservers()

    guard let window else {
      setCursorHidden(false)
      return
    }

    window.acceptsMouseMovedEvents = true
    let center = NotificationCenter.default
    windowObservers = [
      center.addObserver(
        forName: NSWindow.didEnterFullScreenNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.onFullScreenChanged?(true)
        }
      },
      center.addObserver(
        forName: NSWindow.didExitFullScreenNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.setCursorHidden(false)
          self?.onFullScreenChanged?(false)
        }
      },
      center.addObserver(
        forName: NSWindow.didResignKeyNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.setCursorHidden(false)
        }
      },
      center.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.onActivity?()
        }
      },
    ]
  }

  override func mouseMoved(with event: NSEvent) {
    onActivity?()
  }

  override func mouseEntered(with event: NSEvent) {
    onActivity?()
  }

  override func mouseDown(with event: NSEvent) {
    onActivity?()
    if event.clickCount == 2 {
      window?.toggleFullScreen(nil)
    } else {
      super.mouseDown(with: event)
    }
  }

  func setRenderer(_ renderer: SampleBufferRenderer) {
    guard self.renderer !== renderer else { return }
    self.renderer.displayLayer.removeFromSuperlayer()
    self.renderer = renderer
    layer?.addSublayer(renderer.displayLayer)
    needsLayout = true
  }

  func handleFullScreenToggleRequest(_ request: Int) {
    guard request != handledFullScreenToggleRequest else { return }
    handledFullScreenToggleRequest = request
    window?.toggleFullScreen(nil)
  }

  func setCursorHidden(_ hidden: Bool) {
    guard hidden != cursorHidden else { return }

    if hidden {
      NSCursor.hide()
    } else {
      NSCursor.unhide()
    }
    cursorHidden = hidden
  }

  func prepareForRemoval() {
    setCursorHidden(false)
    removeWindowObservers()
    renderer.displayLayer.removeFromSuperlayer()
  }

  private func removeWindowObservers() {
    windowObservers.forEach(NotificationCenter.default.removeObserver)
    windowObservers.removeAll()
  }

  deinit {
    if cursorHidden {
      NSCursor.unhide()
    }
    windowObservers.forEach(NotificationCenter.default.removeObserver)
  }
}
