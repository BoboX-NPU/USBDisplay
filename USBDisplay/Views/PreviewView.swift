@preconcurrency import AVFoundation
import AppKit

@MainActor
final class PreviewHostView: NSView {
  private let previewLayer = AVCaptureVideoPreviewLayer()
  private var aspectRatioTimer: Timer?
  private var lastReportedAspectRatio: Double?
  private var cornerFraction = 0.0

  var onGeometryApplied: (() -> Void)?
  var onAspectRatioChanged: ((Double, Double) -> Void)?

  init(session: AVCaptureSession) {
    super.init(frame: .zero)
    wantsLayer = true
    layer = CALayer()
    layer?.backgroundColor = NSColor.black.cgColor
    layer?.masksToBounds = true
    layer?.cornerCurve = .continuous

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
    synchronizeGeometry()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    synchronizeGeometry()
  }

  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    synchronizeGeometry()
  }

  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    synchronizeGeometry()
  }

  func applyGeometry(frame: CGRect, cornerFraction: Double, fillsBounds: Bool) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    self.cornerFraction = cornerFraction
    // The ordinary window follows the source ratio, but AppKit's frame rounding
    // can leave subpoint letterboxing. Fill that rounding remainder; full screen
    // and unknown source geometry keep the complete aspect-fit picture.
    let gravity: AVLayerVideoGravity = fillsBounds ? .resizeAspectFill : .resizeAspect
    if previewLayer.videoGravity != gravity { previewLayer.videoGravity = gravity }
    if self.frame != frame { self.frame = frame }
    synchronizeGeometry()
    CATransaction.commit()
    onGeometryApplied?()
  }

  private func synchronizeGeometry() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let scale = window?.backingScaleFactor ?? 1
    if layer?.contentsScale != scale { layer?.contentsScale = scale }
    if previewLayer.contentsScale != scale { previewLayer.contentsScale = scale }
    if previewLayer.frame != bounds { previewLayer.frame = bounds }
    let radius = CGFloat(
      DisplayCornerProfileResolver.cornerRadius(
        shortSide: min(bounds.width, bounds.height), fraction: cornerFraction))
    if layer?.cornerRadius != radius { layer?.cornerRadius = radius }
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
    lastReportedAspectRatio = nil
  }

  func reportAspectRatioIfAvailable() {
    guard previewLayer.session?.isRunning == true, !bounds.isEmpty else { return }

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

    if let lastReportedAspectRatio, abs(lastReportedAspectRatio - ratio) < 0.001 {
      return
    }

    lastReportedAspectRatio = ratio
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
