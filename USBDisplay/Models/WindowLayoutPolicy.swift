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
  static let resizeSnapAnimationDuration = 0.12

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

  static func frameByApplyingContentSize(
    currentFrame: CGRect,
    currentContentSize: WindowContentSize,
    desiredContentSize: WindowContentSize,
    anchoringAgainst previousFrame: CGRect?
  ) -> CGRect {
    let widthDifference = desiredContentSize.width - currentContentSize.width
    let heightDifference = desiredContentSize.height - currentContentSize.height
    var frame = currentFrame
    frame.size.width += widthDifference
    frame.size.height += heightDifference

    if let previousFrame {
      let leftMovement = abs(currentFrame.minX - previousFrame.minX)
      let rightMovement = abs(currentFrame.maxX - previousFrame.maxX)
      if abs(leftMovement - rightMovement) < 0.5 {
        frame.origin.x -= widthDifference / 2
      } else if leftMovement > rightMovement {
        frame.origin.x = currentFrame.maxX - frame.width
      }

      let bottomMovement = abs(currentFrame.minY - previousFrame.minY)
      let topMovement = abs(currentFrame.maxY - previousFrame.maxY)
      if abs(bottomMovement - topMovement) < 0.5 {
        frame.origin.y -= heightDifference / 2
      } else if bottomMovement > topMovement {
        frame.origin.y = currentFrame.maxY - frame.height
      }
    } else {
      frame.origin.x -= widthDifference / 2
      frame.origin.y -= heightDifference / 2
    }

    return frame
  }

  static func frameByRevealingTitlebar(
    compactFrame: CGRect,
    titlebarHeight: Double,
    visibleFrame: CGRect?
  ) -> CGRect? {
    guard
      titlebarHeight.isFinite,
      titlebarHeight > 0,
      compactFrame.width.isFinite,
      compactFrame.height.isFinite,
      compactFrame.width > 0,
      compactFrame.height > 0
    else {
      return nil
    }

    var revealedFrame = compactFrame
    revealedFrame.size.height += titlebarHeight

    guard let visibleFrame else { return revealedFrame }
    if revealedFrame.maxY > visibleFrame.maxY {
      revealedFrame.origin.y -= revealedFrame.maxY - visibleFrame.maxY
    }
    if revealedFrame.minY < visibleFrame.minY {
      revealedFrame.origin.y = visibleFrame.minY
    }
    return revealedFrame
  }
}
