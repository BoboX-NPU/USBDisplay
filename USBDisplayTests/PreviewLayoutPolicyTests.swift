import Testing

@testable import iPhoneUSBDisplay

struct PreviewLayoutPolicyTests {
  @Test
  func rejectsInvalidAspectRatios() {
    #expect(PreviewLayoutPolicy.validAspectRatio(width: 0, height: 10) == nil)
    #expect(PreviewLayoutPolicy.validAspectRatio(width: 10, height: 0) == nil)
    #expect(PreviewLayoutPolicy.validAspectRatio(width: .infinity, height: 10) == nil)
  }

  @Test
  func fitsPortraitPreviewInsideDisplayArea() {
    let size = PreviewLayoutPolicy.fittedSize(
      containerWidth: 800,
      containerHeight: 600,
      aspectRatio: 9.0 / 16.0
    )

    #expect(abs(size.width - 319.5) < 0.001)
    #expect(size.height == 568)
  }

  @Test
  func fitsLandscapePreviewInsideDisplayArea() {
    let size = PreviewLayoutPolicy.fittedSize(
      containerWidth: 800,
      containerHeight: 600,
      aspectRatio: 16.0 / 9.0
    )

    #expect(size.width == 768)
    #expect(abs(size.height - 432) < 0.001)
  }

  @Test
  func unknownRatioUsesAvailableInsetArea() {
    #expect(
      PreviewLayoutPolicy.fittedSize(
        containerWidth: 800,
        containerHeight: 600,
        aspectRatio: nil
      ) == PreviewSize(width: 768, height: 568)
    )
  }
}
