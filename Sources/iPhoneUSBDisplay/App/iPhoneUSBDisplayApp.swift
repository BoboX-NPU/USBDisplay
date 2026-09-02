import AppKit
import SwiftUI

@main
struct IPhoneUSBDisplayApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var model = AppModel()

  var body: some Scene {
    Window("USB Display", id: "main") {
      ContentView(model: model)
        .frame(minWidth: 700, minHeight: 520)
    }
    .defaultSize(width: 980, height: 720)
    .windowResizability(.contentMinSize)
    .windowToolbarStyle(.unified)
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
