import SwiftUI

struct SidebarView: View {
  let devices: [DisplayDevice]
  let selectedDeviceID: String?
  let onSelectDevice: (String) -> Void

  var body: some View {
    List(selection: selection) {
      Section("Devices") {
        if devices.isEmpty {
          Label("No Devices", systemImage: "rectangle.connected.to.line.below")
            .foregroundStyle(.secondary)
        } else {
          ForEach(devices) { device in
            Label(device.name, systemImage: "rectangle.portrait.on.rectangle.portrait")
              .lineLimit(1)
              .tag(device.id)
          }
        }
      }
    }
    .listStyle(.sidebar)
    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
  }

  private var selection: Binding<String?> {
    Binding(
      get: { selectedDeviceID },
      set: { selectedID in
        guard let selectedID else { return }
        onSelectDevice(selectedID)
      }
    )
  }
}
