import SwiftUI

struct DisplayWindowScene: View {
  @Binding var deviceID: String?
  let catalog: DeviceCatalog
  let windowRegistry: DeviceWindowRegistry

  @Environment(\.openWindow) private var openWindow
  @State private var model: AppModel
  @State private var windowID = UUID()

  init(
    deviceID: Binding<String?>,
    catalog: DeviceCatalog,
    windowRegistry: DeviceWindowRegistry
  ) {
    _deviceID = deviceID
    self.catalog = catalog
    self.windowRegistry = windowRegistry
    _model = State(initialValue: AppModel(deviceID: deviceID.wrappedValue))
  }

  var body: some View {
    ContentView(
      model: model,
      devices: catalog.devices,
      onSelectDevice: selectDevice
    )
    .onAppear {
      catalog.start()
      if let deviceID {
        _ = windowRegistry.claim(deviceID: deviceID, windowID: windowID)
      }
      model.start()
    }
    .onDisappear {
      if let deviceID {
        windowRegistry.release(deviceID: deviceID, windowID: windowID)
      }
      model.stop()
    }
    .onChange(of: deviceID) { _, newDeviceID in
      model.setDeviceID(newDeviceID)
    }
  }

  private func selectDevice(_ selectedDeviceID: String) {
    switch DeviceWindowRoutingPolicy.route(
      currentDeviceID: deviceID,
      selectedDeviceID: selectedDeviceID
    ) {
    case .assignCurrentWindow(let deviceID):
      guard windowRegistry.claim(deviceID: deviceID, windowID: windowID) else {
        openWindow(id: "display", value: deviceID)
        return
      }
      self.deviceID = deviceID
      model.setDeviceID(deviceID)

    case .keepCurrentWindow:
      break

    case .openDeviceWindow(let deviceID):
      openWindow(id: "display", value: deviceID)
    }
  }
}
