import AppKit
import SwiftUI

struct DisplayCanvasView: View {
  @Bindable var model: AppModel
  let hasAvailableDevices: Bool

  var body: some View {
    ZStack {
      Color.black

      PreviewView(
        session: model.session,
        onAspectRatioChanged: model.updatePreviewAspectRatio
      )

      if !model.status.isConnected {
        emptyState
          .transition(.opacity)
      }
    }
    .clipped()
  }

  private var emptyState: some View {
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

      if model.selectedDeviceID == nil, !hasAvailableDevices {
        VStack(spacing: 4) {
          Text("Connect an iPhone or iPad using a USB cable")
          Text("Unlock the device and trust this Mac if prompted.")
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      } else if let detail = model.status.detail, model.selectedDeviceID != nil {
        Text(detail)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(32)
    .accessibilityElement(children: .combine)
  }

  private var emptyStateTitle: String {
    if model.selectedDeviceID == nil, hasAvailableDevices {
      return "Select a device"
    }
    return model.status.title
  }

  private var statusSymbol: String {
    switch model.status {
    case .cameraPermissionDenied:
      "video.slash"
    case .occupied, .deviceUnavailable:
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
