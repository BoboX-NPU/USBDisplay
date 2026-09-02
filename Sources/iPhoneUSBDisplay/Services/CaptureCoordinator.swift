@preconcurrency import AVFoundation
@preconcurrency import CoreMediaIO
import Foundation
@preconcurrency import IOKit.audio

final class CaptureCoordinator: @unchecked Sendable {
  typealias SnapshotHandler = @MainActor @Sendable (CaptureSnapshot) -> Void

  let session = AVCaptureSession()

  private let snapshotHandler: SnapshotHandler
  private let sessionQueue = DispatchQueue(
    label: "com.xuemingbo.iPhoneUSBDisplay.capture-session",
    qos: .userInitiated
  )
  private let notificationCenter: NotificationCenter
  private let userDefaults: UserDefaults

  private var discoverySession: AVCaptureDevice.DiscoverySession?
  private var discoveryObservation: NSKeyValueObservation?
  private var sessionRunningObservation: NSKeyValueObservation?
  private var notificationObservers: [NSObjectProtocol] = []
  private var captureDevices: [String: AVCaptureDevice] = [:]
  private var displayDevices: [DisplayDevice] = []
  private var currentInput: AVCaptureDeviceInput?
  private var currentStatus: ConnectionStatus = .noDevice
  private var selectedDeviceID: String?
  private var lastSelectedDeviceID: String?
  private var retryWorkItem: DispatchWorkItem?
  private var retryAttempt = 0
  private var retryGeneration = 0
  private var permissionRequestInFlight = false
  private var started = false

  private static let lastSelectedDeviceKey = "LastSelectedDisplayDeviceID"

  init(
    notificationCenter: NotificationCenter = .default,
    userDefaults: UserDefaults = .standard,
    snapshotHandler: @escaping SnapshotHandler
  ) {
    self.notificationCenter = notificationCenter
    self.userDefaults = userDefaults
    self.snapshotHandler = snapshotHandler
    lastSelectedDeviceID = userDefaults.string(forKey: Self.lastSelectedDeviceKey)
  }

  func start() {
    sessionQueue.async { [weak self] in
      guard let self, !self.started else { return }
      self.started = true
      self.configureCoreMediaIO()
      self.installObservers()
      self.createDiscoverySession()
      AppLogger.session.info("Capture coordinator started")
    }
  }

  func stop() {
    sessionQueue.async { [weak self] in
      guard let self, self.started else { return }
      self.started = false
      self.cancelRetry()
      self.discoveryObservation?.invalidate()
      self.discoveryObservation = nil
      self.sessionRunningObservation?.invalidate()
      self.sessionRunningObservation = nil
      self.discoverySession = nil
      self.notificationObservers.forEach(self.notificationCenter.removeObserver)
      self.notificationObservers.removeAll()
      self.stopAndClearSession()
      AppLogger.session.info("Capture coordinator stopped")
    }
  }

  func selectDevice(id: String) {
    sessionQueue.async { [weak self] in
      guard let self, self.captureDevices[id] != nil else { return }
      self.cancelRetry()
      self.selectedDeviceID = id
      self.lastSelectedDeviceID = id
      self.userDefaults.set(id, forKey: Self.lastSelectedDeviceKey)
      AppLogger.device.info("User selected an iPhone screen capture device")
      self.connectSelectedDevice()
    }
  }

  private func configureCoreMediaIO() {
    setCoreMediaIOProperty(
      kCMIOHardwarePropertyAllowScreenCaptureDevices,
      value: 1,
      description: "wired screen capture"
    )
    setCoreMediaIOProperty(
      kCMIOHardwarePropertyAllowWirelessScreenCaptureDevices,
      value: 0,
      description: "wireless screen capture"
    )
  }

  private func setCoreMediaIOProperty(
    _ selector: Int,
    value: UInt32,
    description: String
  ) {
    var propertyAddress = CMIOObjectPropertyAddress(
      mSelector: CMIOObjectPropertySelector(selector),
      mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
    var mutableValue = value
    let status = CMIOObjectSetPropertyData(
      CMIOObjectID(kCMIOObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      UInt32(MemoryLayout<UInt32>.size),
      &mutableValue
    )

    if status == noErr {
      AppLogger.device.info("Configured \(description, privacy: .public) discovery")
    } else {
      AppLogger.device.error(
        "Failed to configure \(description, privacy: .public) discovery: \(status)"
      )
    }
  }

  private func createDiscoverySession() {
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.external],
      mediaType: .muxed,
      position: .unspecified
    )
    self.discoverySession = discoverySession
    discoveryObservation = discoverySession.observe(\.devices, options: [.initial, .new]) {
      [weak self] _, _ in
      self?.enqueueDeviceRefresh()
    }
  }

