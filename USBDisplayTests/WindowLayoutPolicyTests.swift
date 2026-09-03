import Testing

@testable import iPhoneUSBDisplay

struct WindowLayoutPolicyTests {
  @Test
  func rejectsInvalidAspectRatios() {
    #expect(WindowLayoutPolicy.validAspectRatio(width: 0, height: 10) == nil)
    #expect(WindowLayoutPolicy.validAspectRatio(width: 10, height: 0) == nil)
    #expect(WindowLayoutPolicy.validAspectRatio(width: .infinity, height: 10) == nil)
  }

  @Test
  func portraitPreviewFillsVisibleDetailAtExactRatio() {
    let size = WindowLayoutPolicy.contentSize(
      previewHeight: 640,
      aspectRatio: 9.0 / 16.0,
      sidebarWidth: 220,
      sidebarIsVisible: true
    )

    #expect(size == WindowContentSize(width: 581, height: 640))
  }

  @Test
  func landscapePreviewFillsVisibleDetailAtExactRatio() {
    let size = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 16.0 / 9.0,
      sidebarWidth: 220,
      sidebarIsVisible: true
    )

    #expect(size == WindowContentSize(width: 1287.6666666666665, height: 600))
  }

  @Test
  func hiddenSidebarRemovesItsEntireContribution() {
    let size = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: false
    )

    #expect(size == WindowContentSize(width: 800, height: 600))
  }

  @Test
  func showingSidebarAddsWidthWithoutChangingPreviewSize() {
    let hiddenSize = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: false
    )
    let visibleSize = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: true
    )

    #expect(hiddenSize == WindowContentSize(width: 800, height: 600))
    #expect(visibleSize == WindowContentSize(width: 1021, height: 600))
  }

  @Test
  func changingSidebarWidthChangesOnlyOuterWidth() {
    let narrowSize = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 180,
      sidebarIsVisible: true
    )
    let wideSize = WindowLayoutPolicy.contentSize(
      previewHeight: 600,
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 280,
      sidebarIsVisible: true
    )

    #expect(narrowSize == WindowContentSize(width: 981, height: 600))
    #expect(wideSize == WindowContentSize(width: 1081, height: 600))
  }

  @Test
  func deviceChangePreservesHeightWhenItFits() {
    let size = WindowLayoutPolicy.sizePreservingHeight(
      currentHeight: 600,
      aspectRatio: 9.0 / 16.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 1400, height: 900)
    )

    #expect(size == WindowContentSize(width: 558.5, height: 600))
  }

  @Test
  func deviceChangeShrinksToVisibleBounds() {
    let size = WindowLayoutPolicy.sizePreservingHeight(
      currentHeight: 900,
      aspectRatio: 16.0 / 9.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 1200, height: 700)
    )

    #expect(abs((size?.width ?? 0) - 1200) < 0.001)
    #expect(abs((size?.height ?? 0) - 550.6875) < 0.001)
  }

  @Test
  func visibleBoundsOverrideNominalMinimumPreviewHeight() {
    let size = WindowLayoutPolicy.sizePreservingHeight(
      currentHeight: WindowLayoutPolicy.minimumPreviewHeight,
      aspectRatio: 16.0 / 9.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 700, height: 600)
    )

    #expect(abs((size?.width ?? 0) - 700) < 0.001)
    #expect(abs((size?.height ?? 0) - 269.4375) < 0.001)
  }

  @Test
  func widthDrivenResizeAdjustsHeight() {
    let size = WindowLayoutPolicy.constrainedResize(
      proposedSize: WindowContentSize(width: 1021, height: 600),
      previousSize: WindowContentSize(width: 821, height: 600),
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 1600, height: 1000)
    )

    #expect(size == WindowContentSize(width: 1021, height: 600))
  }

  @Test
  func heightDrivenResizeAdjustsWidth() {
    let size = WindowLayoutPolicy.constrainedResize(
      proposedSize: WindowContentSize(width: 821, height: 700),
      previousSize: WindowContentSize(width: 821, height: 600),
      aspectRatio: 4.0 / 3.0,
      sidebarWidth: 220,
      sidebarIsVisible: true,
      maximumSize: WindowContentSize(width: 1600, height: 1000)
    )

    #expect(abs((size?.width ?? 0) - 1154.3333333333333) < 0.001)
    #expect(size?.height == 700)
  }

  @Test
  func fullScreenDoesNotConstrainWindow() {
    #expect(!WindowLayoutPolicy.shouldConstrainWindow(isFullScreen: true, aspectRatio: 4.0 / 3.0))
    #expect(!WindowLayoutPolicy.shouldConstrainWindow(isFullScreen: false, aspectRatio: nil))
    #expect(WindowLayoutPolicy.shouldConstrainWindow(isFullScreen: false, aspectRatio: 4.0 / 3.0))
  }

  @Test
  func expandedSidebarAlwaysShowsStandardWindowButtons() {
    var state = WindowControlsVisibilityState(sidebarIsVisible: true)

    #expect(state.showsStandardButtons)
    let shouldScheduleHide = state.pointerExitedTitlebar()
    #expect(!shouldScheduleHide)
    #expect(state.showsStandardButtons)
  }

  @Test
  func collapsedSidebarHidesButtonsWhenPointerIsOutsideTitlebar() {
    let state = WindowControlsVisibilityState(sidebarIsVisible: false)

    #expect(!state.showsStandardButtons)
  }

  @Test
  func enteringTitlebarShowsButtonsImmediately() {
    var state = WindowControlsVisibilityState(sidebarIsVisible: false)

    state.pointerEnteredTitlebar()

    #expect(state.showsStandardButtons)
    #expect(!state.hideIsPending)
  }

  @Test
  func exitingTitlebarKeepsButtonsVisibleUntilDelayElapses() {
    var state = WindowControlsVisibilityState(sidebarIsVisible: false)
    state.pointerEnteredTitlebar()

    let shouldScheduleHide = state.pointerExitedTitlebar()
    #expect(shouldScheduleHide)
    #expect(state.hideIsPending)
    #expect(state.showsStandardButtons)

    state.hideDelayElapsed()

    #expect(!state.hideIsPending)
    #expect(!state.showsStandardButtons)
  }

  @Test
  func reenteringTitlebarCancelsPendingHide() {
    var state = WindowControlsVisibilityState(sidebarIsVisible: false)
    state.pointerEnteredTitlebar()
    _ = state.pointerExitedTitlebar()

    state.pointerEnteredTitlebar()
    state.hideDelayElapsed()

    #expect(!state.hideIsPending)
    #expect(state.showsStandardButtons)
  }

  @Test
  func expandingSidebarCancelsPendingHideAndShowsButtons() {
    var state = WindowControlsVisibilityState(sidebarIsVisible: false)
    state.pointerEnteredTitlebar()
    _ = state.pointerExitedTitlebar()

    state.updateSidebarVisibility(true, pointerIsInsideTitlebar: false)

    #expect(!state.hideIsPending)
    #expect(state.showsStandardButtons)
  }
}
