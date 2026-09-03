@preconcurrency import AVFoundation
import Foundation

final class CaptureCoordinator: @unchecked Sendable {
  typealias SnapshotHandler = @MainActor @Sendable (CaptureSnapshot) -> Void

  let session = AVCaptureSession()

  private let snapshotHandler: SnapshotHandler
  private let sessionQueue = DispatchQueue(
    label: "com.xuemingbo.iPhoneUSBDisplay.capture-session",
    qos: .userInitiated
  )
  private let notificationCenter: NotificationCenter

  private var notificationObservers: [NSObjectProtocol] = []
  private var currentInput: AVCaptureDeviceInput?
  private var currentStatus: ConnectionStatus = .noDevice
  private var selectedDeviceID: String?
  private var lastKnownDeviceName: String?
  private var retryWorkItem: DispatchWorkItem?
  private var retryAttempt = 0
  private var retryGeneration = 0
  private var permissionRequestInFlight = false
  private var started = false
  private var captureStartGeneration = 0

  init(
    deviceID: String? = nil,
    notificationCenter: NotificationCenter = .default,
    snapshotHandler: @escaping SnapshotHandler
  ) {
    selectedDeviceID = deviceID
    self.notificationCenter = notificationCenter
    self.snapshotHandler = snapshotHandler
  }

  func start() {
    sessionQueue.async { [weak self] in
      guard let self, !self.started else { return }
      self.started = true
      self.installObservers()
      self.connectSelectedDevice()
      AppLogger.session.info("Window capture coordinator started")
    }
  }

  func stop() {
    sessionQueue.async { [self] in
      guard started else { return }
      self.started = false
      self.cancelRetry()
      self.notificationObservers.forEach(self.notificationCenter.removeObserver)
      self.notificationObservers.removeAll()
      self.stopAndClearSession()
      AppLogger.session.info("Window capture coordinator stopped")
    }
  }

  func setDeviceID(_ deviceID: String?) {
    sessionQueue.async { [weak self] in
      guard let self, deviceID != self.selectedDeviceID else { return }
      self.cancelRetry()
      self.selectedDeviceID = deviceID
      self.lastKnownDeviceName = nil
      self.connectSelectedDevice()
    }
  }

