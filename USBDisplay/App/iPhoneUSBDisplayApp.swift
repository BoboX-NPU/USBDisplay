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
    .windowToolbarStyle(.unifiedCompact)
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
