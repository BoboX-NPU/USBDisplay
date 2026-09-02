import CoreMedia
import Foundation

enum FrameDeliveryAction: Equatable, Sendable {
  case drop
  case enqueue
  case flushAndEnqueue
}

enum FrameDeliveryPolicy {
  static func action(
    isReadyForMoreMediaData: Bool,
    statusFailed: Bool,
    requiresFlush: Bool
  ) -> FrameDeliveryAction {
    if statusFailed || requiresFlush {
      return .flushAndEnqueue
    }

    return isReadyForMoreMediaData ? .enqueue : .drop
  }
}

enum ImmediateFrameDisplayPolicy {
  static func apply(to sampleBuffer: CMSampleBuffer) {
    CMSetAttachment(
      sampleBuffer,
      key: kCMSampleAttachmentKey_DisplayImmediately,
      value: kCFBooleanTrue,
      attachmentMode: kCMAttachmentMode_ShouldNotPropagate
    )
  }

  static func isApplied(to sampleBuffer: CMSampleBuffer) -> Bool {
    guard
      let value = CMGetAttachment(
        sampleBuffer,
        key: kCMSampleAttachmentKey_DisplayImmediately,
        attachmentModeOut: nil
      )
    else {
      return false
    }

    return CFEqual(value, kCFBooleanTrue)
  }
}

struct StreamGeneration: Equatable, Sendable {
  private(set) var value = 0

  mutating func advance() -> Int {
    value &+= 1
    return value
  }

  func contains(_ candidate: Int) -> Bool {
    value == candidate
  }
}

struct FrameTelemetrySnapshot: Equatable, Sendable {
  let receivedFrames: Int
  let droppedFrames: Int
  let averageFrameIntervalMilliseconds: Double?
  let averageCaptureToEnqueueMilliseconds: Double?
}

struct FrameTelemetryAccumulator: Sendable {
  let reportingInterval: TimeInterval

  private var receivedFrames = 0
  private var droppedFrames = 0
  private var frameIntervalTotal = 0.0
  private var frameIntervalCount = 0
  private var captureAgeTotal = 0.0
  private var captureAgeCount = 0
  private var lastPresentationTime: TimeInterval?
  private var lastReportTime: TimeInterval?

  init(reportingInterval: TimeInterval = 5) {
    self.reportingInterval = reportingInterval
  }

  mutating func recordFrame(
    presentationTime: TimeInterval?,
    captureToEnqueueTime: TimeInterval?
  ) {
    receivedFrames += 1

    if let presentationTime {
      if let lastPresentationTime {
        let interval = presentationTime - lastPresentationTime
        if interval > 0, interval < 1 {
          frameIntervalTotal += interval
          frameIntervalCount += 1
        }
      }
      self.lastPresentationTime = presentationTime
    }

    if let captureToEnqueueTime, captureToEnqueueTime >= 0, captureToEnqueueTime < 10 {
      captureAgeTotal += captureToEnqueueTime
      captureAgeCount += 1
    }
  }

  mutating func recordDrop() {
    droppedFrames += 1
  }

  mutating func snapshotIfDue(now: TimeInterval) -> FrameTelemetrySnapshot? {
    guard let lastReportTime else {
      self.lastReportTime = now
      return nil
    }

    guard now - lastReportTime >= reportingInterval else { return nil }

    let snapshot = FrameTelemetrySnapshot(
      receivedFrames: receivedFrames,
      droppedFrames: droppedFrames,
      averageFrameIntervalMilliseconds: averageMilliseconds(
        total: frameIntervalTotal,
        count: frameIntervalCount
      ),
      averageCaptureToEnqueueMilliseconds: averageMilliseconds(
        total: captureAgeTotal,
        count: captureAgeCount
      )
    )

    receivedFrames = 0
    droppedFrames = 0
    frameIntervalTotal = 0
    frameIntervalCount = 0
    captureAgeTotal = 0
    captureAgeCount = 0
    self.lastReportTime = now
    return snapshot
  }

  mutating func reset() {
    receivedFrames = 0
    droppedFrames = 0
    frameIntervalTotal = 0
    frameIntervalCount = 0
    captureAgeTotal = 0
    captureAgeCount = 0
    lastPresentationTime = nil
    lastReportTime = nil
  }

  private func averageMilliseconds(total: Double, count: Int) -> Double? {
    guard count > 0 else { return nil }
    return total / Double(count) * 1_000
  }
}
