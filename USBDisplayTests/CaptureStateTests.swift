import AVFoundation
import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct CaptureStateTests {
  @Test func sameRatioPublishesAgainForEverySourceIncludingReturnToA() {
    var ratios = PreviewAspectRatioTracker()
    let a = PreviewSource(requestID: UUID(), streamID: UUID())
    let b = PreviewSource(requestID: UUID(), streamID: UUID())
    let returningA = PreviewSource(requestID: UUID(), streamID: UUID())
    for source in [a, b, returningA] {
      ratios.setSource(source)
      let observed1 = ratios.observe(source: source, width: 402, height: 874)
      #expect(observed1)
      let observed2 = ratios.observe(source: source, width: 402, height: 874)
      #expect(!observed2)
      ratios.setSource(source)
      let observed3 = ratios.observe(source: source, width: 402, height: 874)
      #expect(!observed3)
    }
    let observed4 = ratios.observe(source: a, width: 874, height: 402)
    #expect(!observed4)
    ratios.setSource(nil)
    let observed5 = ratios.observe(source: returningA, width: 402, height: 874)
    #expect(!observed5)
  }

  @Test func presentationRejectsOldRequestsSequencesAndSourceRatios() {
    let requestA = CaptureRequest(deviceID: "A")
    let requestB = CaptureRequest(deviceID: "B")
    let stream = UUID()
    var state = CapturePresentationState(request: requestB)
    state.apply(
      CaptureSnapshot(
        request: requestB, streamID: stream, sequence: 3, status: .connected(deviceName: "B")))
    let source = PreviewSource(requestID: requestB.id, streamID: stream)
    state.updateAspectRatio(source: source, width: 1, height: 2)
    for snapshot in [
      CaptureSnapshot(
        request: requestA, streamID: UUID(), sequence: 100, status: .connected(deviceName: "A")),
      CaptureSnapshot(request: requestB, streamID: nil, sequence: 2, status: .noDevice),
      CaptureSnapshot(request: requestB, streamID: nil, sequence: 3, status: .noDevice),
    ] { state.apply(snapshot) }
    #expect(state.status == .connected(deviceName: "B"))
    #expect(state.aspectRatio == 0.5)
    state.apply(
      CaptureSnapshot(
        request: requestB, streamID: UUID(), sequence: 4, status: .connected(deviceName: "B")))
    state.updateAspectRatio(source: source, width: 2, height: 1)
    #expect(state.aspectRatio == nil)
  }

  @Test func interruptedStartupCannotConfirmAndAutomaticRecoveryPublishesConnected() throws {
    let h = CaptureHarness()
    h.state.update(request: CaptureRequest(deviceID: "A"), active: true)
    let stream = try #require(h.snapshots.last?.streamID)
    h.driver.emit(.interrupted)
    h.clock.advance(by: 0.25)
    #expect(h.snapshots.last?.status == .interrupted(deviceName: "A"))
    // AVFoundation may already be running when the interruption-ended event arrives.
    h.driver.emit(.interruptionEnded)
    h.clock.advance(by: 0.25)
    #expect(h.snapshots.last?.status == .connected(deviceName: "A"))
    #expect(h.snapshots.last?.streamID == stream)
    #expect(h.driver.starts == ["A"])
    h.clock.advance(by: 5)
    #expect(h.driver.starts == ["A"])
  }

  @Test func switchingAtoBtoARejectsQueuedEventsAndConfirmations() throws {
    let h = CaptureHarness()
    let firstA = CaptureRequest(deviceID: "A")
    h.state.update(request: firstA, active: true)
    let oldEvent = try #require(h.driver.handler)
    let firstStream = h.snapshots.last?.streamID
    h.state.update(request: CaptureRequest(deviceID: "B"), active: true)
    let returningA = CaptureRequest(deviceID: "A")
    h.state.update(request: returningA, active: true)
    let count = h.snapshots.count
    oldEvent(.interrupted)
    oldEvent(.failed(NSError(domain: AVFoundationErrorDomain, code: -11819)))
    #expect(h.snapshots.count == count)
    h.clock.advance(by: 0.25)
    #expect(h.snapshots.filter { $0.status.isConnected }.count == 1)
    #expect(h.snapshots.last?.request == returningA)
    #expect(h.snapshots.last?.streamID != firstStream)
    #expect(zip(h.snapshots, h.snapshots.dropFirst()).allSatisfy { $0.sequence < $1.sequence })
  }

  @Test func stopInvalidatesEventsConfirmationRetryAndRestartUsesNewStream() throws {
    let h = CaptureHarness()
    h.state.update(request: CaptureRequest(deviceID: "A"), active: true)
    let firstStream = h.snapshots.last?.streamID
    let oldEvent = try #require(h.driver.handler)
    h.driver.emit(.interrupted)
    let stopped = CaptureRequest(deviceID: "A")
    h.state.update(request: stopped, active: false)
    let count = h.snapshots.count
    oldEvent(.interruptionEnded)
    h.clock.advance(by: 10)
    #expect(h.snapshots.count == count)
    #expect(h.snapshots.last?.status == .noDevice)
    #expect(!h.driver.isRunning)
    let restarted = CaptureRequest(deviceID: "A")
    h.state.update(request: restarted, active: true)
    h.clock.advance(by: 0.25)
    #expect(h.snapshots.last?.request == restarted)
    #expect(h.snapshots.last?.status.isConnected == true)
    #expect(h.snapshots.last?.streamID != firstStream)
  }

  @Test func permissionCompletionReevaluatesOnlyCurrentActiveRequest() throws {
    let h = CaptureHarness()
    h.driver.authorization = .notDetermined
    h.state.update(request: CaptureRequest(deviceID: "A"), active: true)
    let completion = try #require(h.driver.permissionCompletion)
    let b = CaptureRequest(deviceID: "B")
    h.state.update(request: b, active: true)
    h.driver.authorization = .authorized
    completion()
    h.clock.advance(by: 0.25)
    #expect(h.driver.starts == ["B"])
    #expect(h.snapshots.last?.request == b)

    h.driver.authorization = .notDetermined
    h.state.update(request: CaptureRequest(deviceID: "A"), active: true)
    let denied = try #require(h.driver.permissionCompletion)
    h.state.update(request: CaptureRequest(deviceID: "A"), active: false)
    let count = h.snapshots.count
    h.driver.authorization = .denied
    denied()
    #expect(h.snapshots.count == count)
    #expect(h.snapshots.last?.status == .noDevice)
  }

  @Test func reconnectAndMediaResetCreateNewStreamsAndReconfirm() throws {
    let h = CaptureHarness()
    let request = CaptureRequest(deviceID: "A")
    h.state.update(request: request, active: true)
    h.clock.advance(by: 0.25)
    let first = h.snapshots.last?.streamID
    h.driver.devices.removeValue(forKey: "A")
    h.driver.emit(.availabilityChanged("A"))
    #expect(h.snapshots.last?.status == .interrupted(deviceName: "A"))
    h.driver.devices["A"] = CaptureDeviceState(id: "A", name: "A")
    h.driver.emit(.availabilityChanged("A"))
    h.clock.advance(by: 0.25)
    let second = h.snapshots.last?.streamID
    #expect(second != first)
    h.driver.emit(.failed(NSError(domain: AVFoundationErrorDomain, code: -11819)))
    #expect(!h.driver.isRunning)
    #expect(h.snapshots.last?.status == .interrupted(deviceName: "A"))
    h.clock.advance(by: 0.75)
    #expect(h.snapshots.last?.status == .connected(deviceName: "A"))
    #expect(h.snapshots.last?.streamID != second)
  }

  @Test func occupiedAndSuspendedDevicesRecoverWithoutReusingOldRetries() {
    let h = CaptureHarness()
    h.driver.devices["A"]?.occupied = true
    h.state.update(request: CaptureRequest(deviceID: "A"), active: true)
    #expect(h.snapshots.last?.status == .occupied(deviceName: "A"))
    #expect(h.driver.starts.isEmpty)
    h.driver.devices["A"]?.occupied = false
    h.driver.devices["A"]?.suspended = true
    h.clock.advance(by: 2)
    #expect(h.snapshots.last?.status == .waitingForUnlockOrTrust(deviceName: "A"))
    h.driver.devices["A"]?.suspended = false
    h.driver.emit(.availabilityChanged("A"))
    h.clock.advance(by: 0.25)
    #expect(h.snapshots.last?.status == .connected(deviceName: "A"))
    h.clock.advance(by: 10)
    #expect(h.driver.starts == ["A"])
  }

  @Test func configurationFailureAndDeniedPermissionCannotLeaveAnInputRunning() {
    let h = CaptureHarness()
    h.driver.startError = NSError(domain: "Fixture", code: 1)
    h.state.update(request: CaptureRequest(deviceID: "A"), active: true)
    #expect(!h.driver.isRunning)
    #expect(h.driver.inputDeviceID == nil)
    if case .failed = h.snapshots.last?.status {} else { Issue.record("Expected failed startup") }
    h.driver.startError = nil
    h.clock.advance(by: 0.75)
    #expect(h.snapshots.last?.status == .connected(deviceName: "A"))
    h.driver.authorization = .denied
    h.state.update(request: CaptureRequest(deviceID: "B"), active: true)
    #expect(!h.driver.isRunning)
    #expect(h.snapshots.last?.status == .cameraPermissionDenied)
    let count = h.snapshots.count
    h.clock.advance(by: 10)
    #expect(h.snapshots.count == count)
  }

  @Test func duplicateDiscoveryDoesNotRestartIdentityWork() {
    var snapshots = DeviceDiscoverySnapshots()
    let a = DisplayDevice(id: "A", name: "A")
    let observed6 = snapshots.accept([])
    #expect(observed6)
    let observed7 = snapshots.accept([])
    #expect(!observed7)
    let observed8 = snapshots.accept([a])
    #expect(observed8)
    let observed9 = snapshots.accept([a])
    #expect(!observed9)
    let observed10 = snapshots.accept([DisplayDevice(id: "A", name: "Renamed")])
    #expect(observed10)
    let observed11 = snapshots.accept([])
    #expect(observed11)
  }
}

