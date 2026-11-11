import AppKit

/// AppKit owns divider drawing, hit testing, cursor feedback and drag tracking.
/// The trailing pane is transparent: the persistent video stays in its host.
@MainActor
final class SidebarSplitView: NSSplitView, NSSplitViewDelegate {
  var onBeginResize: (() -> Void)?
  var onWidthChanged: ((Double) -> Void)?
  var onEndResize: (() -> Void)?
  private var applyingGeometry = false
  private var isTrackingDivider = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    isVertical = true
    dividerStyle = .thin
    delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func drawDivider(in rect: NSRect) {
    // Native thin dividers can be translucent or clear. Our window has no
    // opaque backing, so give only the divider a base before AppKit draws it.
    NSColor.windowBackgroundColor.setFill()
    rect.fill()
    super.drawDivider(in: rect)
  }

  func beginResize() {
    guard !isTrackingDivider else { return }
    isTrackingDivider = true
    onBeginResize?()
  }

  func endResize() {
    guard isTrackingDivider else { return }
    isTrackingDivider = false
    onEndResize?()
  }

  func containsDivider(at point: CGPoint) -> Bool {
    guard !isHidden, alphaValue > 0, let leading = subviews.first else { return false }
    return bounds.contains(point) && abs(point.x - leading.frame.maxX) <= 5
  }

  override func setPosition(_ position: CGFloat, ofDividerAt dividerIndex: Int) {
    let standalone = !isTrackingDivider && !applyingGeometry
    if standalone { beginResize() }
    super.setPosition(position, ofDividerAt: dividerIndex)
    if standalone { endResize() }
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let hit = super.hitTest(point)
    // NSSplitView otherwise claims the empty trailing pane after its hit test.
    let local = convert(point, from: superview)
    if hit === self, let leading = subviews.first, local.x > leading.frame.maxX + 5 { return nil }
    return hit
  }

  func applyGeometry(frame: CGRect, sidebarWidth: Double) {
    guard subviews.count == 2 else { return }
    applyingGeometry = true
    defer { applyingGeometry = false }
    self.frame = frame
    subviews[0].frame = CGRect(x: 0, y: 0, width: sidebarWidth, height: bounds.height)
    let trailingX = min(bounds.width, sidebarWidth + dividerThickness)
    subviews[1].frame = CGRect(
      x: trailingX, y: 0, width: max(0, bounds.width - trailingX), height: bounds.height)
    needsDisplay = true
    window?.invalidateCursorRects(for: self)
  }

  func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
    guard subviews.count == 2 else { return }
    let width = min(subviews[0].frame.width, max(0, bounds.width - dividerThickness))
    subviews[0].frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
    let trailingX = min(bounds.width, width + dividerThickness)
    subviews[1].frame = CGRect(
      x: trailingX, y: 0,
      width: max(0, bounds.width - trailingX), height: bounds.height)
  }

  func splitViewDidResizeSubviews(_ notification: Notification) {
    guard !applyingGeometry, isTrackingDivider, let leading = subviews.first else { return }
    onWidthChanged?(leading.frame.width)
  }

  func splitView(
    _ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat,
    ofSubviewAt dividerIndex: Int
  ) -> CGFloat {
    min(WindowLayoutPolicy.minimumSidebarWidth, max(0, bounds.width - 160))
  }

  func splitView(
    _ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat,
    ofSubviewAt dividerIndex: Int
  ) -> CGFloat {
    min(WindowLayoutPolicy.maximumSidebarWidth, max(0, bounds.width - 160 - dividerThickness))
  }
}

@MainActor
final class SplitPassthroughView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
