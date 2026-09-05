import AppKit

/// A cancelled hover callback cannot act on a later reveal or window mode.
@MainActor
final class WindowHoverScheduler {
  typealias Action = @MainActor @Sendable () -> Void
  private let after: (TimeInterval, @escaping Action) -> Void
  private var generation = 0
  private var pending = false

  init(
    after: @escaping (TimeInterval, @escaping Action) -> Void = { delay, action in
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
  ) {
    self.after = after
  }

  func schedule(_ action: @escaping Action) {
    guard !pending else { return }
    pending = true
    let generation = generation
    after(WindowChromeVisibilityState.hideDelay) { [weak self] in
      guard let self, self.pending, self.generation == generation else { return }
      self.pending = false
      action()
    }
  }

  func cancel() {
    generation += 1
    pending = false
  }
}
