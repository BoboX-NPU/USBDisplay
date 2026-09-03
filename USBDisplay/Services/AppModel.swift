import AVFoundation
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
  private(set) var devices: [DisplayDevice] = []
  private(set) var selectedDeviceID: String?
  private(set) var status: ConnectionStatus = .noDevice
  private(set) var controlsVisible = true
  private(set) var isFullScreen = false
  private(set) var fullScreenToggleRequest = 0
  private(set) var columnVisibility = NavigationSplitViewVisibility.all
  private(set) var captureQuality: CaptureQuality

  @ObservationIgnored private var coordinator: CaptureCoordinator!
  @ObservationIgnored private let clock: AppClock
  @ObservationIgnored private let autoHidePolicy: ControlAutoHidePolicy
  @ObservationIgnored private let userDefaults: UserDefaults
  @ObservationIgnored private var lastActivity: Date
  @ObservationIgnored private var autoHideTask: Task<Void, Never>?
  @ObservationIgnored private var columnVisibilityBeforeFullScreen =
    NavigationSplitViewVisibility.all

  private static let captureQualityKey = "CaptureQuality"

  var session: AVCaptureSession {
    coordinator.session
  }

  var selectedDevice: DisplayDevice? {
    devices.first { $0.id == selectedDeviceID }
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
    autoHidePolicy: ControlAutoHidePolicy = ControlAutoHidePolicy(),
    userDefaults: UserDefaults = .standard
  ) {
    self.clock = clock
    self.autoHidePolicy = autoHidePolicy
    self.userDefaults = userDefaults
    captureQuality =
      userDefaults.string(forKey: Self.captureQualityKey)
      .flatMap(CaptureQuality.init(rawValue:)) ?? .automatic
    lastActivity = clock.now()
    coordinator = CaptureCoordinator(
      userDefaults: userDefaults,
      initialQuality: captureQuality
    ) { [weak self] snapshot in
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

  func setCaptureQuality(_ quality: CaptureQuality) {
    guard quality != captureQuality else { return }
    captureQuality = quality
    userDefaults.set(quality.rawValue, forKey: Self.captureQualityKey)
    registerActivity()
    coordinator.setCaptureQuality(quality)
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

  func setColumnVisibility(_ visibility: NavigationSplitViewVisibility) {
    columnVisibility = visibility
  }

  func showSidebar() {
    columnVisibility = .all
    registerActivity()
  }

  func setFullScreen(_ fullScreen: Bool) {
    guard fullScreen != isFullScreen else { return }

    if fullScreen {
      columnVisibilityBeforeFullScreen = columnVisibility
      columnVisibility = .detailOnly
    } else {
      columnVisibility = columnVisibilityBeforeFullScreen
    }

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
