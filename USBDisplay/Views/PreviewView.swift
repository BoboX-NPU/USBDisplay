@preconcurrency import AVFoundation
import AppKit

@MainActor
final class PreviewHostView: NSView {
  private let previewLayer = AVCaptureVideoPreviewLayer()
  private var aspectRatioTimer: Timer?
  private var lastReportedAspectRatio: Double?

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
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    previewLayer.frame = bounds
    CATransaction.commit()
  }

  func applyGeometry(frame: CGRect, cornerFraction: Double) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    if self.frame != frame { self.frame = frame }
    previewLayer.frame = bounds
    layer?.cornerRadius = DisplayCornerProfileResolver.cornerRadius(
      shortSide: min(bounds.width, bounds.height), fraction: cornerFraction)
    CATransaction.commit()
    onGeometryApplied?()
  }

  override var isOpaque: Bool { false }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

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
