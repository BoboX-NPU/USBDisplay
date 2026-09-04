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
      onSelectDevice: selectDevice,
      onOpenDeviceInNewWindow: openDeviceInNewWindow
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
      selectedDeviceID: selectedDeviceID,
      selectedDeviceIsClaimedElsewhere: windowRegistry.isClaimed(
        selectedDeviceID,
        byAnotherWindowThan: windowID
      )
    ) {
    case .switchCurrentWindow(let deviceID):
      guard
        windowRegistry.transfer(
          from: self.deviceID,
          to: deviceID,
          windowID: windowID
        )
      else {
        openWindow(id: "display", value: deviceID)
        return
      }
      self.deviceID = deviceID
      model.setDeviceID(deviceID)

    case .keepCurrentWindow:
      break

    case .focusExistingWindow(let deviceID):
      openWindow(id: "display", value: deviceID)
    }
  }

  private func openDeviceInNewWindow(_ deviceID: String) {
    openWindow(id: "display", value: deviceID)
  }
}
