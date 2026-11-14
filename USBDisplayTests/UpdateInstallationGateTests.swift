import Testing

@testable import iPhoneUSBDisplay

@MainActor
struct UpdateInstallationGateTests {
  @Test func quittingWhileDownloadingCancelsBeforeTermination() {
    let gate = UpdateInstallationGate()
    var events: [String] = []
    gate.begin()
    gate.setCancellation { events.append("cancel") }
    #expect(gate.deferTermination { events.append("quit") })
    #expect(events == ["cancel"])
    gate.finish()
    #expect(events == ["cancel", "quit"])
  }

  @Test func quittingDuringExtractionWaitsForSafeCancellation() {
    let gate = UpdateInstallationGate()
    var events: [String] = []
    gate.begin()
    gate.setCancellation(nil)
    #expect(gate.deferTermination { events.append("quit") })
    #expect(events.isEmpty)
    gate.setCancellation { events.append("cancel prepared update") }
    #expect(events == ["cancel prepared update"])
    gate.finish()
    #expect(events == ["cancel prepared update", "quit"])
  }

  @Test func readyUpdateCannotInstallByOrdinaryQuit() {
    let gate = UpdateInstallationGate()
    var cancelled = 0
    gate.begin()
    gate.setCancellation { cancelled += 1 }
    #expect(gate.deferTermination {})
    #expect(gate.deferTermination {})
    #expect(cancelled == 1)
  }

  @Test func explicitInstallAllowsSparkleToQuitAndRelaunch() {
    let gate = UpdateInstallationGate()
    gate.begin()
    gate.setCancellation { Issue.record("An accepted install must not be cancelled") }
    gate.authorizeInstallation()
    #expect(!gate.deferTermination {})
  }

  @Test func failedOrCancelledCycleDoesNotBlockFutureQuit() {
    let gate = UpdateInstallationGate()
    gate.begin()
    gate.finish()
    #expect(!gate.deferTermination {})
    gate.begin()
    #expect(gate.deferTermination {})
  }

  @Test func idleQuitDoesNotWaitForUpdater() {
    let gate = UpdateInstallationGate()
    #expect(!gate.deferTermination {})
  }
}
