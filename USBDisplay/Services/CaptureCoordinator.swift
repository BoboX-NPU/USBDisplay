@preconcurrency import AVFoundation
import Foundation

@MainActor
protocol CaptureCoordinating: AnyObject {
  var session: AVCaptureSession { get }
  func update(request: CaptureRequest, active: Bool)
}

/// Owns the serial execution boundary; the state machine also runs synchronously in tests.
final class CaptureCoordinator: CaptureCoordinating, @unchecked Sendable {
  typealias SnapshotHandler = @MainActor @Sendable (CaptureSnapshot) -> Void

  let session: AVCaptureSession
  private let queue: DispatchQueue
  private let state: CaptureStateMachine

  init(snapshotHandler: @escaping SnapshotHandler) {
    let queue = DispatchQueue(
      label: "com.xuemingbo.iPhoneUSBDisplay.capture-session", qos: .userInitiated)
    let driver = AVFoundationCaptureDriver()
    self.queue = queue
    session = driver.session
    state = CaptureStateMachine(
      driver: driver,
      enqueue: { queue.async(execute: $0) },
      schedule: { delay, action in queue.asyncAfter(deadline: .now() + delay, execute: action) },
      publish: { snapshot in Task { @MainActor in snapshotHandler(snapshot) } })
  }

  func update(request: CaptureRequest, active: Bool) {
    queue.async { [state] in state.update(request: request, active: active) }
  }
}

struct CaptureDeviceState: Equatable, Sendable {
  let id: String
  let name: String
  var suspended = false
  var occupied = false
}

enum CaptureAuthorization: Sendable {
  case authorized, notDetermined, denied
}

enum CaptureEvent: Sendable {
  case availabilityChanged(String)
  case interrupted
  case interruptionEnded
  case failed(NSError)
}

/// All access, except delivery of events and authorization completion, is queue-confined.
protocol CaptureDriving: AnyObject {
  var isRunning: Bool { get }
  var inputDeviceID: String? { get }
  var authorization: CaptureAuthorization { get }
  func device(withID id: String) -> CaptureDeviceState?
  func requestAccess(completion: @escaping @Sendable () -> Void)
  func observe(_ handler: @escaping @Sendable (CaptureEvent) -> Void)
  func stopObserving()
  func configureAndStart(deviceID: String) throws
  func stopAndClear()
}

/// Mutable state is confined to the coordinator's queue. Delayed work is invalidated
/// by generations, including work that has already left a scheduler's cancellation boundary.
final class CaptureStateMachine: @unchecked Sendable {
  typealias Action = @Sendable () -> Void
  private let driver: any CaptureDriving
  private let enqueue: (@escaping Action) -> Void
  private let schedule: (TimeInterval, @escaping Action) -> Void
  private let publishSnapshot: (CaptureSnapshot) -> Void
  private var request = CaptureRequest(deviceID: nil)
  private var active = false
  private var streamID: UUID?
  private var sequence: UInt64 = 0
  private var eventGeneration = 0
  private var confirmationGeneration = 0
  private var retryGeneration = 0
  private var retryAttempt = 0
  private var permissionRequestInFlight = false
  private var interrupted = false
  private var lastKnownDeviceName: String?

  init(
    driver: any CaptureDriving,
    enqueue: @escaping (@escaping Action) -> Void,
    schedule: @escaping (TimeInterval, @escaping Action) -> Void,
    publish: @escaping (CaptureSnapshot) -> Void
  ) {
    self.driver = driver
    self.enqueue = enqueue
    self.schedule = schedule
    publishSnapshot = publish
  }

  func update(request: CaptureRequest, active: Bool) {
    self.active = false
    cancelRetry()
    stopAndClear()
    self.request = request
    self.active = active
    lastKnownDeviceName = nil
    if active {
      observeEvents()
      connectSelectedDevice()
    } else {
      publish(.noDevice)
    }
  }

  private func observeEvents() {
    eventGeneration += 1
    let generation = eventGeneration
    driver.observe { [weak self] event in
      self?.enqueue { [weak self] in
        guard let self, self.active, self.eventGeneration == generation else { return }
        self.handle(event)
      }
    }
  }

  private func handle(_ event: CaptureEvent) {
    switch event {
    case .availabilityChanged(let id):
      if id == request.deviceID { connectSelectedDevice() }
    case .interrupted:
      confirmationGeneration += 1
      interrupted = true
      let device = request.deviceID.flatMap(driver.device)
      if let device, device.occupied {
        publish(.occupied(deviceName: device.name))
      } else {
        publish(.interrupted(deviceName: device?.name ?? lastKnownDeviceName))
      }
      scheduleRetry(occupied: device?.occupied == true)
    case .interruptionEnded:
      interrupted = false
      cancelRetry()
      connectSelectedDevice()
    case .failed(let error):
      handleConnectionError(error)
    }
  }

