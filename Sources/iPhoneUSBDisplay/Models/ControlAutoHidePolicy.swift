import Foundation

struct AppClock: Sendable {
  let now: @Sendable () -> Date

  static let live = AppClock(now: Date.init)
}

struct ControlAutoHidePolicy: Equatable, Sendable {
  let inactivityInterval: TimeInterval

  init(inactivityInterval: TimeInterval = 3) {
    self.inactivityInterval = inactivityInterval
  }

  func shouldHideControls(
    lastActivity: Date,
    now: Date,
    isConnected: Bool
  ) -> Bool {
    isConnected && now.timeIntervalSince(lastActivity) >= inactivityInterval
  }

  func shouldHideCursor(
    controlsHidden: Bool,
    isConnected: Bool,
    isFullScreen: Bool
  ) -> Bool {
    controlsHidden && isConnected && isFullScreen
  }
}
