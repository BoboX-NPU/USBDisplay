import AppKit
import SwiftUI

struct DisplayCanvasView: View {
  @Bindable var model: AppModel
  let hasAvailableDevices: Bool

  var body: some View {
    emptyState
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.black)
      .environment(\.colorScheme, .dark)
  }

  @ViewBuilder
  private var emptyState: some View {
    if case .connecting = model.status {
      VStack(spacing: 12) {
        ProgressView().controlSize(.large)
        Text(emptyStateTitle).font(.title2.weight(.semibold))
        stateDescription
      }
      .padding(32)
      .accessibilityElement(children: .combine)
    } else {
      ContentUnavailableView {
        Label(emptyStateTitle, systemImage: statusSymbol)
      } description: {
        stateDescription
      }
    }
  }

  @ViewBuilder
  private var stateDescription: some View {
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
