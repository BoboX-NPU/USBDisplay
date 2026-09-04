import SwiftUI

struct ContentView: View {
  @Bindable var model: AppModel
  let devices: [DisplayDevice]
  let onSelectDevice: (String) -> Void
  let onOpenDeviceInNewWindow: (String) -> Void

  var body: some View {
    WindowLayoutCoordinator(
      configuration: WindowLayoutConfiguration(
        title: selectedDevice?.name ?? "USB Display",
        aspectRatio: model.previewAspectRatio,
        sidebarWidth: model.sidebarWidth,
        sidebarIsVisible: model.sidebarIsVisible,
        cornerRadiusFraction: selectedDevice.map {
          DisplayCornerProfileResolver.automaticProfile(for: $0).fraction
        } ?? 0
      ),
      session: model.session,
      sidebar: AnyView(
        SidebarView(
          devices: devices, selectedDeviceID: model.selectedDeviceID,
          onSelectDevice: onSelectDevice, onOpenDeviceInNewWindow: onOpenDeviceInNewWindow
        )),
      status: AnyView(DisplayCanvasView(model: model, hasAvailableDevices: !devices.isEmpty)),
      statusIsVisible: !model.status.isConnected,
      onAspectRatioChanged: model.updatePreviewAspectRatio,
      onSidebarChanged: model.setSidebarVisible
    )
    .ignoresSafeArea()
  }

  private var selectedDevice: DisplayDevice? {
    devices.first { $0.id == model.selectedDeviceID }
  }
}
