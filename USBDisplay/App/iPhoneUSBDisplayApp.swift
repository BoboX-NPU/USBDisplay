import AppKit
import SwiftUI

@main
struct IPhoneUSBDisplayApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var catalog = DeviceCatalog()
  @State private var windowRegistry = DeviceWindowRegistry()

  var body: some Scene {
    WindowGroup("USB Display", id: "display", for: String.self) { $deviceID in
      DisplayWindowScene(
        deviceID: $deviceID,
        catalog: catalog,
        windowRegistry: windowRegistry
      )
    }
    .defaultSize(width: 980, height: 720)
    .windowResizability(.automatic)
    .windowToolbarStyle(.unified)
    .commands { UpdateCommands(controller: appDelegate.updateController) }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let updateController = UpdateController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    updateController.start()
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    updateController.applicationShouldTerminate()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
