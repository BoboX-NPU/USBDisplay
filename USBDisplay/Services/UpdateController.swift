import AppKit
import Combine
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
  @Published private(set) var canCheckForUpdates = false
  @Published private(set) var automaticallyChecksForUpdates = true
  private let userDriver: UpdateUserDriver
  private var updater: SPUUpdater!
  private var startupError: Error?

  override init() {
    userDriver = UpdateUserDriver(hostBundle: .main, delegate: nil)
    super.init()
    updater = SPUUpdater(
      hostBundle: .main, applicationBundle: .main, userDriver: userDriver, delegate: self)
    updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    updater.publisher(for: \.automaticallyChecksForUpdates)
      .assign(to: &$automaticallyChecksForUpdates)
  }

  func start() {
    // Test hosts must never contact the public feed or display updater windows.
    guard NSClassFromString("XCTestCase") == nil else { return }
    do {
      try updater.start()
    } catch {
      startupError = error
      canCheckForUpdates = true
      AppLogger.interface.error(
        "Updater startup failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func checkForUpdates() {
    if let startupError {
      NSAlert(error: startupError).runModal()
    } else {
      updater.checkForUpdates()
    }
  }

  func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
    updater.automaticallyChecksForUpdates = enabled
  }

  func applicationShouldTerminate() -> NSApplication.TerminateReply {
    let deferred = userDriver.installationGate.deferTermination {
      // Sparkle finishes asynchronously; reply after AppKit received .terminateLater.
      DispatchQueue.main.async { NSApp.reply(toApplicationShouldTerminate: true) }
    }
    AppLogger.interface.info("Update termination deferred: \(deferred)")
    return deferred ? .terminateLater : .terminateNow
  }

  func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: Error?
  ) {
    AppLogger.interface.info(
      "Update cycle finished; error: \(error?.localizedDescription ?? "none", privacy: .public)")
    userDriver.installationGate.finish()
  }
}
