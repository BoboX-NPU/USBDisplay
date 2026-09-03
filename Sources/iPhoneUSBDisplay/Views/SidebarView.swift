import SwiftUI

struct SidebarView: View {
  @Bindable var model: AppModel

  var body: some View {
    List(selection: selection) {
      Section("Devices") {
        if model.devices.isEmpty {
          Label("No Devices", systemImage: "rectangle.connected.to.line.below")
            .foregroundStyle(.secondary)
        } else {
          ForEach(model.devices) { device in
            DeviceSidebarRow(
              device: device,
              isSelected: device.id == model.selectedDeviceID,
              status: device.id == model.selectedDeviceID ? model.status : nil
            )
            .tag(device.id)
          }
        }
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("Devices")
    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
  }

  private var selection: Binding<String?> {
    Binding(
      get: { model.selectedDeviceID },
      set: { selectedID in
        guard let selectedID, selectedID != model.selectedDeviceID else { return }
        model.selectDevice(id: selectedID)
      }
    )
  }
}

private struct DeviceSidebarRow: View {
  let device: DisplayDevice
  let isSelected: Bool
  let status: ConnectionStatus?

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "rectangle.portrait.on.rectangle.portrait")
        .foregroundStyle(.secondary)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(device.name)
          .lineLimit(1)

        Text(status?.title ?? "Available")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 4)

      if isSelected {
        Circle()
          .fill(statusColor)
          .frame(width: 7, height: 7)
          .accessibilityHidden(true)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var statusColor: Color {
    switch status {
    case .connected:
      .green
    case .connecting:
      .yellow
    case .occupied, .deviceUnavailable, .failed, .cameraPermissionDenied:
      .red
    default:
      .secondary
    }
  }
}
