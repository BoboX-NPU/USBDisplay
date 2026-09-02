import CoreMedia
import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct FrameRenderingPolicyTests {
  @Test
  func dropsFramesWhenDisplayLayerIsBusy() {
    #expect(
      FrameDeliveryPolicy.action(
        isReadyForMoreMediaData: false,
        statusFailed: false,
        requiresFlush: false
      ) == .drop)
  }

  @Test
  func flushesFailedOrStalledDisplayLayerBeforeEnqueueing() {
    #expect(
      FrameDeliveryPolicy.action(
        isReadyForMoreMediaData: false,
        statusFailed: true,
        requiresFlush: false
      ) == .flushAndEnqueue)
    #expect(
      FrameDeliveryPolicy.action(
        isReadyForMoreMediaData: true,
        statusFailed: false,
        requiresFlush: true
      ) == .flushAndEnqueue)
  }

  @Test
  func invalidatesFramesFromPreviousStreamGeneration() {
    var generation = StreamGeneration()
    let first = generation.advance()
    let second = generation.advance()

    #expect(!generation.contains(first))
    #expect(generation.contains(second))
  }

  @Test
  func marksSampleBuffersForImmediateDisplay() throws {
    var sampleBuffer: CMSampleBuffer?
    let status = CMSampleBufferCreateReady(
      allocator: kCFAllocatorDefault,
      dataBuffer: nil,
      formatDescription: nil,
      sampleCount: 0,
      sampleTimingEntryCount: 0,
      sampleTimingArray: nil,
      sampleSizeEntryCount: 0,
      sampleSizeArray: nil,
      sampleBufferOut: &sampleBuffer
    )

    #expect(status == noErr)
    let buffer = try #require(sampleBuffer)
    ImmediateFrameDisplayPolicy.apply(to: buffer)
    #expect(ImmediateFrameDisplayPolicy.isApplied(to: buffer))
  }

  @Test
  func reportsFrameTimingWithoutAccumulatingAcrossWindows() {
    var telemetry = FrameTelemetryAccumulator(reportingInterval: 5)
    telemetry.recordFrame(presentationTime: 10, captureToEnqueueTime: 0.020)
    telemetry.recordFrame(presentationTime: 10.016, captureToEnqueueTime: 0.024)
    telemetry.recordDrop()

    #expect(telemetry.snapshotIfDue(now: 100) == nil)
    let snapshot = telemetry.snapshotIfDue(now: 105)

    #expect(snapshot?.receivedFrames == 2)
    #expect(snapshot?.droppedFrames == 1)
    #expect(abs((snapshot?.averageFrameIntervalMilliseconds ?? 0) - 16) < 0.001)
    #expect(abs((snapshot?.averageCaptureToEnqueueMilliseconds ?? 0) - 22) < 0.001)
  }
}
