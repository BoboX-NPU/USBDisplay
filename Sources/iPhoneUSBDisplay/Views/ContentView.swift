import SwiftUI

struct ContentView: View {
  @Bindable var model: AppModel

  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()

      PreviewView(
        session: model.session,
        fullScreenToggleRequest: model.fullScreenToggleRequest,
        shouldHideCursor: model.shouldHideCursor,
        onActivity: {
          model.registerActivity()
        },
        onFullScreenChanged: { isFullScreen in
          model.setFullScreen(isFullScreen)
        }
      )
      .ignoresSafeArea()

      if shouldShowEmptyState {
        emptyState
          .transition(.opacity)
      }

      controls
    }
    .background(Color.black)
    .onHover { isHovering in
      if isHovering {
        model.registerActivity()
      }
    }
    .onAppear {
      model.start()
      model.registerActivity()
    }
    .onDisappear {
      model.stop()
    }
  }

  private var shouldShowEmptyState: Bool {
    switch model.status {
    case .connected, .connecting:
      false
    default:
      true
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: statusSymbol)
        .font(.system(size: 42, weight: .light))
        .foregroundStyle(.secondary)

      Text(emptyStateTitle)
        .font(.title2.weight(.semibold))

      if case .noDevice = model.status, model.devices.isEmpty {
        VStack(spacing: 4) {
          Text("Connect an iPhone using a USB cable")
          Text("Unlock the iPhone and trust this Mac if prompted.")
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      } else if let detail = model.status.detail {
        Text(detail)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .foregroundStyle(.white)
    .padding(32)
    .accessibilityElement(children: .combine)
  }

  private var emptyStateTitle: String {
    if model.devices.count > 1, model.selectedDeviceID == nil {
      return "Select an iPhone"
    }
    return model.status.title
  }

  private var statusSymbol: String {
    switch model.status {
    case .cameraPermissionDenied:
      "video.slash"
    case .occupied:
      "exclamationmark.triangle"
    case .interrupted, .failed:
      "cable.connector.slash"
    case .waitingForUnlockOrTrust:
      "lock.iphone"
    default:
      "iphone"
    }
  }

  private var controls: some View {
    VStack {
      HStack(spacing: 12) {
        deviceControl

        Spacer(minLength: 8)

        statusControl

        Button(action: model.requestFullScreenToggle) {
          Image(
            systemName: model.isFullScreen
              ? "arrow.down.right.and.arrow.up.left"
              : "arrow.up.left.and.arrow.down.right")
        }
        .buttonStyle(.plain)
        .font(.system(size: 15, weight: .semibold))
        .help(model.isFullScreen ? "Exit Full Screen" : "Enter Full Screen")
        .accessibilityLabel(model.isFullScreen ? "Exit Full Screen" : "Enter Full Screen")
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 14)
      .padding(.vertical, 11)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .padding(14)

      Spacer()
    }
    .opacity(model.controlsVisible || !model.status.isConnected ? 1 : 0)
    .allowsHitTesting(model.controlsVisible || !model.status.isConnected)
    .animation(.easeOut(duration: 0.18), value: model.controlsVisible)
    .onHover { isHovering in
      if isHovering {
        model.registerActivity()
      }
    }
  }

  @ViewBuilder
  private var deviceControl: some View {
    if model.devices.count > 1 {
      Picker(
        "Device",
        selection: Binding(
          get: { model.selectedDeviceID ?? "" },
          set: { selectedID in
            guard !selectedID.isEmpty else { return }
            model.selectDevice(id: selectedID)
          }
        )
      ) {
        Text("Select an iPhone").tag("")
        ForEach(model.devices) { device in
          Text(device.name).tag(device.id)
        }
      }
      .labelsHidden()
      .frame(maxWidth: 210)
      .accessibilityLabel("iPhone")
    } else if let device = model.devices.first {
      Label(device.name, systemImage: "iphone")
        .lineLimit(1)
    } else {
      Label("No iPhone", systemImage: "iphone.slash")
        .foregroundStyle(.secondary)
    }
  }

  private var statusControl: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)
      Text(model.status.title)
        .lineLimit(1)
    }
    .font(.caption.weight(.medium))
    .accessibilityElement(children: .combine)
  }

  private var statusColor: Color {
    switch model.status {
    case .connected:
      .green
    case .connecting:
      .yellow
    case .occupied, .failed, .cameraPermissionDenied:
      .red
    default:
      .secondary
    }
  }
}
