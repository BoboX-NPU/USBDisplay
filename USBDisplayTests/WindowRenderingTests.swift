import AVFoundation
import AppKit
import SwiftUI
import Testing

@testable import iPhoneUSBDisplay

@Suite(.serialized)
@MainActor
struct WindowRenderingTests {
  @Test func disconnectedSwiftUIContentIgnoresOldPhoneRatio() async throws {
    let capture = FakeCaptureCoordinator()
    let model = AppModel(
      deviceID: "phone",
      makeCoordinator: {
        capture.handler = $0
        return capture
      })
    model.start()
    let request = try #require(capture.requests.last?.0)
    let source = PreviewSource(requestID: request.id, streamID: UUID())
    capture.handler?(
      CaptureSnapshot(
        request: request, streamID: source.streamID, sequence: 1,
        status: .connected(deviceName: "Phone")))
    model.updatePreviewAspectRatio(source: source, width: 402, height: 874)
    model.stop()
    model.updatePreviewAspectRatio(source: source, width: 402, height: 874)
    let window = NSWindow(
      contentRect: CGRect(x: 200, y: 100, width: 238, height: 516),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(
      rootView: ContentView(
        model: model, devices: [], onSelectDevice: { _ in }, onOpenDeviceInNewWindow: { _ in }))
    window.orderFront(nil)
    func surface(in view: NSView) -> WindowLayoutHostView? {
      if let host = view as? WindowLayoutHostView { return host }
      return view.subviews.lazy.compactMap { surface(in: $0) }.first
    }
    defer {
      window.contentView.flatMap { surface(in: $0) }?.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let host = try #require(window.contentView.flatMap { surface(in: $0) })
    let layout = try #require(host.surfaceLayout)
    #expect(window.frame.width >= 720)
    #expect(abs(layout.sidebar.width / window.frame.width - 0.3) < 0.001)
    let preview = window.convertToScreen(host.preview.convert(host.preview.bounds, to: nil))
    #expect(abs(preview.width / window.frame.width - 0.7) < 0.001)
    #expect(preview.maxX == window.frame.maxX)
    let video = try #require(host.preview.layer?.sublayers?.first as? AVCaptureVideoPreviewLayer)
    #expect(video.videoGravity == .resizeAspect)
  }

  @Test func previewLayerAndMaskFollowSizeChangesBeforeDeferredLayout() throws {
    let preview = PreviewHostView(session: AVCaptureSession())
    let fraction = 62.0 / 402
    preview.applyGeometry(
      frame: CGRect(x: 0, y: 0, width: 238, height: 516),
      cornerFraction: fraction, fillsBounds: true)
    let video = try #require(preview.layer?.sublayers?.first as? AVCaptureVideoPreviewLayer)
    let mask = try #require(preview.layer?.mask as? CAShapeLayer)
    for step in 0..<40 {
      let height = 400 + Double(step) * 3.25
      preview.setFrameSize(CGSize(width: ceil(height * 402 / 874), height: height))
      #expect(video.frame == preview.bounds)
      #expect(
        abs(preview.displayCornerRadius - preview.bounds.width * CGFloat(fraction))
          < 0.000001)
      #expect(preview.layer?.mask === mask)
      #expect(mask.frame == preview.bounds)
      #expect(mask.path?.boundingBoxOfPath == preview.bounds)
      #expect(mask.animationKeys()?.isEmpty ?? true)
      #expect(video.animationKeys()?.isEmpty ?? true)
      #expect(preview.layer?.animationKeys()?.isEmpty ?? true)
    }
    preview.setBoundsSize(CGSize(width: 200, height: 435))
    #expect(video.frame == preview.bounds)
    #expect(abs(preview.displayCornerRadius - CGFloat(200 * fraction)) < 0.000001)
    #expect(mask.frame == preview.bounds)
    #expect(video.videoGravity == .resizeAspectFill)
    preview.applyGeometry(
      frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
      cornerFraction: 0, fillsBounds: false)
    #expect(video.videoGravity == .resizeAspect)
    #expect(preview.layer?.cornerRadius == 0)
    #expect(preview.layer?.mask == nil)
  }

  @Test func fractionalPhoneGeometryCoversTheCommittedWindowImmediately() async throws {
    let window = NSWindow(
      contentRect: CGRect(x: 500, y: 200, width: 459, height: 568),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let config = WindowLayoutConfiguration(
      title: "Fractional phone geometry", aspectRatio: 402.0 / 874,
      sidebarWidth: 220, sidebarIsVisible: true, cornerRadiusFraction: 62.0 / 402)
    let surface = WindowLayoutHostView(configuration: config, animatesChrome: false)
    window.contentView = NSHostingView(
      rootView: RenderingFixture(surface: surface).ignoresSafeArea())
    window.orderFront(nil)
    defer {
      surface.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    var samples = 0
    surface.onLayoutCommitted = { layout in
      samples += 1
      // Do not force another layout: the first committed frame must cover the
      // window AppKit actually accepted, including its size quantization.
      #expect(layout.frame == window.frame)
      let rect = surface.preview.convert(surface.preview.bounds, to: nil)
      #expect(abs(rect.maxX - window.frame.width) < 0.000001)
      #expect(abs(rect.minY) < 0.000001)
      #expect(abs(rect.maxY - (window.frame.height - layout.externalTitlebar)) < 0.000001)
    }
    for _ in 0..<20 {
      surface.updateConfiguration(config.showingSidebar(false))
      surface.revealTitlebar()
      surface.hideTitlebar()
      surface.updateConfiguration(config)
    }
    #expect(samples == 80)
    surface.onLayoutCommitted = nil
  }

  @Test func swiftUISceneKeepsCompactWindowFocusable() async throws {
    try await Task.sleep(for: .milliseconds(200))
    func surface(in view: NSView) -> WindowLayoutHostView? {
      if let host = view as? WindowLayoutHostView { return host }
      for child in view.subviews {
        if let host = surface(in: child) { return host }
      }
      return nil
    }
    // Include the real SwiftUI scene owner, whose window behavior differs from
    // the isolated NSWindow fixture below.
    let window = try #require(
      NSApp.windows.first {
        type(of: $0) != NSWindow.self && $0.contentView.flatMap { surface(in: $0) } != nil
      })
    let host = try #require(window.contentView.flatMap { surface(in: $0) })
    let wasVisible = (host.surfaceLayout?.sidebar.width ?? 0) > 0
    if wasVisible { host.toggleSidebar() }
    try await Task.sleep(for: .milliseconds(250))
    defer { if wasVisible { host.toggleSidebar() } }
    host.hideTitlebar()
    try await Task.sleep(for: .milliseconds(250))
    #expect(window.styleMask.contains(.titled))
    #expect(!window.hasShadow)
    #expect(window.canBecomeKey)
    #expect(window.canBecomeMain)
    host.revealTitlebar()
    #expect(window.styleMask.contains(.titled))
    #expect(window.standardWindowButton(.closeButton)?.isHidden == false)
    #expect(window.standardWindowButton(.zoomButton)?.isHidden == false)
    host.hideTitlebar()
  }

  @Test func composedHostingSurfaceHasTransparentCornersAndCurrentDynamicFrame() async throws {
    let window = NSWindow(
      contentRect: CGRect(x: 500, y: 200, width: 240, height: 480),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let config = WindowLayoutConfiguration(
      title: "Synthetic rendering test", aspectRatio: 402.0 / 874,
      sidebarWidth: 220, sidebarIsVisible: false, cornerRadiusFraction: 62.0 / 402)
    let surface = WindowLayoutHostView(configuration: config, animatesChrome: false)
    let hosting = NSHostingView(rootView: RenderingFixture(surface: surface).ignoresSafeArea())
    window.contentView = hosting
    window.orderFront(nil)
    defer {
      surface.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let pattern = CALayer()
    surface.preview.layer?.addSublayer(pattern)
    defer { pattern.removeFromSuperlayer() }
    for step in 0..<12 {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      let color = step.isMultiple(of: 2) ? NSColor.red : NSColor.blue
      surface.preview.onGeometryApplied = { pattern.frame = surface.preview.bounds }
      pattern.backgroundColor = color.cgColor
      pattern.frame = surface.preview.bounds
      surface.updateConfiguration(config)
      surface.hideTitlebar()
      let compact = step % 3 == 1
      if step % 3 == 0 { surface.updateConfiguration(config.showingSidebar(true)) }
      if step % 3 == 2 { surface.revealTitlebar() }
      #expect(window.styleMask.contains(.titled))
      #expect(window.hasShadow == !compact)
      #expect(window.styleMask.contains(.resizable))
      let current = try #require(surface.surfaceLayout)
      NotificationCenter.default.post(
        name: NSWindow.willStartLiveResizeNotification, object: window)
      let size = try #require(
        window.delegate?.windowWillResize?(
          window,
          to: CGSize(
            width: 240.25 + Double(step) + current.externalSidebar,
            height: 480.25 + Double(2 * step) + current.externalTitlebar)))
      window.setFrame(CGRect(origin: window.frame.origin, size: size), display: false)
      NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
      hosting.layoutSubtreeIfNeeded()
      CATransaction.commit()
      try await Task.sleep(for: .milliseconds(20))
      // Includes SwiftUI's hosting surface and the native titlebar/frame hierarchy.
      // This AppKit bitmap check is separate from WindowServer/live-video acceptance.
      let frameView = try #require(window.contentView?.superview)
      let bitmap = try #require(frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds))
      frameView.cacheDisplay(in: frameView.bounds, to: bitmap)
      if compact {
        // Check the whole outer corner strip, including the mid-corner areas
        // where stale rectangular video fragments can survive a resize.
        let reach = Int(Double(bitmap.pixelsWide) * 62 / 402 * 0.75)
        for offset in 0..<reach {
          for inset in 0..<2 {
            for (x, y) in [
              (offset, inset), (bitmap.pixelsWide - 1 - offset, inset),
              (offset, bitmap.pixelsHigh - 1 - inset),
              (bitmap.pixelsWide - 1 - offset, bitmap.pixelsHigh - 1 - inset),
              (inset, offset), (bitmap.pixelsWide - 1 - inset, offset),
              (inset, bitmap.pixelsHigh - 1 - offset),
              (bitmap.pixelsWide - 1 - inset, bitmap.pixelsHigh - 1 - offset),
            ] {
              let corner = try #require(bitmap.colorAt(x: x, y: y))
              #expect(corner.alphaComponent < 0.02)
            }
          }
        }
      }
      // Sample the center and the newly exposed edges, away from the corner mask.
      let previewRect = frameView.convert(surface.preview.bounds, from: surface.preview)
      let scale = Double(bitmap.pixelsWide) / frameView.bounds.width
      let centerPixel = try #require(
        bitmap.colorAt(
          x: Int(previewRect.midX * scale),
          y: bitmap.pixelsHigh - 1 - Int(previewRect.midY * scale))?.usingColorSpace(.sRGB))
      var samplePoints = [
        CGPoint(x: previewRect.midX, y: previewRect.midY),
        CGPoint(x: previewRect.maxX - 3, y: previewRect.midY),
        CGPoint(x: previewRect.midX, y: previewRect.minY + 3),
      ]
      do {
        // Include every chrome state and fractional phone geometry: an inset
        // sample or an exactly divisible 1:2 ratio misses a one-pixel rim.
        let halfPixel = 0.5 / scale
        samplePoints += [
          CGPoint(x: previewRect.minX + halfPixel, y: previewRect.midY),
          CGPoint(x: previewRect.maxX - halfPixel, y: previewRect.midY),
          CGPoint(x: previewRect.midX, y: previewRect.minY + halfPixel),
          CGPoint(x: previewRect.midX, y: previewRect.maxY - halfPixel),
        ]
      }
      for point in samplePoints {
        let x = Int(point.x * scale)
        let y = bitmap.pixelsHigh - 1 - Int(point.y * scale)
        let pixel = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        if step.isMultiple(of: 2) {
          #expect(pixel.redComponent > 0.8 && pixel.blueComponent < 0.4)
        } else {
          #expect(pixel.blueComponent > 0.8 && pixel.redComponent < 0.4)
        }
        #expect(pixel.alphaComponent > 0.98)
        // Compare within the same rendered color space, including its edge pixels.
        #expect(abs(pixel.redComponent - centerPixel.redComponent) < 0.02)
        #expect(abs(pixel.greenComponent - centerPixel.greenComponent) < 0.02)
        #expect(abs(pixel.blueComponent - centerPixel.blueComponent) < 0.02)
      }
      // Use source-over composition, preserving the background under alpha = 0.
      for white in compact ? [true, false] : [] {
        let result = try #require(
          NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: bitmap.pixelsWide, pixelsHigh: bitmap.pixelsHigh,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: result)?.cgContext)
        context.setFillColor((white ? NSColor.white : NSColor.black).cgColor)
        let rect = CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        context.fill(rect)
        context.draw(try #require(bitmap.cgImage), in: rect)
        let corner = try #require(result.colorAt(x: 1, y: 1)?.usingColorSpace(.sRGB))
        #expect(abs(corner.redComponent - (white ? 1 : 0)) < 0.02)
      }
    }
    surface.preview.onGeometryApplied = nil
  }

  @Test func animatedChromeKeepsDynamicEdgesAndClipsEveryIntermediateCorner() async throws {
    let window = NSWindow(
      contentRect: CGRect(x: 500, y: 150, width: 459, height: 568),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let config = WindowLayoutConfiguration(
      title: "Animated rendering fixture", aspectRatio: 402.0 / 874, sidebarWidth: 220,
      sidebarIsVisible: true, cornerRadiusFraction: 62.0 / 402)
    let surface = WindowLayoutHostView(configuration: config)
    window.contentView = NSHostingView(
      rootView: RenderingFixture(surface: surface).ignoresSafeArea())
    window.orderFront(nil)
    defer {
      surface.prepareForRemoval()
      window.close()
    }
    try await Task.sleep(for: .milliseconds(100))
    let pattern = CALayer()
    pattern.frame = surface.preview.bounds
    surface.preview.layer?.addSublayer(pattern)
    defer { pattern.removeFromSuperlayer() }
    let video = surface.preview.layer?.sublayers?.first
    let expected = window.convertToScreen(surface.preview.convert(surface.preview.bounds, to: nil))
    for visible in [false, true] {
      surface.updateConfiguration(config.showingSidebar(visible))
      let start = try #require(surface.chromeAnimator.startedAt)
      for (index, progress) in [0.0, 0.25, 0.5, 0.75, 1].enumerated() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let color = index.isMultiple(of: 2) ? NSColor.red : NSColor.blue
        pattern.backgroundColor = color.cgColor
        surface.chromeAnimator.advance(to: start + progress * WindowChromeAnimator.duration)
        CATransaction.commit()
        #expect(surface.preview.layer?.sublayers?.first === video)
        #expect(
          window.convertToScreen(surface.preview.convert(surface.preview.bounds, to: nil))
            == expected)
        let frameView = try #require(window.contentView?.superview)
        let bitmap = try #require(frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds))
        frameView.cacheDisplay(in: frameView.bounds, to: bitmap)
        let rect = frameView.convert(surface.preview.bounds, from: surface.preview)
        let scale = Double(bitmap.pixelsWide) / frameView.bounds.width
        let inset = 0.5 / scale
        for point in [
          CGPoint(x: rect.midX, y: rect.midY), CGPoint(x: rect.minX + inset, y: rect.midY),
          CGPoint(x: rect.maxX - inset, y: rect.midY), CGPoint(x: rect.midX, y: rect.minY + inset),
          CGPoint(x: rect.midX, y: rect.maxY - inset),
        ] {
          let pixel = try #require(
            bitmap.colorAt(
              x: Int(point.x * scale), y: bitmap.pixelsHigh - 1 - Int(point.y * scale))?
              .usingColorSpace(.sRGB))
          #expect(pixel.alphaComponent > 0.98)
          #expect(index.isMultiple(of: 2) ? pixel.redComponent > 0.8 : pixel.blueComponent > 0.8)
        }
        if surface.preview.displayCornerRadius > 4 {
          for point in [
            CGPoint(x: rect.minX + inset, y: rect.minY + inset),
            CGPoint(x: rect.maxX - inset, y: rect.minY + inset),
            CGPoint(x: rect.minX + inset, y: rect.maxY - inset),
            CGPoint(x: rect.maxX - inset, y: rect.maxY - inset),
          ] {
            let pixel = try #require(
              bitmap.colorAt(
                x: Int(point.x * scale), y: bitmap.pixelsHigh - 1 - Int(point.y * scale)))
            #expect(pixel.alphaComponent < 0.02)
            // Source-over on either a dark or a light desktop retains that
            // background at a transparent corner, throughout the transition.
            for background in [0.0, 1.0] {
              let composed =
                pixel.alphaComponent * pixel.redComponent
                + (1 - pixel.alphaComponent) * background
              #expect(abs(composed - background) < 0.02)
            }
          }
        }
      }
    }
  }
}

private struct RenderingFixture: NSViewRepresentable {
  let surface: WindowLayoutHostView
  func makeNSView(context: Context) -> WindowLayoutHostView { surface }
  func updateNSView(_ nsView: WindowLayoutHostView, context: Context) {}
}
