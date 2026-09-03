import AVFoundation
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
  private(set) var selectedDeviceID: String?
  private(set) var status: ConnectionStatus = .noDevice
  private(set) var columnVisibility = NavigationSplitViewVisibility.all
  private(set) var previewAspectRatio: Double?
  private(set) var sidebarWidth = 220.0

  @ObservationIgnored private var coordinator: CaptureCoordinator!

  var session: AVCaptureSession {
    coordinator.session
  }

  init(deviceID: String? = nil) {
    selectedDeviceID = deviceID
    coordinator = CaptureCoordinator(deviceID: deviceID) { [weak self] snapshot in
      self?.apply(snapshot)
    }
  }

  func start() {
    coordinator.start()
  }

  func stop() {
    coordinator.stop()
  }

  func setDeviceID(_ deviceID: String?) {
    guard deviceID != selectedDeviceID else { return }
    selectedDeviceID = deviceID
    previewAspectRatio = nil
    status = .noDevice
    coordinator.setDeviceID(deviceID)
  }

  func setColumnVisibility(_ visibility: NavigationSplitViewVisibility) {
    columnVisibility = visibility
  }

  func updateSidebarWidth(_ width: Double) {
    guard width.isFinite, width > 0, abs(sidebarWidth - width) >= 0.5 else { return }
    sidebarWidth = width
  }

  func updatePreviewAspectRatio(width: Double, height: Double) {
    guard let ratio = WindowLayoutPolicy.validAspectRatio(width: width, height: height) else {
      return
    }

    if let previewAspectRatio, abs(previewAspectRatio - ratio) < 0.001 {
      return
    }

    previewAspectRatio = ratio
    AppLogger.interface.info(
      "Preview aspect ratio changed to \(ratio, format: .fixed(precision: 4))"
    )
  }

  private func apply(_ snapshot: CaptureSnapshot) {
    selectedDeviceID = snapshot.selectedDeviceID
    status = snapshot.status
  }
}
