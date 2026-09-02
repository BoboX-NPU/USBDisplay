@preconcurrency import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
  private(set) var devices: [DisplayDevice] = []
  private(set) var selectedDeviceID: String?
  private(set) var status: ConnectionStatus = .noDevice
  private(set) var controlsVisible = true
  private(set) var isFullScreen = false
  private(set) var fullScreenToggleRequest = 0

  @ObservationIgnored private var coordinator: CaptureCoordinator!
  @ObservationIgnored private let clock: AppClock
  @ObservationIgnored private let autoHidePolicy: ControlAutoHidePolicy
  @ObservationIgnored private var lastActivity: Date
  @ObservationIgnored private var autoHideTask: Task<Void, Never>?

  var session: AVCaptureSession {
    coordinator.session
  }

  var shouldHideCursor: Bool {
    autoHidePolicy.shouldHideCursor(
      controlsHidden: !controlsVisible,
      isConnected: status.isConnected,
      isFullScreen: isFullScreen
    )
  }

  init(
    clock: AppClock = .live,
    autoHidePolicy: ControlAutoHidePolicy = ControlAutoHidePolicy()
  ) {
    self.clock = clock
    self.autoHidePolicy = autoHidePolicy
    lastActivity = clock.now()
    coordinator = CaptureCoordinator { [weak self] snapshot in
      self?.apply(snapshot)
    }
  }

  func start() {
    coordinator.start()
  }

  func stop() {
    autoHideTask?.cancel()
    controlsVisible = true
    coordinator.stop()
  }

  func selectDevice(id: String) {
    registerActivity()
    coordinator.selectDevice(id: id)
  }

  func registerActivity() {
    lastActivity = clock.now()
    controlsVisible = true
    scheduleAutoHideIfNeeded()
  }

  func requestFullScreenToggle() {
    registerActivity()
    fullScreenToggleRequest &+= 1
  }

  func setFullScreen(_ fullScreen: Bool) {
    isFullScreen = fullScreen
    registerActivity()
    AppLogger.interface.info("Full screen changed: \(fullScreen)")
  }

  private func apply(_ snapshot: CaptureSnapshot) {
    devices = snapshot.devices
    selectedDeviceID = snapshot.selectedDeviceID
    status = snapshot.status

    if snapshot.status.isConnected {
      scheduleAutoHideIfNeeded()
    } else {
      autoHideTask?.cancel()
      controlsVisible = true
    }
  }

  private func scheduleAutoHideIfNeeded() {
    autoHideTask?.cancel()
    guard status.isConnected else { return }

    let activityDate = lastActivity
    let interval = autoHidePolicy.inactivityInterval
    autoHideTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(interval))
      guard !Task.isCancelled, let self else { return }

      if self.autoHidePolicy.shouldHideControls(
        lastActivity: activityDate,
        now: self.clock.now(),
        isConnected: self.status.isConnected
      ), self.lastActivity == activityDate {
        self.controlsVisible = false
      }
    }
  }
}
