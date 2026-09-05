import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
  private(set) var selectedDeviceID: String?
  private(set) var sidebarIsVisible = true
  let sidebarWidth = 220.0
  private var presentation: CapturePresentationState

  @ObservationIgnored private var coordinator: (any CaptureCoordinating)!
  @ObservationIgnored private var active = false

  var session: AVCaptureSession { coordinator.session }
  var status: ConnectionStatus { presentation.status }
  var previewAspectRatio: Double? { presentation.aspectRatio }
  var previewSource: PreviewSource? { presentation.source }

  init(
    deviceID: String? = nil,
    makeCoordinator: (@escaping CaptureCoordinator.SnapshotHandler) -> any CaptureCoordinating = {
      CaptureCoordinator(snapshotHandler: $0)
    }
  ) {
    selectedDeviceID = deviceID
    presentation = CapturePresentationState(request: CaptureRequest(deviceID: deviceID))
    coordinator = makeCoordinator { [weak self] snapshot in
      self?.presentation.apply(snapshot)
    }
  }

  func start() {
    guard !active else { return }
    active = true
    renewRequest()
  }

  func stop() {
    guard active else { return }
    active = false
    renewRequest()
  }

  func setDeviceID(_ deviceID: String?) {
    guard deviceID != selectedDeviceID else { return }
    selectedDeviceID = deviceID
    renewRequest()
  }

  private func renewRequest() {
    let request = CaptureRequest(deviceID: selectedDeviceID)
    presentation = CapturePresentationState(request: request)
    coordinator.update(request: request, active: active)
  }

  func setSidebarVisible(_ isVisible: Bool) {
    sidebarIsVisible = isVisible
  }

  func updatePreviewAspectRatio(source: PreviewSource, width: Double, height: Double) {
    presentation.updateAspectRatio(source: source, width: width, height: height)
  }
}
