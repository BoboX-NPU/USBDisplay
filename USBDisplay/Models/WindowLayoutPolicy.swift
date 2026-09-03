import Foundation

struct WindowContentSize: Equatable, Sendable {
  let width: Double
  let height: Double
}

enum WindowLayoutPolicy {
  static let minimumPreviewHeight = 320.0
  static let splitDividerWidth = 1.0

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
