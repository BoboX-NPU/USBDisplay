@preconcurrency import AVFoundation
import Foundation

final class AVFoundationCaptureDriver: CaptureDriving {
  let session = AVCaptureSession()
  private lazy var discovery = MobileScreenDeviceDiscovery.makeSession()
  private let center: NotificationCenter
  private var observers: [NSObjectProtocol] = []

  init(notificationCenter: NotificationCenter = .default) {
    center = notificationCenter
  }

  var isRunning: Bool { session.isRunning }
  var inputDeviceID: String? {
    (session.inputs.first as? AVCaptureDeviceInput)?.device.uniqueID
  }
  var authorization: CaptureAuthorization {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: .authorized
    case .notDetermined: .notDetermined
    default: .denied
    }
  }

  private func captureDevice(withID id: String) -> AVCaptureDevice? {
    MobileScreenDeviceDiscovery.eligibleDevices(in: discovery).first { $0.uniqueID == id }
  }

  func device(withID id: String) -> CaptureDeviceState? {
    guard let device = captureDevice(withID: id) else { return nil }
    return CaptureDeviceState(
      id: id, name: device.localizedName,
      suspended: device.isSuspended, occupied: device.isInUseByAnotherApplication)
  }

  func requestAccess(completion: @escaping @Sendable () -> Void) {
    AVCaptureDevice.requestAccess(for: .video) { _ in completion() }
  }

  func observe(_ handler: @escaping @Sendable (CaptureEvent) -> Void) {
    stopObserving()
    for name in [
      AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification,
    ] {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: nil) { notification in
          guard let device = notification.object as? AVCaptureDevice else { return }
          handler(.availabilityChanged(device.uniqueID))
        })
    }
    observers.append(
      center.addObserver(
        forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
      ) { notification in
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError {
          handler(.failed(error))
        }
      })
    for (name, event) in [
      (AVCaptureSession.wasInterruptedNotification, CaptureEvent.interrupted),
      (AVCaptureSession.interruptionEndedNotification, CaptureEvent.interruptionEnded),
    ] {
      observers.append(
        center.addObserver(forName: name, object: session, queue: nil) { _ in
          handler(event)
        })
    }
  }

  func stopObserving() {
    observers.forEach(center.removeObserver)
    observers.removeAll()
  }

  func configureAndStart(deviceID: String) throws {
    guard let device = captureDevice(withID: deviceID) else {
      throw NSError(domain: AVFoundationErrorDomain, code: AVError.deviceWasDisconnected.rawValue)
    }
    session.beginConfiguration()
    do {
      let input = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(input) else {
        throw NSError(
          domain: "USBDisplay.Capture", code: 1,
          userInfo: [
            NSLocalizedDescriptionKey: "The selected device cannot be added to the capture session."
          ])
      }
      session.addInput(input)
      session.commitConfiguration()
    } catch {
      session.commitConfiguration()
      throw error
    }
    // Keep system-negotiated formats and the same session/preview layer across switches.
    session.startRunning()
  }

  func stopAndClear() {
    if session.isRunning { session.stopRunning() }
    guard !session.inputs.isEmpty || !session.outputs.isEmpty else { return }
    session.beginConfiguration()
    session.inputs.forEach(session.removeInput)
    session.outputs.forEach(session.removeOutput)
    session.commitConfiguration()
  }

  deinit { observers.forEach(center.removeObserver) }
}
