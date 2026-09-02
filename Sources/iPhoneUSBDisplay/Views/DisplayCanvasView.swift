import SwiftUI

struct DisplayCanvasView: View {
  @Bindable var model: AppModel

  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()

      PreviewView(
        renderer: model.renderer,
        fullScreenToggleRequest: model.fullScreenToggleRequest,
        shouldHideCursor: model.shouldHideCursor,
        onActivity: model.registerActivity,
        onFullScreenChanged: model.setFullScreen
      )
      .ignoresSafeArea()

      if !model.status.isConnected {
        emptyState
          .transition(.opacity)
      }

      if model.isFullScreen, model.controlsVisible || !model.status.isConnected {
        fullScreenControls
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .background(Color.black)
    .onHover { isHovering in
      if isHovering {
        model.registerActivity()
      }
    }
    .animation(.easeOut(duration: 0.18), value: model.controlsVisible)
  }

  private var emptyState: some View {
    AdaptiveGlassSurface(interactive: false) {
      VStack(spacing: 12) {
        if case .connecting = model.status {
          ProgressView()
            .controlSize(.large)
        } else {
          Image(systemName: statusSymbol)
            .font(.system(size: 38, weight: .light))
            .foregroundStyle(.secondary)
        }

        Text(emptyStateTitle)
          .font(.title2.weight(.semibold))

        if case .noDevice = model.status, model.devices.isEmpty {
          VStack(spacing: 4) {
            Text("Connect an iPhone or iPad using a USB cable")
            Text("Unlock the device and trust this Mac if prompted.")
          }
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        } else if let detail = model.status.detail {
          Text(detail)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      }
      .padding(.horizontal, 8)
      .accessibilityElement(children: .combine)
    }
    .padding(32)
  }

  private var fullScreenControls: some View {
    VStack {
      HStack {
        Spacer()

        AdaptiveGlassSurface(interactive: true) {
          HStack(spacing: 14) {
            Button(action: model.showSidebar) {
              Image(systemName: "sidebar.left")
            }
            .buttonStyle(.plain)
            .help("Show Sidebar")
            .accessibilityLabel("Show Sidebar")

            ConnectionStatusView(status: model.status)

            Button(action: model.requestFullScreenToggle) {
              Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .buttonStyle(.plain)
            .help("Exit Full Screen")
            .accessibilityLabel("Exit Full Screen")
          }
        }
      }

      Spacer()
    }
    .padding(16)
  }

  private var emptyStateTitle: String {
    if model.devices.count > 1, model.selectedDeviceID == nil {
      return "Select a device"
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
      "lock"
    default:
      "rectangle.connected.to.line.below"
    }
  }
}

struct ConnectionStatusView: View {
  let status: ConnectionStatus

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(statusColor)
        .frame(width: 7, height: 7)
      Text(status.title)
        .lineLimit(1)
    }
    .font(.caption.weight(.medium))
    .accessibilityElement(children: .combine)
  }

  private var statusColor: Color {
    switch status {
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

private struct AdaptiveGlassSurface<Content: View>: View {
  let interactive: Bool
  @ViewBuilder let content: () -> Content

  var body: some View {
    if #available(macOS 26, *) {
      GlassEffectContainer(spacing: 12) {
        content()
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .glassEffect(
            .regular.interactive(interactive),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
          )
      }
    } else {
      content()
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
          .regularMaterial,
          in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
  }
}
