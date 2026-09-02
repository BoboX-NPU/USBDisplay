@preconcurrency import AVFoundation
import Foundation
import Testing

@testable import iPhoneUSBDisplay

struct CaptureFailureTests {
  @Test
  func mapsOccupiedErrors() {
    let error = NSError(
      domain: AVFoundationErrorDomain,
      code: AVError.Code.deviceInUseByAnotherApplication.rawValue
    )

    #expect(CaptureErrorClassifier.classify(error) == .occupied)
  }

  @Test
  func mapsPermissionErrors() {
    let error = NSError(
      domain: AVFoundationErrorDomain,
      code: AVError.Code.applicationIsNotAuthorizedToUseDevice.rawValue
    )

    #expect(CaptureErrorClassifier.classify(error) == .permissionDenied)
  }

  @Test
  func mapsDisconnectAndMediaResetErrors() {
    let disconnect = NSError(
      domain: AVFoundationErrorDomain,
      code: AVError.Code.deviceWasDisconnected.rawValue
    )
    let reset = NSError(
      domain: AVFoundationErrorDomain,
      code: -11819  // AVErrorMediaServicesWereReset
    )

    #expect(CaptureErrorClassifier.classify(disconnect) == .disconnected)
    #expect(CaptureErrorClassifier.classify(reset) == .mediaServicesReset)
  }

  @Test
  func retryAttemptIsCancelledByGenerationOrSelectionChange() {
    let attempt = RetryAttempt(generation: 4, deviceID: "selected")

    #expect(attempt.isValid(currentGeneration: 4, selectedDeviceID: "selected"))
    #expect(!attempt.isValid(currentGeneration: 5, selectedDeviceID: "selected"))
    #expect(!attempt.isValid(currentGeneration: 4, selectedDeviceID: "different"))
  }

  @Test
  func retryDelayIsBounded() {
    #expect(RetryPolicy.delay(for: 0, occupied: false) == 0.5)
    #expect(RetryPolicy.delay(for: 99, occupied: false) == 5)
    #expect(RetryPolicy.delay(for: 99, occupied: true) == 2)
  }
}
