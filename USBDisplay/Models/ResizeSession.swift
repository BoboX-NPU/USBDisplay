import Foundation

/// One strategy for the entire gesture. Accepted sizes are never fed back into
/// axis selection; AppKit owns the opposite edge/corner and the window origin.
struct ResizeSession {
  enum Strategy: Equatable {
    case width, height, corner

    static func at(pointer: CGPoint, frame: CGRect, tolerance: Double = 12) -> Self? {
      guard frame.insetBy(dx: -tolerance, dy: -tolerance).contains(pointer) else { return nil }
      let vertical = min(abs(pointer.x - frame.minX), abs(pointer.x - frame.maxX)) <= tolerance
      let horizontal = min(abs(pointer.y - frame.minY), abs(pointer.y - frame.maxY)) <= tolerance
      if vertical && horizontal { return .corner }
      if vertical { return .width }
      if horizontal { return .height }
      return nil
    }
  }

  let initialFrame: CGRect
  let aspectRatio: Double
  let externalSidebar: Double
  let externalTitlebar: Double
  private(set) var strategy: Strategy?

  init(
    frame: CGRect, aspectRatio: Double, externalSidebar: Double, externalTitlebar: Double,
    strategy: Strategy? = nil
  ) {
    initialFrame = frame
    self.aspectRatio = aspectRatio
    self.externalSidebar = externalSidebar
    self.externalTitlebar = externalTitlebar
    self.strategy = strategy
  }

  mutating func constrain(_ proposed: CGSize, maximumSize: CGSize) -> CGSize {
    guard proposed.width.isFinite, proposed.height.isFinite,
      WindowLayoutPolicy.validAspectRatio(width: aspectRatio, height: 1) != nil
    else { return initialFrame.size }
    if strategy == nil {
      let widthChanged = abs(proposed.width - initialFrame.width) > 0.25
      let heightChanged = abs(proposed.height - initialFrame.height) > 0.25
      if widthChanged && heightChanged {
        strategy = .corner
      } else if widthChanged {
        strategy = .width
      } else if heightChanged {
        strategy = .height
      }
    }
    let width = proposed.width - externalSidebar
    let height = proposed.height - externalTitlebar
    let requestedHeight: Double
    switch strategy {
    case .width: requestedHeight = width / aspectRatio
    case .height: requestedHeight = height
    case .corner:
      requestedHeight = (aspectRatio * width + height) / (aspectRatio * aspectRatio + 1)
    case nil: requestedHeight = initialFrame.height - externalTitlebar
    }
    let maximumHeight = max(
      1,
      min(
        maximumSize.height - externalTitlebar,
        (maximumSize.width - externalSidebar) / aspectRatio))
    let minimumHeight = min(WindowLayoutPolicy.minimumPreviewHeight, maximumHeight)
    let acceptedHeight = min(maximumHeight, max(minimumHeight, requestedHeight))
    return CGSize(
      width: acceptedHeight * aspectRatio + externalSidebar,
      height: acceptedHeight + externalTitlebar)
  }
}

/// The first usable ratio is immediate. Later changes need two consistent
/// samples, and samples obtained during geometry changes are discarded.
struct StableAspectRatio {
  private(set) var confirmed: Double?
  private var candidate: Double?

  mutating func discardCandidate() { candidate = nil }

  mutating func observe(_ ratio: Double) -> Bool {
    guard WindowLayoutPolicy.validAspectRatio(width: ratio, height: 1) != nil else {
      candidate = nil
      return false
    }
    guard let confirmed else {
      self.confirmed = ratio
      return true
    }
    guard abs(ratio - confirmed) >= 0.001 else {
      candidate = nil
      return false
    }
    if let candidate, abs(ratio - candidate) < 0.001 {
      self.confirmed = ratio
      self.candidate = nil
      return true
    }
    candidate = ratio
    return false
  }
}

/// A stable session can carry several video sources. Each gets a fresh first sample.
struct PreviewAspectRatioTracker {
  private(set) var source: PreviewSource?
  private var filter = StableAspectRatio()

  mutating func setSource(_ source: PreviewSource?) {
    guard self.source != source else { return }
    self.source = source
    reset()
  }

  mutating func reset() { filter = StableAspectRatio() }
  mutating func discardCandidate() { filter.discardCandidate() }

  mutating func observe(source: PreviewSource, width: Double, height: Double) -> Bool {
    guard self.source == source,
      let ratio = WindowLayoutPolicy.validAspectRatio(width: width, height: height)
    else { return false }
    return filter.observe(ratio)
  }
}
