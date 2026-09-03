import AppKit
import SwiftUI

struct ContentView: View {
  @Bindable var model: AppModel
  let devices: [DisplayDevice]
  let onSelectDevice: (String) -> Void

  var body: some View {
    NavigationSplitView(columnVisibility: columnVisibility) {
      SidebarView(
        devices: devices,
        selectedDeviceID: model.selectedDeviceID,
        onSelectDevice: onSelectDevice
      )
    } detail: {
      DisplayCanvasView(
        model: model,
        hasAvailableDevices: !devices.isEmpty
      )
    }
    .navigationSplitViewStyle(.balanced)
    .background(WindowTitleConfiguration(title: logicalWindowTitle))
  }

  private var logicalWindowTitle: String {
    devices.first { $0.id == model.selectedDeviceID }?.name ?? "USB Display"
  }

  private var columnVisibility: Binding<NavigationSplitViewVisibility> {
    Binding(
      get: { model.columnVisibility },
      set: { visibility in
        model.setColumnVisibility(visibility)
      }
    )
  }
}

private struct WindowTitleConfiguration: NSViewRepresentable {
  let title: String

  func makeNSView(context: Context) -> WindowTitleConfigurationView {
    let view = WindowTitleConfigurationView()
    view.title = title
    return view
  }

  func updateNSView(_ nsView: WindowTitleConfigurationView, context: Context) {
    nsView.title = title
    nsView.applyConfiguration()
  }
}

@MainActor
private final class WindowTitleConfigurationView: NSView {
  var title = "USB Display"

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    applyConfiguration()
    DispatchQueue.main.async { [weak self] in
      self?.applyConfiguration()
    }
  }

  func applyConfiguration() {
    window?.title = title
    window?.titleVisibility = .hidden
  }
}