  private func installObservers() {
    sessionRunningObservation = session.observe(\.isRunning, options: [.new]) {
      [weak self] session, _ in
      guard session.isRunning else { return }
      self?.sessionQueue.async { [weak self] in
        guard
          let self,
          let selectedDeviceID = self.selectedDeviceID,
          let device = self.captureDevices[selectedDeviceID]
        else {
          return
        }

        self.retryAttempt = 0
        self.publish(status: .connected(deviceName: device.localizedName))
      }
    }

    notificationObservers.append(
      notificationCenter.addObserver(
        forName: AVCaptureDevice.wasConnectedNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        self?.enqueueDeviceRefresh()
      }
    )
    notificationObservers.append(
      notificationCenter.addObserver(
        forName: AVCaptureDevice.wasDisconnectedNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        self?.enqueueDeviceRefresh()
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

  private func enqueueDeviceRefresh() {
    sessionQueue.async { [weak self] in
      self?.refreshDevices()
    }
  }

  private func refreshDevices() {
    guard started, let discoverySession else { return }

    let eligibleDevices = discoverySession.devices
      .filter { CaptureDeviceFilter.isEligible(Self.descriptor(for: $0)) }
      .sorted {
        $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending
      }

    let previousSelectedID = selectedDeviceID
    let previousSelectedName = previousSelectedID.flatMap { captureDevices[$0]?.localizedName }
    captureDevices = Dictionary(uniqueKeysWithValues: eligibleDevices.map { ($0.uniqueID, $0) })
    displayDevices = eligibleDevices.map {
      DisplayDevice(id: $0.uniqueID, name: $0.localizedName)
    }

    let desiredSelection = DeviceSelectionPolicy.selectedID(
      devices: displayDevices,
      currentID: selectedDeviceID,
      lastSelectedID: lastSelectedDeviceID
    )

    AppLogger.device.info("Found \(self.displayDevices.count) eligible wired iPhone device(s)")

    guard let desiredSelection else {
      cancelRetry()
      selectedDeviceID = nil
      stopAndClearSession()

      if displayDevices.isEmpty {
        publish(
          status: DeviceAbsenceStatusPolicy.status(
            previousSelectedName: previousSelectedName,
            currentStatus: currentStatus
          ))
      } else {
        publish(status: .noDevice)
      }
      return
    }

    if desiredSelection != selectedDeviceID || currentInput?.device.uniqueID != desiredSelection {
      selectedDeviceID = desiredSelection
      connectSelectedDevice()
    } else {
      publish(status: currentStatus)
    }
  }

  private func connectSelectedDevice() {
    guard
      started,
      let selectedDeviceID,
      let device = captureDevices[selectedDeviceID]
    else {
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

    do {
      if session.isRunning {
        session.stopRunning()
      }

      session.beginConfiguration()
      defer { session.commitConfiguration() }

      session.inputs.forEach(session.removeInput)
      currentInput = nil

      let input = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(input) else {
        throw CaptureCoordinatorError.cannotAddInput
      }

      session.addInput(input)
      currentInput = input

      if session.canSetSessionPreset(.high) {
        session.sessionPreset = .high
      }
    } catch {
      handleConnectionError(error as NSError, device: device)
      return
    }

    session.startRunning()

    if session.isRunning {
      cancelRetry()
      AppLogger.session.info("Capture session is running")
      publish(status: .connected(deviceName: device.localizedName))
    } else {
      publish(status: .failed(message: "The iPhone screen stream did not start."))
      scheduleRetry(for: device, occupied: false)
    }
  }

  private func handleConnectionError(_ error: NSError, device: AVCaptureDevice) {
    AppLogger.session.error(
      "Capture connection failed: \(error.localizedDescription, privacy: .public)")

    switch CaptureErrorClassifier.classify(error) {
    case .occupied:
      publish(status: .occupied(deviceName: device.localizedName))
      scheduleRetry(for: device, occupied: true)
    case .permissionDenied:
      publish(status: .cameraPermissionDenied)
    case .disconnected:
      stopAndClearSession()
      publish(status: .interrupted(deviceName: device.localizedName))
      refreshDevices()
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
      let device = captureDevices[selectedDeviceID]
    else {
      return
    }

    handleConnectionError(error, device: device)
  }

  private func handleInterruption() {
    guard
      let selectedDeviceID,
      let device = captureDevices[selectedDeviceID]
    else {
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

      AppLogger.session.info("Retrying the selected capture device")
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
    if session.isRunning {
      session.stopRunning()
    }

    guard !session.inputs.isEmpty else {
      currentInput = nil
      return
    }

    session.beginConfiguration()
    session.inputs.forEach(session.removeInput)
    session.commitConfiguration()
    currentInput = nil
  }

  private func publish(status: ConnectionStatus) {
    currentStatus = status
    let snapshot = CaptureSnapshot(
      devices: displayDevices,
      selectedDeviceID: selectedDeviceID,
      status: status
    )
    let snapshotHandler = snapshotHandler

    Task { @MainActor in
      snapshotHandler(snapshot)
    }
  }

  private static func descriptor(for device: AVCaptureDevice) -> CaptureDeviceDescriptor {
    CaptureDeviceDescriptor(
      isExternal: device.deviceType == .external,
      hasMuxedMedia: device.hasMediaType(.muxed),
      manufacturer: device.manufacturer,
      isUSB: device.transportType == Int32(kIOAudioDeviceTransportTypeUSB)
    )
  }
}

private enum CaptureCoordinatorError: LocalizedError {
  case cannotAddInput

  var errorDescription: String? {
    "The selected iPhone cannot be added to the capture session."
  }
}
