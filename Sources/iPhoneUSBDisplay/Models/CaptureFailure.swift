@preconcurrency import AVFoundation
import Foundation

enum CaptureFailureKind: Equatable, Sendable {
  case occupied
  case deviceUnavailable
  case permissionDenied
  case disconnected
  case mediaServicesReset
  case retryable
}

enum CaptureErrorClassifier {
  private static let invalidDeviceStreamStatus = 560_227_702  // '!dev'

  static func classify(_ error: NSError) -> CaptureFailureKind {
    if error.domain == AVFoundationErrorDomain,
      error.code == AVError.Code.unknown.rawValue,
      underlyingErrors(in: error).contains(where: {
        $0.domain == NSOSStatusErrorDomain && $0.code == invalidDeviceStreamStatus
      })
    {
      return .deviceUnavailable
    }

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

  private static func underlyingErrors(in error: NSError) -> [NSError] {
    var results: [NSError] = []
    var candidate = error.userInfo[NSUnderlyingErrorKey] as? NSError

    while let current = candidate {
      results.append(current)
      candidate = current.userInfo[NSUnderlyingErrorKey] as? NSError
    }

    return results
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
