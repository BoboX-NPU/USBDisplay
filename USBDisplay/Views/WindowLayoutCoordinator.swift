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
  private var observers: [NSObjectProtocol] = []
  private var lastFrame: CGRect?
  private var lastContentSize: CGSize?
  private var isApplyingFrame = false

  fileprivate init(configuration: WindowLayoutConfiguration) {
    self.configuration = configuration
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
    applyChrome(to: window)
    rememberCurrentGeometry(of: window)
    scheduleProportionalLayout(animated: false)
  }

  fileprivate func updateConfiguration(_ newConfiguration: WindowLayoutConfiguration) {
    let layoutChanged =
      configuration.aspectRatio != newConfiguration.aspectRatio
      || abs(configuration.sidebarWidth - newConfiguration.sidebarWidth) >= 0.5
      || configuration.sidebarIsVisible != newConfiguration.sidebarIsVisible

    configuration = newConfiguration
    guard let window = observedWindow else { return }
    applyChrome(to: window)

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
        forName: NSWindow.didExitFullScreenNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.scheduleProportionalLayout(animated: false)
        }
      },
      center.addObserver(
        forName: NSWindow.didChangeScreenNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.scheduleProportionalLayout(animated: false)
        }
      },
    ]
  }

  private func detachFromWindow() {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    observedWindow = nil
    lastFrame = nil
    lastContentSize = nil
  }

  private func applyChrome(to window: NSWindow) {
    window.title = configuration.title
    window.titleVisibility = .hidden
    window.styleMask.insert(.fullSizeContentView)
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.toolbar?.showsBaselineSeparator = false
  }

  private func scheduleProportionalLayout(animated: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.applyProportionalLayoutPreservingHeight(animated: animated)
    }
  }

  private func applyProportionalLayoutPreservingHeight(animated: Bool) {
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
    guard
      let aspectRatio = configuration.aspectRatio,
      WindowLayoutPolicy.shouldConstrainWindow(
        isFullScreen: window.styleMask.contains(.fullScreen),
        aspectRatio: aspectRatio
      ),
      let proposedSize = currentContentSize(of: window)
    else {
      rememberCurrentGeometry(of: window)
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
      return
    }

    apply(
      desiredContentSize: desiredSize,
      to: window,
      anchoringAgainst: lastFrame,
      animated: false
    )
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
    return WindowContentSize(
      width: max(screenFrame.width - horizontalDecoration, 1),
      height: max(screenFrame.height - verticalDecoration, 1)
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
