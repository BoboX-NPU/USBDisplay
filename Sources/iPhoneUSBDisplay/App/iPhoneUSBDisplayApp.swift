import AppKit
import SwiftUI

@main
struct IPhoneUSBDisplayApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var model = AppModel()

  var body: some Scene {
    Window("iPhone USB Display", id: "main") {
      ContentView(model: model)
        .frame(minWidth: 360, minHeight: 480)
    }
    .defaultSize(width: 520, height: 820)
    .windowResizability(.contentMinSize)
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
