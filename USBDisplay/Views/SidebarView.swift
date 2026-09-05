import SwiftUI

struct SidebarView: View {
  let devices: [DisplayDevice]
  let selectedDeviceID: String?
  let onSelectDevice: (String) -> Void
  let onOpenDeviceInNewWindow: (String) -> Void

  var body: some View {
    List {
      Section("Devices") {
        if devices.isEmpty {
          Label("No Devices", systemImage: "rectangle.connected.to.line.below")
            .foregroundStyle(.secondary)
        } else {
          ForEach(devices) { device in
            let isSelected = device.id == selectedDeviceID
            let modelName = device.modelDisplayName

            Button {
              onSelectDevice(device.id)
            } label: {
              Label {
                VStack(alignment: .leading, spacing: 3) {
                  Text(device.name)
                  if modelName != device.name {
                    Text(modelName)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              } icon: {
                Image(systemName: "rectangle.portrait.on.rectangle.portrait")
              }
              .lineLimit(1)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 6)
              .padding(.vertical, 4)
              .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
              )
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button("Open in New Window") {
                onOpenDeviceInNewWindow(device.id)
              }
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
          }
        }
      }
    }
    .listStyle(.sidebar)
  }
}
