@preconcurrency import AVFoundation
import AppKit
import SwiftUI

struct PreviewView: NSViewRepresentable {
  let session: AVCaptureSession
  let onAspectRatioChanged: @MainActor (Double, Double) -> Void

  func makeNSView(context: Context) -> PreviewHostView {
    let view = PreviewHostView(session: session)
    update(view)
    return view
  }

  func updateNSView(_ nsView: PreviewHostView, context: Context) {
    update(nsView)
  }

  static func dismantleNSView(_ nsView: PreviewHostView, coordinator: Void) {
    nsView.prepareForRemoval()
  }

  private func update(_ view: PreviewHostView) {
    view.onAspectRatioChanged = onAspectRatioChanged
    view.setSession(session)
    view.reportAspectRatioIfAvailable()
  }
}

@MainActor
final class PreviewHostView: NSView {
  private let previewLayer = AVCaptureVideoPreviewLayer()
  private var aspectRatioTimer: Timer?
  private var lastReportedAspectRatio: Double?

  var onAspectRatioChanged: ((Double, Double) -> Void)?

  init(session: AVCaptureSession) {
    super.init(frame: .zero)
    wantsLayer = true
    layer = CALayer()
    layer?.backgroundColor = NSColor.black.cgColor

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
    reportAspectRatioIfAvailable()
  }

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
      super.mouseDown(with: event)
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
