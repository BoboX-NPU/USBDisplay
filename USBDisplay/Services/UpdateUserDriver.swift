import Sparkle

/// Uses Sparkle's standard windows while separating download from installation.
@MainActor
final class UpdateUserDriver: SPUStandardUserDriver {
  let installationGate = UpdateInstallationGate()

  override func showUpdateFound(
    with appcastItem: SUAppcastItem,
    state: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void
  ) {
    AppLogger.interface.info("Update found at stage \(state.stage.rawValue)")
    // Never automatically accept an informational, major, or already-installing update.
    guard !appcastItem.isInformationOnlyUpdate, !appcastItem.isMajorUpgrade,
      state.stage == .notDownloaded || state.stage == .downloaded
    else {
      // A recovered installer must also require consent, even after an interrupted run.
      if state.stage == .installing {
        installationGate.begin()
        installationGate.setCancellation { reply(.skip) }
      }
      super.showUpdateFound(with: appcastItem, state: state) { [weak self] choice in
        if choice == .install {
          self?.installationGate.begin()
          if state.stage == .installing { self?.installationGate.authorizeInstallation() }
        }
        reply(state.stage == .installing && choice != .install ? .skip : choice)
      }
      return
    }

    // Close the checking window before the standard download progress window opens.
    super.dismissUpdateInstallation()
    installationGate.begin()
    // In these two stages, .install only downloads/extracts; ready is a separate callback.
    reply(.install)
  }

  override func showDownloadInitiated(cancellation: @escaping () -> Void) {
    installationGate.setCancellation(cancellation)
    if !installationGate.isQuitting {
      super.showDownloadInitiated(cancellation: cancellation)
    }
  }

  override func showDownloadDidStartExtractingUpdate() {
    installationGate.setCancellation(nil)
    super.showDownloadDidStartExtractingUpdate()
  }

  override func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
    AppLogger.interface.info("Update prepared; waiting for installation consent")
    // .skip here cancels the prepared installation without skipping this version forever.
    // .dismiss would still let Sparkle install on quit, so it must not be used for quitting.
    installationGate.setCancellation { reply(.skip) }
    guard !installationGate.isQuitting else { return }
    super.showReady { [weak self] choice in
      AppLogger.interface.info("Ready update choice: \(choice.rawValue)")
      if choice == .install { self?.installationGate.authorizeInstallation() }
      reply(choice)
    }
  }
}
