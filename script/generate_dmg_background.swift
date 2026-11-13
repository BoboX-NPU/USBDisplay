import AppKit

// Finder supplies the real draggable app/folder icons. This artwork only draws
// the installation guidance and background at a 720-by-460-point logical size.
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Packaging/DMG")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let width: CGFloat = 720
let height: CGFloat = 460

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
  NSColor(
    srgbRed: CGFloat((hex >> 16) & 255) / 255,
    green: CGFloat((hex >> 8) & 255) / 255,
    blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func rect(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
  NSRect(x: x, y: height - top - h, width: w, height: h)
}

func text(_ value: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, ink: UInt32) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center
  let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: size, weight: weight),
    .foregroundColor: color(ink), .paragraphStyle: paragraph,
  ]
  NSAttributedString(string: value, attributes: attributes)
    .draw(in: rect(48, top, width - 96, size * 1.8))
}

for scale in [1, 2] {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width) * scale, pixelsHigh: Int(height) * scale,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  bitmap.size = NSSize(width: width, height: height)
  let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphics
  // bitmap.size establishes logical points; NSGraphicsContext supplies the
  // backing scale. Applying another scale here would crop the Retina artwork.

  NSGradient(colors: [color(0xFFFFFF), color(0xF1F6FC)])!
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

  // Quiet pools of white keep both native icons distinct from the blue-gray base.
  for center in [CGFloat(200), CGFloat(520)] {
    let ring = NSBezierPath(ovalIn: rect(center - 84, 146, 168, 168))
    color(0xFFFFFF, alpha: 0.84).setFill()
    ring.fill()
    color(0xDDE7F2).setStroke()
    ring.lineWidth = 1
    ring.stroke()
  }

  text("USB Display", top: 38, size: 32, weight: .semibold, ink: 0x213650)
  text("拖到「应用程序」完成安装", top: 89, size: 16, weight: .medium, ink: 0x435D79)
  text("Drag to Applications to install", top: 116, size: 13, weight: .regular, ink: 0x526A83)

  let arrow = NSBezierPath()
  arrow.move(to: NSPoint(x: 326, y: height - 224))
  arrow.line(to: NSPoint(x: 394, y: height - 224))
  arrow.move(to: NSPoint(x: 382, y: height - 213))
  arrow.line(to: NSPoint(x: 394, y: height - 224))
  arrow.line(to: NSPoint(x: 382, y: height - 235))
  arrow.lineWidth = 2.5
  arrow.lineCapStyle = .round
  arrow.lineJoinStyle = .round
  color(0x708CA9).setStroke()
  arrow.stroke()

  color(0xDDE6F0).setFill()
  rect(76, 349, width - 152, 1).fill()
  text("安装后，连接你的 iPhone 或 iPad", top: 371, size: 13, weight: .medium, ink: 0x435D79)
  text(
    "Then connect your iPhone or iPad with a USB cable", top: 395, size: 12,
    weight: .regular, ink: 0x526A83)
  text(
    "macOS 14+  ·  Apple Silicon & Intel", top: 426, size: 10.5,
    weight: .regular, ink: 0x526A83)

  NSGraphicsContext.restoreGraphicsState()
  let suffix = scale == 1 ? "" : "@2x"
  let data = bitmap.representation(using: .png, properties: [:])!
  try data.write(to: output.appendingPathComponent("background\(suffix).png"))
}
