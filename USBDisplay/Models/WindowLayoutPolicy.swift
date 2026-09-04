import Foundation

struct WindowContentSize: Equatable, Sendable {
  let width: Double
  let height: Double
}

enum WindowChromeMode: Equatable, Sendable {
  case sidebarVisible
  case compact
  case hoverRevealed
}

struct WindowChromeVisibilityState: Equatable, Sendable {
  static let hideDelay = 0.5
  static let animationDuration = 0.15
  static let compactHotZoneHeight = 8.0

  private(set) var sidebarIsVisible: Bool
  private(set) var mode: WindowChromeMode
  private(set) var hideIsPending = false

  var showsTitlebar: Bool {
    mode != .compact
  }

  init(sidebarIsVisible: Bool) {
    self.sidebarIsVisible = sidebarIsVisible
    mode = sidebarIsVisible ? .sidebarVisible : .compact
  }

  mutating func updateSidebarVisibility(_ isVisible: Bool) {
    sidebarIsVisible = isVisible
    hideIsPending = false
    mode = isVisible ? .sidebarVisible : .compact
  }

  mutating func pointerEnteredTopRegion() {
    guard !sidebarIsVisible else { return }
    hideIsPending = false
    mode = .hoverRevealed
  }

  @discardableResult
  mutating func pointerExitedRevealRegion() -> Bool {
    guard !sidebarIsVisible, mode == .hoverRevealed else {
      hideIsPending = false
      return false
    }

    hideIsPending = true
    return true
  }

  mutating func hideDelayElapsed() {
    hideIsPending = false
    if !sidebarIsVisible {
      mode = .compact
    }
  }
}

enum WindowLayoutPolicy {
  static let minimumPreviewHeight = 320.0
  static let splitDividerWidth = 1.0
  static let sidebarResizeDebounce = 0.1
  static let nonInteractiveResizeDebounce = 0.04

  static func validAspectRatio(width: Double, height: Double) -> Double? {
    guard width.isFinite, height.isFinite, width > 0, height > 0 else {
      return nil
    }

    let ratio = width / height
    return ratio.isFinite && ratio > 0 ? ratio : nil
  }

  static func sidebarContribution(width: Double, isVisible: Bool) -> Double {
    guard isVisible else { return 0 }
    return max(width, 0) + splitDividerWidth
  }

  static func contentSize(
    previewHeight: Double,
    aspectRatio: Double,
    sidebarWidth: Double,
    sidebarIsVisible: Bool
  ) -> WindowContentSize? {
    guard
      validAspectRatio(width: aspectRatio, height: 1) != nil,
      previewHeight.isFinite,
      previewHeight > 0
    else {
      return nil
    }

    let sidebar = sidebarContribution(width: sidebarWidth, isVisible: sidebarIsVisible)
    return WindowContentSize(
      width: sidebar + previewHeight * aspectRatio,
      height: previewHeight
    )
  }

  static func sizePreservingHeight(
    currentHeight: Double,
    aspectRatio: Double,
    sidebarWidth: Double,
    sidebarIsVisible: Bool,
    maximumSize: WindowContentSize
  ) -> WindowContentSize? {
    guard
      maximumSize.width > 0,
      maximumSize.height > 0,
      let unconstrained = contentSize(
        previewHeight: max(currentHeight, minimumPreviewHeight),
        aspectRatio: aspectRatio,
        sidebarWidth: sidebarWidth,
        sidebarIsVisible: sidebarIsVisible
      )
    else {
      return nil
    }

    let sidebar = sidebarContribution(width: sidebarWidth, isVisible: sidebarIsVisible)
    let widthScale = (maximumSize.width - sidebar) / max(unconstrained.width - sidebar, 1)
    let heightScale = maximumSize.height / unconstrained.height
    let scale = min(1, widthScale, heightScale)
    let fittedHeight = max(unconstrained.height * max(scale, 0), 1)

    return contentSize(
      previewHeight: fittedHeight,
      aspectRatio: aspectRatio,
      sidebarWidth: sidebarWidth,
      sidebarIsVisible: sidebarIsVisible
    )
  }

  static func constrainedResize(
    proposedSize: WindowContentSize,
    previousSize: WindowContentSize,
    aspectRatio: Double,
    sidebarWidth: Double,
    sidebarIsVisible: Bool,
    maximumSize: WindowContentSize
  ) -> WindowContentSize? {
    let sidebar = sidebarContribution(width: sidebarWidth, isVisible: sidebarIsVisible)
    let widthDelta = abs(proposedSize.width - previousSize.width)
    let heightDelta = abs(proposedSize.height - previousSize.height) * aspectRatio
    let previewHeight: Double

    if widthDelta > heightDelta {
      previewHeight = max(
        (proposedSize.width - sidebar) / aspectRatio,
        minimumPreviewHeight
      )
    } else {
      previewHeight = max(proposedSize.height, minimumPreviewHeight)
    }

    return sizePreservingHeight(
      currentHeight: previewHeight,
      aspectRatio: aspectRatio,
      sidebarWidth: sidebarWidth,
      sidebarIsVisible: sidebarIsVisible,
      maximumSize: maximumSize
    )
  }

  static func shouldConstrainWindow(isFullScreen: Bool, aspectRatio: Double?) -> Bool {
    guard !isFullScreen, let aspectRatio else { return false }
    return validAspectRatio(width: aspectRatio, height: 1) != nil
  }

}

/// The user's intended preview rectangle, independent of temporary window chrome.
struct WindowGeometryState: Equatable {
  private(set) var previewRect: CGRect?

  mutating func rememberUserGeometry(frame: CGRect, sidebar: Double, titlebar: Double) {
    previewRect = CGRect(
      x: frame.minX + sidebar, y: frame.minY,
      width: max(frame.width - sidebar, 1), height: max(frame.height - titlebar, 1)
    )
  }

  mutating func move(by delta: CGSize) {
    previewRect = previewRect?.offsetBy(dx: delta.width, dy: delta.height)
  }

  func frame(aspectRatio: Double, sidebar: Double, titlebar: Double, visibleFrame: CGRect)
    -> CGRect?
  {
    guard let previewRect,
      let size = WindowLayoutPolicy.sizePreservingHeight(
        currentHeight: previewRect.height, aspectRatio: aspectRatio,
        sidebarWidth: max(sidebar - WindowLayoutPolicy.splitDividerWidth, 0),
        sidebarIsVisible: sidebar > 0,
        maximumSize: WindowContentSize(
          width: visibleFrame.width, height: max(visibleFrame.height - titlebar, 1)
        )
      )
    else { return nil }
    var result = CGRect(
      x: previewRect.minX - sidebar, y: previewRect.minY,
      width: size.width, height: size.height + titlebar
    )
    result.origin.x = min(max(result.minX, visibleFrame.minX), visibleFrame.maxX - result.width)
    result.origin.y = min(max(result.minY, visibleFrame.minY), visibleFrame.maxY - result.height)
    return result
  }
}

/// Only one frame transition can own a window; cancellation discards all future ticks.
struct WindowFrameTransition {
  let start: CGRect
  let target: CGRect
  let startTime: TimeInterval
  let duration: TimeInterval

  func frame(at time: TimeInterval) -> CGRect {
    let progress = min(max((time - startTime) / duration, 0), 1)
    let eased = progress * progress * (3 - 2 * progress)
    return CGRect(
      x: start.minX + (target.minX - start.minX) * eased,
      y: start.minY + (target.minY - start.minY) * eased,
      width: start.width + (target.width - start.width) * eased,
      height: start.height + (target.height - start.height) * eased
    )
  }
}