@MainActor
struct CaptureModelTests {
  @Test func modelOwnsSelectionAndRejectsCallbacksAfterStopAndRestart() throws {
    let capture = FakeCaptureCoordinator()
    let model = AppModel(
      deviceID: "A",
      makeCoordinator: {
        capture.handler = $0
        return capture
      })
    model.start()
    let a = try #require(capture.requests.last?.0)
    model.setDeviceID("B")
    let b = try #require(capture.requests.last?.0)
    let stream = UUID()
    capture.handler?(
      CaptureSnapshot(
        request: b, streamID: stream, sequence: 2, status: .connected(deviceName: "B")))
    capture.handler?(
      CaptureSnapshot(
        request: a, streamID: UUID(), sequence: 5, status: .connected(deviceName: "A")))
    #expect(model.selectedDeviceID == "B")
    #expect(model.status == .connected(deviceName: "B"))
    model.stop()
    capture.handler?(
      CaptureSnapshot(
        request: b, streamID: stream, sequence: 6, status: .connected(deviceName: "B")))
    #expect(model.status == .noDevice)
    model.start()
    let restarted = try #require(capture.requests.last?.0)
    #expect(restarted.id != b.id)
    capture.handler?(
      CaptureSnapshot(
        request: b, streamID: stream, sequence: 7, status: .connected(deviceName: "B")))
    #expect(model.status == .noDevice)
    model.setDeviceID("A")
    capture.handler?(
      CaptureSnapshot(
        request: a, streamID: stream, sequence: 8, status: .connected(deviceName: "A")))
    #expect(model.status == .noDevice)
  }

