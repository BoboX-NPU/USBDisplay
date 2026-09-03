import SwiftUI

struct SidebarView: View {
  let devices: [DisplayDevice]
  let selectedDeviceID: String?
  let onSelectDevice: (String) -> Void
  let onOpenDeviceInNewWindow: (String) -> Void
  let onWidthChanged: (Double) -> Void

  var body: some View {
    List {
      Section("Devices") {
        if devices.isEmpty {
          Label("No Devices", systemImage: "rectangle.connected.to.line.below")
            .foregroundStyle(.secondary)
        } else {
          ForEach(devices) { device in
            let isSelected = device.id == selectedDeviceID

            Label(device.name, systemImage: "rectangle.portrait.on.rectangle.portrait")
              .lineLimit(1)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 6)
              .padding(.vertical, 4)
              .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
              )
              .contentShape(Rectangle())
              .onTapGesture {
                onSelectDevice(device.id)
              }
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
    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
    .background {
      GeometryReader { geometry in
        Color.clear
          .onAppear {
            onWidthChanged(geometry.size.width)
          }
          .onChange(of: geometry.size.width) { _, width in
            onWidthChanged(width)
          }
      }
    }
  }
}
