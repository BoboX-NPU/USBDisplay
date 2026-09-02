@preconcurrency import AVFoundation
import Foundation

enum CaptureFailureKind: Equatable, Sendable {
  case occupied
  case permissionDenied
  case disconnected
  case mediaServicesReset
  case retryable
}

enum CaptureErrorClassifier {
  static func classify(_ error: NSError) -> CaptureFailureKind {
    guard error.domain == AVFoundationErrorDomain else {
      return .retryable
    }

    switch error.code {
    case AVError.Code.deviceAlreadyUsedByAnotherSession.rawValue,
      AVError.Code.deviceInUseByAnotherApplication.rawValue,
      AVError.Code.deviceLockedForConfigurationByAnotherProcess.rawValue:
      return .occupied

    case AVError.Code.applicationIsNotAuthorized.rawValue,
      AVError.Code.applicationIsNotAuthorizedToUseDevice.rawValue:
      return .permissionDenied

    case AVError.Code.deviceWasDisconnected.rawValue,
      AVError.Code.deviceNotConnected.rawValue:
      return .disconnected

    case -11819:  // AVErrorMediaServicesWereReset
      return .mediaServicesReset

    default:
      return .retryable
    }
  }
}

struct RetryAttempt: Equatable, Sendable {
  let generation: Int
  let deviceID: String

  func isValid(currentGeneration: Int, selectedDeviceID: String?) -> Bool {
    generation == currentGeneration && deviceID == selectedDeviceID
  }
}

enum RetryPolicy {
  static func delay(for attempt: Int, occupied: Bool) -> TimeInterval {
    if occupied {
      return 2
    }

    let delays: [TimeInterval] = [0.5, 1, 2, 4, 5]
    return delays[min(max(attempt, 0), delays.count - 1)]
  }
}
