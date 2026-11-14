import Foundation

/// Keeps an ordinary quit from installing an update the user has not accepted.
@MainActor
final class UpdateInstallationGate {
  private var active = false
  private var authorized = false
  private var cancellation: (() -> Void)?
  private var termination: (() -> Void)?

  var isQuitting: Bool { termination != nil }

  func begin() {
    active = true
    authorized = false
  }

  func setCancellation(_ cancellation: (() -> Void)?) {
    self.cancellation = cancellation
    cancelIfQuitting()
  }

  func authorizeInstallation() {
    authorized = true
    cancellation = nil
  }

  /// During extraction, wait for Sparkle's ready callback before cancelling.
  func deferTermination(untilCancelled completion: @escaping () -> Void) -> Bool {
    guard active, !authorized else { return false }
    if termination == nil { termination = completion }
    cancelIfQuitting()
    return true
  }

  func finish() {
    active = false
    authorized = false
    cancellation = nil
    let completion = termination
    termination = nil
    completion?()
  }

  private func cancelIfQuitting() {
    guard isQuitting, let cancel = cancellation else { return }
    cancellation = nil
    cancel()
  }
}
