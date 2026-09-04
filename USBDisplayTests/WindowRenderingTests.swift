import AppKit
import SwiftUI
import Testing

@testable import iPhoneUSBDisplay

@Suite(.serialized)
@MainActor
struct WindowRenderingTests {
  @Test func composedHostingSurfaceHasTransparentCornersAndCurrentDynamicFrame() async throws {
    let window = NSWindow(
      contentRect: CGRect(x: 500, y: 200, width: 240, height: 480),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let config = WindowLayoutConfiguration(
      title: "Synthetic rendering test", aspectRatio: 0.5,
      sidebarWidth: 220, sidebarIsVisible: false, cornerRadiusFraction: 62.0 / 402)
    let surface = WindowLayoutHostView(configuration: config)
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
      let current = try #require(surface.surfaceLayout)
      NotificationCenter.default.post(
        name: NSWindow.willStartLiveResizeNotification, object: window)
      let size = try #require(
        window.delegate?.windowWillResize?(
          window,
          to: CGSize(
            width: 240 + Double(step) + current.externalSidebar,
            height: 480 + Double(2 * step) + current.externalTitlebar)))
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
        for (x, y) in [
          (1, 1), (bitmap.pixelsWide - 2, 1), (1, bitmap.pixelsHigh - 2),
          (bitmap.pixelsWide - 2, bitmap.pixelsHigh - 2),
        ] {
          let corner = try #require(bitmap.colorAt(x: x, y: y))
          #expect(corner.alphaComponent < 0.02)
        }
      }
      // Sample the center and the newly exposed edges, away from the corner mask.
      let previewRect = frameView.convert(surface.preview.bounds, from: surface.preview)
      let scale = Double(bitmap.pixelsWide) / frameView.bounds.width
      for point in [
        CGPoint(x: previewRect.midX, y: previewRect.midY),
        CGPoint(x: previewRect.maxX - 3, y: previewRect.midY),
        CGPoint(x: previewRect.midX, y: previewRect.minY + 3),
      ] {
        let x = Int(point.x * scale)
        let y = bitmap.pixelsHigh - 1 - Int(point.y * scale)
        let pixel = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        if step.isMultiple(of: 2) {
          #expect(pixel.redComponent > 0.8 && pixel.blueComponent < 0.4)
        } else {
          #expect(pixel.blueComponent > 0.8 && pixel.redComponent < 0.4)
        }
        #expect(pixel.alphaComponent > 0.98)
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
}

private struct RenderingFixture: NSViewRepresentable {
  let surface: WindowLayoutHostView
  func makeNSView(context: Context) -> WindowLayoutHostView { surface }
  func updateNSView(_ nsView: WindowLayoutHostView, context: Context) {}
}
