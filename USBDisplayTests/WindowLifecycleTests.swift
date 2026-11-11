import AppKit
import Testing

@testable import iPhoneUSBDisplay

@Suite(.serialized)
@MainActor
struct WindowLifecycleTests {
  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: CGRect(x: 300, y: 200, width: 500, height: 448),
      styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false
    )
    window.isReleasedWhenClosed = false
    return window
  }

  private var configuration: WindowLayoutConfiguration {
    WindowLayoutConfiguration(
      title: "Lifecycle fixture", aspectRatio: 0.5, sidebarWidth: 220,
      sidebarIsVisible: true, cornerRadiusFraction: 0.1)
  }

  @Test func ordinaryNonLiveResizeSurvivesChromeChanges() throws {
    let window = makeWindow()
    let host = WindowLayoutHostView(configuration: configuration, animatesChrome: false)
    defer {
      host.prepareForRemoval()
      window.close()
    }
    window.contentView = host
    let before = try #require(host.surfaceLayout)
    let proposed = CGSize(width: window.frame.width + 50, height: window.frame.height + 100)
    let size = try #require(window.delegate?.windowWillResize?(window, to: proposed))
    window.setFrame(CGRect(origin: window.frame.origin, size: size), display: false)
    NotificationCenter.default.post(name: NSWindow.didResizeNotification, object: window)
    let resized = try #require(host.surfaceLayout).preview.size
    #expect(resized.height > before.preview.height)
    host.toggleSidebar()
    #expect(host.surfaceLayout?.preview.size == resized)
    host.revealTitlebar()
    host.hideTitlebar()
    #expect(host.surfaceLayout?.preview.size == resized)
  }

  @Test func ordinaryResizeDuringChromeAnimationSurvivesReservationRelease() throws {
    let window = makeWindow()
    let host = WindowLayoutHostView(configuration: configuration, animationClock: { 0 })
    defer {
      host.prepareForRemoval()
      window.close()
    }
    window.contentView = host
    host.toggleSidebar()
    host.chromeAnimator.advance(to: 0.1)
    #expect(host.chromeAnimator.isRunning)
    let size = try #require(
      window.delegate?.windowWillResize?(
        window,
        to:
          CGSize(width: window.frame.width + 50, height: window.frame.height + 100)))
    window.setFrame(CGRect(origin: window.frame.origin, size: size), display: false)
    NotificationCenter.default.post(name: NSWindow.didResizeNotification, object: window)
    let resized = try #require(host.surfaceLayout).preview.size
    host.chromeAnimator.advance(to: 0.2)
    #expect(host.surfaceLayout?.preview.size == resized)
    #expect(host.surfaceLayout?.externalSidebar == 0)
  }

  @Test func smallerScreenFitsThenLargerScreenRestoresPreferredVideo() throws {
    var state = WindowGeometryState()
    let preferred = CGRect(x: 1500, y: 100, width: 1600, height: 900)
    let small = CGRect(x: -1280, y: 50, width: 1280, height: 720)
    let large = CGRect(x: 0, y: 0, width: 3840, height: 2160)
    state.rememberPreview(preferred)
    for _ in 0..<3 {
      let fitted = try #require(state.layout(sidebar: 221, titlebar: 52, screen: small))
      #expect(small.contains(fitted.frame))
      #expect(fitted.preview.width / fitted.preview.height == 16.0 / 9)
      #expect(state.previewRect == preferred)
      #expect(state.layout(sidebar: 221, titlebar: 52, screen: large)?.previewOnScreen == preferred)
    }
  }

  @Test func screenChangeDuringDragIsAppliedOnReleaseAndDoesNotOverwritePreference() throws {
    let window = makeWindow()
    var screen = CGRect(x: 0, y: 0, width: 2000, height: 1200)
    let host = WindowLayoutHostView(
      configuration: configuration, animatesChrome: false, screenFrame: { _ in screen })
    defer {
      host.prepareForRemoval()
      window.close()
    }
    window.contentView = host
    let preferred = try #require(host.surfaceLayout).preview.size
    let originalFrame = window.frame
    NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: window)
    screen = CGRect(x: 0, y: 0, width: 300, height: 360)
    NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: window)
    #expect(window.frame == originalFrame)
    NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
    #expect(screen.contains(window.frame))
    #expect(host.surfaceLayout!.preview.height < preferred.height)
    screen = CGRect(x: 0, y: 0, width: 2000, height: 1200)
    NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: window)
    #expect(host.surfaceLayout?.preview.size == preferred)
  }

  @Test func screenResizeNotificationBeforeScreenChangeDoesNotReplacePreferredSize() throws {
    let window = makeWindow()
    var screen = CGRect(x: 0, y: 0, width: 2000, height: 1200)
    let host = WindowLayoutHostView(
      configuration: configuration, animatesChrome: false, screenFrame: { _ in screen })
    defer {
      host.prepareForRemoval()
      window.close()
    }
    window.contentView = host
    let preferred = try #require(host.surfaceLayout).preview.size
    screen = CGRect(x: 0, y: 0, width: 300, height: 360)
    NotificationCenter.default.post(name: NSWindow.didResizeNotification, object: window)
    #expect(screen.contains(window.frame))
    screen = CGRect(x: 0, y: 0, width: 2000, height: 1200)
    NotificationCenter.default.post(
      name: NSApplication.didChangeScreenParametersNotification, object: nil)
    #expect(host.surfaceLayout?.preview.size == preferred)
  }

  @Test func failedEntryForwardsAndRestoresResizeAndHover() throws {
    let window = makeWindow()
    let original = FullScreenDelegateRecorder()
    window.delegate = original
    let host = WindowLayoutHostView(
      configuration: configuration.showingSidebar(false), animatesChrome: false)
    defer {
      host.prepareForRemoval()
      window.close()
    }
    window.contentView = host
    let preview = try #require(host.surfaceLayout).preview.size
    NotificationCenter.default.post(name: NSWindow.willEnterFullScreenNotification, object: window)
    #expect(host.preview.isGeometryChanging)
    window.delegate?.windowDidFailToEnterFullScreen?(window)
    #expect(original.entryFailures == 1)
    #expect(!host.preview.isGeometryChanging)
    host.hideTitlebar()
    host.revealTitlebar()
    #expect(window.toolbar?.isVisible == true)
    #expect(host.surfaceLayout?.preview.size == preview)
    host.toggleSidebar()
    #expect(host.surfaceLayout?.sidebar.width == 221)
  }

  @Test func failedExitKeepsFullScreenOverlayAndAllowsLaterExit() throws {
    let window = makeWindow()
    let original = FullScreenDelegateRecorder()
    window.delegate = original
    var fullScreen = true
    let host = WindowLayoutHostView(
      configuration: configuration, animatesChrome: false, isFullScreen: { _ in fullScreen })
    defer {
      host.prepareForRemoval()
      window.close()
    }
    window.contentView = host
    let ordinary = try #require(host.surfaceLayout).preview.size
    NotificationCenter.default.post(name: NSWindow.willEnterFullScreenNotification, object: window)
    NotificationCenter.default.post(name: NSWindow.didEnterFullScreenNotification, object: window)
    NotificationCenter.default.post(name: NSWindow.willExitFullScreenNotification, object: window)
    window.delegate?.windowDidFailToExitFullScreen?(window)
    #expect(original.exitFailures == 1)
    #expect(!host.preview.isGeometryChanging)
    host.updatePointer(CGPoint(x: 1, y: 100))
    let layout = try #require(host.surfaceLayout)
    #expect(layout.externalSidebar == 0)
    #expect(layout.externalTitlebar == 0)
    #expect(layout.sidebar.width == 221)
    fullScreen = false
    NotificationCenter.default.post(name: NSWindow.willExitFullScreenNotification, object: window)
    NotificationCenter.default.post(name: NSWindow.didExitFullScreenNotification, object: window)
    #expect(host.surfaceLayout?.preview.size == ordinary)
  }

  @Test func appearanceCallbackRefreshesTitlebarAndDividerInBothDirections() throws {
    let window = makeWindow()
    let host = WindowLayoutHostView(configuration: configuration, animatesChrome: false)
    defer {
      host.prepareForRemoval()
      window.close()
    }
    window.contentView = host
    let titlebar = try #require(host.subviews.last)
    let split = try #require(host.subviews.compactMap { $0 as? NSSplitView }.first)
    for name in [NSAppearance.Name.aqua, .darkAqua, .aqua] {
      window.appearance = NSAppearance(named: name)
      host.viewDidChangeEffectiveAppearance()
      host.effectiveAppearance.performAsCurrentDrawingAppearance {
        #expect(titlebar.layer?.backgroundColor == NSColor.windowBackgroundColor.cgColor)
        #expect(split.dividerStyle == .thin)
      }
    }
  }

  @Test func cancelledHoverActionsCannotHideLaterReveals() {
    var delayed: [WindowHoverScheduler.Action] = []
    let scheduler = WindowHoverScheduler(after: { _, action in delayed.append(action) })
    var hides = 0
    scheduler.schedule { hides += 1 }
    scheduler.cancel()
    scheduler.schedule { hides += 1 }
    delayed[0]()
    #expect(hides == 0)
    delayed[1]()
    #expect(hides == 1)
  }
}

@MainActor
private final class FullScreenDelegateRecorder: NSObject, NSWindowDelegate {
  var entryFailures = 0
  var exitFailures = 0
  func windowDidFailToEnterFullScreen(_ window: NSWindow) { entryFailures += 1 }
  func windowDidFailToExitFullScreen(_ window: NSWindow) { exitFailures += 1 }
}
