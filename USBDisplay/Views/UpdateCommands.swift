import SwiftUI

struct UpdateCommands: Commands {
  @ObservedObject var controller: UpdateController

  var body: some Commands {
    CommandGroup(after: .appInfo) {
      Button("Check for Updates…", action: controller.checkForUpdates)
        .disabled(!controller.canCheckForUpdates)
      Toggle(
        "Automatically Check for Updates",
        isOn: Binding(
          get: { controller.automaticallyChecksForUpdates },
          set: { controller.setAutomaticallyChecksForUpdates($0) }
        )
      )
    }
  }
}