  private func installObservers() {
    notificationObservers.append(
      notificationCenter.addObserver(
        forName: AVCaptureDevice.wasConnectedNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        guard let device = notification.object as? AVCaptureDevice else { return }
        self?.handleDeviceAvailabilityChange(deviceID: device.uniqueID)
      }
    )
    notificationObservers.append(
      notificationCenter.addObserver(
        forName: AVCaptureDevice.wasDisconnectedNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        guard let device = notification.object as? AVCaptureDevice else { return }
        self?.handleDeviceAvailabilityChange(deviceID: device.uniqueID)
      }
    )
    notificationObservers.append(
      notificationCenter.addObserver(
        forName: AVCaptureSession.runtimeErrorNotification,
        object: session,
        queue: nil
      ) { [weak self] notification in
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
          return
        }
        self?.sessionQueue.async { [weak self] in
          self?.handleRuntimeError(error)
        }
      }
    )
    notificationObservers.append(
      notificationCenter.addObserver(
        forName: AVCaptureSession.wasInterruptedNotification,
        object: session,
        queue: nil
      ) { [weak self] _ in
        self?.sessionQueue.async { [weak self] in
          self?.handleInterruption()
        }
      }
    )
    notificationObservers.append(
      notificationCenter.addObserver(
        forName: AVCaptureSession.interruptionEndedNotification,
        object: session,
        queue: nil
      ) { [weak self] _ in
        self?.sessionQueue.async { [weak self] in
          self?.retryAttempt = 0
          self?.connectSelectedDevice()
        }
      }
    )
  }

  private func handleDeviceAvailabilityChange(deviceID: String) {
    sessionQueue.async { [weak self] in
      guard let self, deviceID == self.selectedDeviceID else { return }
      self.connectSelectedDevice()
    }
  }

  private func connectSelectedDevice() {
    guard started else { return }

    guard let selectedDeviceID else {
      cancelRetry()
      stopAndClearSession()
      publish(status: .noDevice)
      return
    }

    guard let device = MobileScreenDeviceDiscovery.device(withID: selectedDeviceID) else {
      cancelRetry()
      stopAndClearSession()
      publish(status: .interrupted(deviceName: lastKnownDeviceName))
      return
    }

    lastKnownDeviceName = device.localizedName

    if currentInput?.device.uniqueID == device.uniqueID, session.isRunning {
      publish(status: currentStatus)
      return
    }

    if device.isSuspended {
      stopAndClearSession()
      publish(status: .waitingForUnlockOrTrust(deviceName: device.localizedName))
      scheduleRetry(for: device, occupied: false)
      return
    }

    if device.isInUseByAnotherApplication {
      stopAndClearSession()
      publish(status: .occupied(deviceName: device.localizedName))
      scheduleRetry(for: device, occupied: true)
      return
    }

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      configureAndStartSession(for: device)

    case .notDetermined:
      requestPermission(for: device)

    case .denied, .restricted:
      stopAndClearSession()
      publish(status: .cameraPermissionDenied)

    @unknown default:
      stopAndClearSession()
      publish(status: .cameraPermissionDenied)
    }
  }

  private func requestPermission(for device: AVCaptureDevice) {
    guard !permissionRequestInFlight else { return }
    permissionRequestInFlight = true
    publish(status: .connecting(deviceName: device.localizedName))

    AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
      self?.sessionQueue.async { [weak self] in
        guard let self else { return }
        self.permissionRequestInFlight = false

        if granted {
          self.connectSelectedDevice()
        } else {
          self.stopAndClearSession()
          self.publish(status: .cameraPermissionDenied)
        }
      }
    }
  }

  private func configureAndStartSession(for device: AVCaptureDevice) {
    retryWorkItem?.cancel()
    retryWorkItem = nil
    publish(status: .connecting(deviceName: device.localizedName))
    stopAndClearSession()

    do {
      session.beginConfiguration()
      defer { session.commitConfiguration() }

      let input = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(input) else {
        throw CaptureCoordinatorError.cannotAddInput
      }

      session.addInput(input)
      currentInput = input
      AppLogger.session.info("Using the system-negotiated mobile screen stream")
    } catch {
      handleConnectionError(error as NSError, device: device)
      return
    }

    session.startRunning()

    if session.isRunning {
      AppLogger.session.info("Direct preview capture session started")
      confirmSessionAfterStabilization(for: device)
    } else {
      publish(status: .failed(message: "The device screen stream did not start."))
      scheduleRetry(for: device, occupied: false)
    }
  }

  private func handleConnectionError(_ error: NSError, device: AVCaptureDevice) {
    let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
    let underlyingDomain = underlying?.domain ?? "none"
    let underlyingCode = underlying?.code ?? 0
    AppLogger.session.error(
      "Capture connection failed domain=\(error.domain, privacy: .public) code=\(error.code) underlyingDomain=\(underlyingDomain, privacy: .public) underlyingCode=\(underlyingCode) description=\(error.localizedDescription, privacy: .public)"
    )
    captureStartGeneration += 1

    switch CaptureErrorClassifier.classify(error) {
    case .occupied:
      publish(status: .occupied(deviceName: device.localizedName))
      scheduleRetry(for: device, occupied: true)
    case .deviceUnavailable:
      stopAndClearSession()
      publish(status: .deviceUnavailable(deviceName: device.localizedName))
      scheduleRetry(for: device, occupied: false)
    case .permissionDenied:
      publish(status: .cameraPermissionDenied)
    case .disconnected:
      stopAndClearSession()
      publish(status: .interrupted(deviceName: device.localizedName))
    case .mediaServicesReset:
      stopAndClearSession()
      scheduleRetry(for: device, occupied: false)
    case .retryable:
      publish(status: .failed(message: error.localizedDescription))
      scheduleRetry(for: device, occupied: false)
    }
  }

  private func handleRuntimeError(_ error: NSError) {
    guard
      let selectedDeviceID,
      let device = MobileScreenDeviceDiscovery.device(withID: selectedDeviceID)
    else {
      stopAndClearSession()
      publish(status: .interrupted(deviceName: lastKnownDeviceName))
      return
    }

    handleConnectionError(error, device: device)
  }

  private func confirmSessionAfterStabilization(for device: AVCaptureDevice) {
    let generation = captureStartGeneration
    let deviceID = device.uniqueID

    sessionQueue.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      guard
        let self,
        generation == self.captureStartGeneration,
        self.session.isRunning,
        self.selectedDeviceID == deviceID,
        self.currentInput?.device.uniqueID == deviceID
      else {
        return
      }

      self.cancelRetry()
      AppLogger.session.info("Direct preview capture session is stable")
      self.publish(status: .connected(deviceName: device.localizedName))
    }
  }

  private func handleInterruption() {
    guard
      let selectedDeviceID,
      let device = MobileScreenDeviceDiscovery.device(withID: selectedDeviceID)
    else {
      publish(status: .interrupted(deviceName: lastKnownDeviceName))
      return
    }

    if device.isInUseByAnotherApplication {
      publish(status: .occupied(deviceName: device.localizedName))
      scheduleRetry(for: device, occupied: true)
    } else {
      publish(status: .interrupted(deviceName: device.localizedName))
      scheduleRetry(for: device, occupied: false)
    }
  }

  private func scheduleRetry(for device: AVCaptureDevice, occupied: Bool) {
    retryWorkItem?.cancel()

    let generation = retryGeneration
    let attempt = RetryAttempt(generation: generation, deviceID: device.uniqueID)
    let delay = RetryPolicy.delay(for: retryAttempt, occupied: occupied)
    retryAttempt += 1

    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard
        attempt.isValid(
          currentGeneration: self.retryGeneration,
          selectedDeviceID: self.selectedDeviceID
        )
      else {
        return
      }

      AppLogger.session.info("Retrying this window's capture device")
      self.connectSelectedDevice()
    }
    retryWorkItem = workItem
    sessionQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  private func cancelRetry() {
    retryWorkItem?.cancel()
    retryWorkItem = nil
    retryGeneration += 1
    retryAttempt = 0
  }

  private func stopAndClearSession() {
    captureStartGeneration += 1

    if session.isRunning {
      session.stopRunning()
    }

    guard !session.inputs.isEmpty || !session.outputs.isEmpty else {
      currentInput = nil
      return
    }

    session.beginConfiguration()
    session.inputs.forEach(session.removeInput)
    session.outputs.forEach(session.removeOutput)
    session.commitConfiguration()
    currentInput = nil
  }

  private func publish(status: ConnectionStatus) {
    currentStatus = status
    let snapshot = CaptureSnapshot(
      selectedDeviceID: selectedDeviceID,
      status: status
    )
    let snapshotHandler = snapshotHandler

    Task { @MainActor in
      snapshotHandler(snapshot)
    }
  }
}

private enum CaptureCoordinatorError: LocalizedError {
  case cannotAddInput

  var errorDescription: String? {
    switch self {
    case .cannotAddInput:
      "The selected device cannot be added to the capture session."
    }
  }
}