  private func connectSelectedDevice() {
    guard active else { return }
    retryGeneration += 1
    guard let id = request.deviceID else {
      cancelRetry()
      stopAndClear()
      publish(.noDevice)
      return
    }
    guard let device = driver.device(withID: id) else {
      cancelRetry()
      stopAndClear()
      publish(.interrupted(deviceName: lastKnownDeviceName))
      return
    }
    lastKnownDeviceName = device.name
    if device.suspended || device.occupied {
      stopAndClear()
      publish(
        device.occupied
          ? .occupied(deviceName: device.name)
          : .waitingForUnlockOrTrust(deviceName: device.name))
      scheduleRetry(occupied: device.occupied)
      return
    }
    switch driver.authorization {
    case .denied:
      cancelRetry()
      stopAndClear()
      publish(.cameraPermissionDenied)
    case .notDetermined:
      publish(.connecting(deviceName: device.name))
      guard !permissionRequestInFlight else { return }
      permissionRequestInFlight = true
      driver.requestAccess { [weak self] in
        self?.enqueue { [weak self] in
          guard let self else { return }
          self.permissionRequestInFlight = false
          // Authorization is process-wide: re-evaluate only the current active request.
          self.connectSelectedDevice()
        }
      }
    case .authorized:
      if driver.inputDeviceID == id, driver.isRunning, !interrupted {
        confirmSession(for: device)
        return
      }
      stopAndClear()
      streamID = UUID()
      publish(.connecting(deviceName: device.name))
      do {
        try driver.configureAndStart(deviceID: id)
        if driver.isRunning {
          confirmSession(for: device)
        } else {
          publish(.failed(message: "The device screen stream did not start."))
          scheduleRetry(occupied: false)
        }
      } catch {
        handleConnectionError(error as NSError)
      }
    }
  }

  private func confirmSession(for device: CaptureDeviceState) {
    confirmationGeneration += 1
    let generation = confirmationGeneration
    let requestID = request.id
    schedule(0.25) { [weak self] in
      guard let self, self.active, !self.interrupted,
        self.request.id == requestID, self.confirmationGeneration == generation,
        self.driver.isRunning, self.driver.inputDeviceID == device.id
      else { return }
      self.cancelRetry()
      self.publish(.connected(deviceName: device.name))
    }
  }

  private func handleConnectionError(_ error: NSError) {
    confirmationGeneration += 1
    AppLogger.session.error(
      "Capture failed domain=\(error.domain, privacy: .public) code=\(error.code) description=\(error.localizedDescription, privacy: .public)"
    )
    let name = lastKnownDeviceName ?? "the device"
    stopAndClear()
    switch CaptureErrorClassifier.classify(error) {
    case .occupied:
      publish(.occupied(deviceName: name))
      scheduleRetry(occupied: true)
    case .deviceUnavailable:
      publish(.deviceUnavailable(deviceName: name))
      scheduleRetry(occupied: false)
    case .permissionDenied:
      cancelRetry()
      publish(.cameraPermissionDenied)
    case .disconnected:
      cancelRetry()
      publish(.interrupted(deviceName: name))
    case .mediaServicesReset:
      publish(.interrupted(deviceName: name))
      scheduleRetry(occupied: false)
    case .retryable:
      publish(.failed(message: error.localizedDescription))
      scheduleRetry(occupied: false)
    }
  }

  private func scheduleRetry(occupied: Bool) {
    retryGeneration += 1
    let generation = retryGeneration
    let requestID = request.id
    let delay = RetryPolicy.delay(for: retryAttempt, occupied: occupied)
    retryAttempt += 1
    schedule(delay) { [weak self] in
      guard let self, self.active, self.request.id == requestID,
        self.retryGeneration == generation
      else { return }
      self.connectSelectedDevice()
    }
  }

  private func cancelRetry() {
    retryGeneration += 1
    retryAttempt = 0
  }

  private func stopAndClear() {
    confirmationGeneration += 1
    eventGeneration += 1
    driver.stopObserving()
    driver.stopAndClear()
    streamID = nil
    interrupted = false
    if active { observeEvents() }
  }

  private func publish(_ status: ConnectionStatus) {
    sequence += 1
    publishSnapshot(
      CaptureSnapshot(
        request: request, streamID: streamID, sequence: sequence, status: status))
  }
}
