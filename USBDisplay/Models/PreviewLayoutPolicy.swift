import Foundation

struct PreviewSize: Equatable, Sendable {
  let width: Double
  let height: Double
}

enum PreviewLayoutPolicy {
  static func validAspectRatio(width: Double, height: Double) -> Double? {
    guard width.isFinite, height.isFinite, width > 0, height > 0 else {
      return nil
    }

    let ratio = width / height
    return ratio.isFinite && ratio > 0 ? ratio : nil
  }

  static func fittedSize(
    containerWidth: Double,
    containerHeight: Double,
    aspectRatio: Double?,
    inset: Double = 16
  ) -> PreviewSize {
    let availableWidth = max(containerWidth - inset * 2, 0)
    let availableHeight = max(containerHeight - inset * 2, 0)

    guard
      let aspectRatio,
      validAspectRatio(width: aspectRatio, height: 1) != nil,
      availableWidth > 0,
      availableHeight > 0
    else {
      return PreviewSize(width: availableWidth, height: availableHeight)
    }

    if availableWidth / availableHeight > aspectRatio {
      return PreviewSize(width: availableHeight * aspectRatio, height: availableHeight)
    }

    return PreviewSize(width: availableWidth, height: availableWidth / aspectRatio)
  }
}
