@preconcurrency import AVFoundation
import AppKit
import SwiftUI

@MainActor
final class PreviewHostView: NSView {
  private let previewLayer = AVCaptureVideoPreviewLayer()
  private let contentMask = RoundedContentMask()
  private var aspectRatioTimer: Timer?
  private var aspectRatioFilter = StableAspectRatio()
  private var cornerFraction = 0.0
  private var retainsCornerMask = false
  private var applyingGeometry = false
  var isGeometryChanging = false {
    didSet { if oldValue != isGeometryChanging { aspectRatioFilter.discardCandidate() } }
  }
  private(set) var displayCornerRadius: CGFloat = 0

  var onGeometryApplied: (() -> Void)?
  var onAspectRatioChanged: ((Double, Double) -> Void)?

  init(session: AVCaptureSession) {
    super.init(frame: .zero)
    wantsLayer = true
    layer = CALayer()
    layer?.backgroundColor = NSColor.black.cgColor
    layer?.masksToBounds = true

    previewLayer.videoGravity = .resizeAspect
    previewLayer.backgroundColor = NSColor.black.cgColor
    previewLayer.actions = disabledLayerActions
    layer?.addSublayer(previewLayer)
    setSession(session)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override func layout() {
    super.layout()
    if !applyingGeometry { synchronizeGeometry() }
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    if !applyingGeometry { synchronizeGeometry() }
  }

  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    if !applyingGeometry { synchronizeGeometry() }
  }

  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    synchronizeGeometry()
  }

  func applyGeometry(
    frame: CGRect, cornerFraction: Double, fillsBounds: Bool, retainsCornerMask: Bool = false
  ) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    applyingGeometry = true
    self.cornerFraction = cornerFraction
    self.retainsCornerMask = retainsCornerMask
    // The ordinary window follows the source ratio, but AppKit's frame rounding
    // can leave subpoint letterboxing. Fill that rounding remainder; full screen
    // and unknown source geometry keep the complete aspect-fit picture.
    let gravity: AVLayerVideoGravity = fillsBounds ? .resizeAspectFill : .resizeAspect
    if previewLayer.videoGravity != gravity { previewLayer.videoGravity = gravity }
    if self.frame != frame { self.frame = frame }
    applyingGeometry = false
    synchronizeGeometry()
    CATransaction.commit()
    onGeometryApplied?()
  }

  func applyCornerFraction(_ fraction: Double, retainingMask: Bool) {
    guard cornerFraction != fraction || retainsCornerMask != retainingMask else { return }
    cornerFraction = fraction
    retainsCornerMask = retainingMask
    synchronizeGeometry()
  }

  private func synchronizeGeometry() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let scale = window?.backingScaleFactor ?? 1
    if layer?.contentsScale != scale { layer?.contentsScale = scale }
    if previewLayer.contentsScale != scale { previewLayer.contentsScale = scale }
    if previewLayer.frame != bounds { previewLayer.frame = bounds }
    displayCornerRadius = CGFloat(
      DisplayCornerProfileResolver.cornerRadius(
        shortSide: min(bounds.width, bounds.height), fraction: cornerFraction))
    if let layer {
      contentMask.apply(
        to: layer, bounds: bounds, radius: displayCornerRadius, scale: scale,
        retainingMask: retainsCornerMask)
    }
    CATransaction.commit()
  }

  override var isOpaque: Bool { false }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    synchronizeGeometry()

    aspectRatioTimer?.invalidate()
    aspectRatioTimer = nil

    guard window != nil else { return }

    let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.reportAspectRatioIfAvailable()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    aspectRatioTimer = timer
  }

  override func mouseDown(with event: NSEvent) {
    if event.clickCount == 2 {
      window?.toggleFullScreen(nil)
    } else {
      window?.performDrag(with: event)
    }
  }

  func setSession(_ session: AVCaptureSession) {
    guard previewLayer.session !== session else { return }
    previewLayer.session = session
    aspectRatioFilter = StableAspectRatio()
  }

  func reportAspectRatioIfAvailable() {
    guard !isGeometryChanging, previewLayer.session?.isRunning == true, !bounds.isEmpty else {
      return
    }

    let pictureRect = previewLayer.layerRectConverted(
      fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1)
    )
    guard
      let ratio = WindowLayoutPolicy.validAspectRatio(
        width: pictureRect.width,
        height: pictureRect.height
      )
    else {
      return
    }

    guard aspectRatioFilter.observe(ratio) else { return }
    onAspectRatioChanged?(pictureRect.width, pictureRect.height)
  }

  func prepareForRemoval() {
    aspectRatioTimer?.invalidate()
    aspectRatioTimer = nil
    previewLayer.session = nil
  }

  private var disabledLayerActions: [String: CAAction] {
    [
      "bounds": NSNull(),
      "position": NSNull(),
      "frame": NSNull(),
      "contents": NSNull(),
      "hidden": NSNull(),
    ]
  }

}

/// One complete alpha shape clips the background and video together. The mask
/// stays attached across resizes and changes geometry in the caller's transaction.
@MainActor
final class RoundedContentMask {
  private let shape = CAShapeLayer()
  private var pathSize = CGSize.zero
  private var pathRadius: CGFloat = -1

  init() {
    shape.fillColor = NSColor.black.cgColor
    shape.strokeColor = nil
    shape.actions = [
      "bounds": NSNull(), "position": NSNull(), "path": NSNull(),
      "contentsScale": NSNull(),
    ]
  }

  func apply(
    to layer: CALayer, bounds: CGRect, radius: CGFloat, scale: CGFloat,
    retainingMask: Bool = false
  ) {
    guard radius > 0 || retainingMask, !bounds.isEmpty else {
      if layer.mask != nil { layer.mask = nil }
      return
    }
    // A tiny radius preserves the continuous path's element topology at the
    // expanded end of a transition. Remove the mask only after completion.
    let radius = max(radius, 0.001)
    if shape.frame != bounds { shape.frame = bounds }
    if shape.contentsScale != scale { shape.contentsScale = scale }
    if pathSize != bounds.size || pathRadius != radius {
      shape.path =
        RoundedRectangle(cornerRadius: radius, style: .continuous)
        .path(in: CGRect(origin: .zero, size: bounds.size)).cgPath
      pathSize = bounds.size
      pathRadius = radius
    }
    if layer.mask !== shape { layer.mask = shape }
  }
}
