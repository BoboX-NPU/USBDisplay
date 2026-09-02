@preconcurrency import AVFoundation
import CoreMedia
import Foundation

final class SampleBufferRenderer: @unchecked Sendable {
  let displayLayer = AVSampleBufferDisplayLayer()
  let renderQueue = DispatchQueue(
    label: "com.xuemingbo.iPhoneUSBDisplay.low-latency-renderer",
    qos: .userInteractive
  )

  private var generation = StreamGeneration()
  private var telemetry = FrameTelemetryAccumulator()

  func beginStream() -> Int {
    renderQueue.sync {
      telemetry.reset()
      displayLayer.flushAndRemoveImage()
      return generation.advance()
    }
  }

  func invalidateStream() {
    renderQueue.sync {
      _ = generation.advance()
      telemetry.reset()
      displayLayer.flushAndRemoveImage()
    }
  }

  fileprivate func render(_ sampleBuffer: CMSampleBuffer, generation candidate: Int) {
    guard generation.contains(candidate) else { return }

    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    let hostTime = CMClockGetTime(CMClockGetHostTimeClock())
    telemetry.recordFrame(
      presentationTime: presentationTime.secondsIfNumeric,
      captureToEnqueueTime: CMTimeSubtract(hostTime, presentationTime).secondsIfNumeric
    )

    let action = FrameDeliveryPolicy.action(
      isReadyForMoreMediaData: displayLayer.isReadyForMoreMediaData,
      statusFailed: displayLayer.status == .failed,
      requiresFlush: displayLayer.requiresFlushToResumeDecoding
    )

    if action == .flushAndEnqueue {
      displayLayer.flush()
    }

    guard action != .drop, displayLayer.isReadyForMoreMediaData else {
      telemetry.recordDrop()
      reportTelemetryIfNeeded(hostTime: hostTime)
      return
    }

    ImmediateFrameDisplayPolicy.apply(to: sampleBuffer)
    displayLayer.enqueue(sampleBuffer)
    reportTelemetryIfNeeded(hostTime: hostTime)
  }

  private func reportTelemetryIfNeeded(hostTime: CMTime) {
    guard let snapshot = telemetry.snapshotIfDue(now: hostTime.seconds) else { return }

    let interval =
      snapshot.averageFrameIntervalMilliseconds.map { String(format: "%.2f", $0) }
      ?? "unavailable"
    let age =
      snapshot.averageCaptureToEnqueueMilliseconds.map { String(format: "%.2f", $0) }
      ?? "unavailable"

    AppLogger.performance.info(
      "Low-latency frames received=\(snapshot.receivedFrames) dropped=\(snapshot.droppedFrames) averageIntervalMs=\(interval, privacy: .public) captureToEnqueueMs=\(age, privacy: .public)"
    )
  }
}

final class FrameOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
  @unchecked Sendable
{
  private let renderer: SampleBufferRenderer
  private let generation: Int

  init(renderer: SampleBufferRenderer, generation: Int) {
    self.renderer = renderer
    self.generation = generation
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    renderer.render(sampleBuffer, generation: generation)
  }
}

extension CMTime {
  fileprivate var secondsIfNumeric: TimeInterval? {
    guard isNumeric else { return nil }
    let value = seconds
    return value.isFinite ? value : nil
  }
}
