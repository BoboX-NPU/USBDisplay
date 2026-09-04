import SwiftUI

struct ContentView: View {
  @Bindable var model: AppModel
  let devices: [DisplayDevice]
  @Bindable var cornerPreferences: CornerRadiusPreferences
  let onSelectDevice: (String) -> Void
  let onOpenDeviceInNewWindow: (String) -> Void

  @State private var cornerAdjustmentDevice: DisplayDevice?

  var body: some View {
    NavigationSplitView(columnVisibility: columnVisibility) {
      SidebarView(
        devices: devices,
        selectedDeviceID: model.selectedDeviceID,
        onSelectDevice: onSelectDevice,
        onOpenDeviceInNewWindow: onOpenDeviceInNewWindow,
        onAdjustScreenCorners: { device in
          cornerAdjustmentDevice = device
        },
        onWidthChanged: model.updateSidebarWidth
      )
      .toolbar(removing: .sidebarToggle)
    } detail: {
      DisplayCanvasView(
        model: model,
        hasAvailableDevices: !devices.isEmpty
      )
      .toolbar(removing: .sidebarToggle)
    }
    .navigationSplitViewStyle(.balanced)
    .toolbar(removing: .sidebarToggle)
    .ignoresSafeArea(
      .container,
      edges: model.columnVisibility == .detailOnly ? .top : []
    )
    .background(
      WindowLayoutCoordinator(
        title: logicalWindowTitle,
        aspectRatio: model.previewAspectRatio,
        sidebarWidth: model.sidebarWidth,
        sidebarIsVisible: model.columnVisibility != .detailOnly,
        cornerRadiusFraction: currentCornerRadiusFraction,
        onRestoreSidebarAfterFullScreen: {
          model.setColumnVisibility(.all)
        }
      )
    )
    .sheet(item: $cornerAdjustmentDevice) { device in
      CornerAdjustmentView(
        device: device,
        aspectRatio: device.id == model.selectedDeviceID ? model.previewAspectRatio : nil,
        preferences: cornerPreferences
      )
    }
  }

  private var logicalWindowTitle: String {
    devices.first { $0.id == model.selectedDeviceID }?.name ?? "USB Display"
  }

  private var currentCornerRadiusFraction: Double {
    guard let device = devices.first(where: { $0.id == model.selectedDeviceID }) else {
      return 0
    }
    return cornerPreferences.resolvedFraction(
      for: device,
      aspectRatio: model.previewAspectRatio
    )
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