  @Test func sourceChangesKeepThePreviewLayerAndCaptureSession() throws {
    let session = AVCaptureSession()
    let view = PreviewHostView(session: session)
    let layer = try #require(view.layer?.sublayers?.first as? AVCaptureVideoPreviewLayer)
    for _ in 0..<3 {
      view.setSource(PreviewSource(requestID: UUID(), streamID: UUID()))
      view.setSession(session)
      #expect(view.layer?.sublayers?.first === layer)
      #expect(layer.session === session)
    }
    view.prepareForRemoval()
  }
}

@MainActor
final class FakeCaptureCoordinator: CaptureCoordinating {
  let session = AVCaptureSession()
  var requests: [(CaptureRequest, Bool)] = []
  var handler: CaptureCoordinator.SnapshotHandler?
  func update(request: CaptureRequest, active: Bool) { requests.append((request, active)) }
}

private final class FakeCaptureDriver: CaptureDriving {
  var isRunning = false
  var inputDeviceID: String?
  var authorization = CaptureAuthorization.authorized
  var devices = [
    "A": CaptureDeviceState(id: "A", name: "A"), "B": CaptureDeviceState(id: "B", name: "B"),
  ]
  var handler: (@Sendable (CaptureEvent) -> Void)?
  var permissionCompletion: (@Sendable () -> Void)?
  var starts: [String] = []
  var startError: NSError?
  func device(withID id: String) -> CaptureDeviceState? { devices[id] }
  func requestAccess(completion: @escaping @Sendable () -> Void) {
    permissionCompletion = completion
  }
  func observe(_ handler: @escaping @Sendable (CaptureEvent) -> Void) { self.handler = handler }
  func stopObserving() { handler = nil }
  func configureAndStart(deviceID: String) throws {
    if let startError { throw startError }
    inputDeviceID = deviceID
    isRunning = true
    starts.append(deviceID)
  }
  func stopAndClear() {
    isRunning = false
    inputDeviceID = nil
  }
  func emit(_ event: CaptureEvent) { handler?(event) }
}

private final class CaptureClock {
  var now = 0.0
  var actions: [(Double, CaptureStateMachine.Action)] = []
  func schedule(_ delay: Double, _ action: @escaping CaptureStateMachine.Action) {
    actions.append((now + delay, action))
  }
  func advance(by interval: Double) {
    let end = now + interval
    while let next = actions.indices.min(by: { actions[$0].0 < actions[$1].0 }),
      actions[next].0 <= end
    {
      let (time, action) = actions.remove(at: next)
      now = time
      action()
    }
    now = end
  }
}

private final class CaptureHarness {
  let driver = FakeCaptureDriver()
  let clock = CaptureClock()
  var snapshots: [CaptureSnapshot] = []
  lazy var state = CaptureStateMachine(
    driver: driver, enqueue: { $0() }, schedule: clock.schedule,
    publish: { [weak self] in self?.snapshots.append($0) })
}
