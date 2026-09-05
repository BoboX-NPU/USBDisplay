import AppKit

struct ChromePresentation: Equatable {
  var sidebar: Double
  var titlebar: Double

  init(sidebar: Double, titlebar: Double) {
    self.sidebar = sidebar
    self.titlebar = titlebar
  }

  init(sidebar: Bool, titlebar: Bool) {
    self.init(sidebar: sidebar ? 1 : 0, titlebar: titlebar ? 1 : 0)
  }

  var compact: Double { 1 - max(sidebar, titlebar) }

  func interpolated(to target: Self, progress: Double) -> Self {
    Self(
      sidebar: sidebar + (target.sidebar - sidebar) * progress,
      titlebar: titlebar + (target.titlebar - titlebar) * progress)
  }
}

/// A display-linked timeline changes controls and mask geometry only. Window
/// frames are committed by the host at the two reservation boundaries.
@MainActor
final class WindowChromeAnimator: NSObject {
  static let duration = 0.2
  private(set) var presentation: ChromePresentation
  private(set) var target: ChromePresentation
  private(set) var startedAt: TimeInterval?
  private var source: ChromePresentation
  private let clock: () -> TimeInterval
  private var link: CADisplayLink?
  var onUpdate: ((ChromePresentation) -> Void)?
  var onCompletion: (() -> Void)?
  var isRunning: Bool { startedAt != nil }

  init(_ presentation: ChromePresentation, clock: @escaping () -> TimeInterval = CACurrentMediaTime)
  {
    self.presentation = presentation
    target = presentation
    source = presentation
    self.clock = clock
  }

  func value(at time: TimeInterval) -> ChromePresentation {
    guard let startedAt else { return presentation }
    let elapsed = min(1, max(0, (time - startedAt) / Self.duration))
    let eased = elapsed * elapsed * (3 - 2 * elapsed)
    return source.interpolated(to: target, progress: eased)
  }

  func retarget(_ target: ChromePresentation, in window: NSWindow, animated: Bool) {
    guard self.target != target else { return }
    let now = clock()
    presentation = value(at: now)
    stopLink()
    source = presentation
    self.target = target
    startedAt = animated ? now : nil
    if animated {
      let relay = DisplayLinkRelay { [weak self] in
        guard let self else { return }
        self.advance(to: self.clock())
      }
      let link = window.displayLink(target: relay, selector: #selector(DisplayLinkRelay.tick))
      self.link = link
      link.add(to: .main, forMode: .common)
    } else {
      presentation = target
    }
    onUpdate?(presentation)
    if !animated { onCompletion?() }
  }

  func advance(to time: TimeInterval) {
    guard let startedAt else { return }
    presentation = value(at: time)
    let complete = time >= startedAt + Self.duration
    if complete {
      presentation = target
      self.startedAt = nil
      stopLink()
    }
    onUpdate?(presentation)
    if complete { onCompletion?() }
  }

  func reset(to presentation: ChromePresentation) {
    stopLink()
    startedAt = nil
    self.presentation = presentation
    target = presentation
    source = presentation
  }

  private func stopLink() {
    link?.invalidate()
    link = nil
  }
}

@MainActor
private final class DisplayLinkRelay: NSObject {
  private let update: () -> Void
  init(update: @escaping () -> Void) { self.update = update }
  @objc func tick() { update() }
}
