import SwiftUI

struct ContentView: View {
  @Bindable var model: AppModel
  let devices: [DisplayDevice]
  let onSelectDevice: (String) -> Void
  let onOpenDeviceInNewWindow: (String) -> Void

  var body: some View {
    NavigationSplitView(columnVisibility: columnVisibility) {
      SidebarView(
        devices: devices,
        selectedDeviceID: model.selectedDeviceID,
        onSelectDevice: onSelectDevice,
        onOpenDeviceInNewWindow: onOpenDeviceInNewWindow,
        onWidthChanged: model.updateSidebarWidth
      )
    } detail: {
      DisplayCanvasView(
        model: model,
        hasAvailableDevices: !devices.isEmpty
      )
    }
    .navigationSplitViewStyle(.balanced)
    .ignoresSafeArea(
      .container,
      edges: model.columnVisibility == .detailOnly ? .top : []
    )
    .background(
      WindowLayoutCoordinator(
        title: logicalWindowTitle,
        aspectRatio: model.previewAspectRatio,
        sidebarWidth: model.sidebarWidth,
        sidebarIsVisible: model.columnVisibility != .detailOnly
      )
    )
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
