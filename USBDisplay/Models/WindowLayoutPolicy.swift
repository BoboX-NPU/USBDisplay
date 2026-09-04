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

/// Explicit child geometry. Chrome either extends the outside frame or overlays it;
/// it never participates in sizing the preview.
struct WindowSurfaceLayout: Equatable {
  let frame: CGRect
  let preview: CGRect
  let sidebar: CGRect
  let titlebar: CGRect
  let externalSidebar: Double
  let externalTitlebar: Double

  var previewOnScreen: CGRect {
    preview.offsetBy(dx: frame.minX, dy: frame.minY)
  }

  static func placing(preview: CGRect, sidebar: Double, titlebar: Double, screen: CGRect) -> Self {
    let externalSidebar = preview.width + sidebar <= screen.width ? sidebar : 0
    let externalTitlebar = preview.height + titlebar <= screen.height ? titlebar : 0
    var frame = CGRect(
      x: preview.minX - externalSidebar, y: preview.minY,
      width: preview.width + externalSidebar, height: preview.height + externalTitlebar)
    frame.origin.x = max(screen.minX, min(frame.minX, screen.maxX - frame.width))
    frame.origin.y = max(screen.minY, min(frame.minY, screen.maxY - frame.height))
    return resizing(
      frame: frame, sidebar: sidebar, titlebar: titlebar,
      externalSidebar: externalSidebar, externalTitlebar: externalTitlebar)
  }

  static func resizing(
    frame: CGRect, sidebar: Double, titlebar: Double,
    externalSidebar: Double, externalTitlebar: Double
  ) -> Self {
    Self(
      frame: frame,
      preview: CGRect(
        x: externalSidebar, y: 0,
        width: max(1, frame.width - externalSidebar),
        height: max(1, frame.height - externalTitlebar)),
      sidebar: CGRect(
        x: 0, y: 0, width: min(sidebar, frame.width), height: max(0, frame.height - titlebar)),
      titlebar: CGRect(x: 0, y: frame.height - titlebar, width: frame.width, height: titlebar),
      externalSidebar: externalSidebar, externalTitlebar: externalTitlebar)
  }
}

/// Preferred ordinary-window geometry lasts only as long as its owning window.
struct WindowGeometryState: Equatable {
  private(set) var previewRect: CGRect?
  private(set) var preferredHeight: Double?

  mutating func rememberPreview(_ rect: CGRect) {
    previewRect = rect
    preferredHeight = rect.height
  }

  mutating func move(by delta: CGSize) {
    previewRect = previewRect?.offsetBy(dx: delta.width, dy: delta.height)
  }

  mutating func orient(aspectRatio: Double, screen: CGRect) {
    guard var previewRect, let preferredHeight,
      WindowLayoutPolicy.validAspectRatio(width: aspectRatio, height: 1) != nil
    else { return }
    // Only a source orientation change may fit the preview itself to the screen.
    let height = min(preferredHeight, screen.height, screen.width / aspectRatio)
    previewRect.size = CGSize(width: height * aspectRatio, height: height)
    self.previewRect = previewRect
  }

  func layout(sidebar: Double, titlebar: Double, screen: CGRect) -> WindowSurfaceLayout? {
    guard let previewRect else { return nil }
    return .placing(preview: previewRect, sidebar: sidebar, titlebar: titlebar, screen: screen)
  }
}
