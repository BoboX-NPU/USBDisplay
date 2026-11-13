import AppKit

// Finder supplies the real draggable app/folder icons. This artwork only draws
// a flat curved arrow and the requested footer on a plain white canvas.
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Packaging/DMG")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let width: CGFloat = 640
let height: CGFloat = 360

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

  NSColor.white.setFill()
  NSRect(x: 0, y: 0, width: width, height: height).fill()

  let halfSpan: CGFloat = 70
  let rise: CGFloat = 28
  let radius = (halfSpan * halfSpan + rise * rise) / (2 * rise)
  let center = NSPoint(x: 320, y: height - (158 + radius - rise))
  let endAngle = atan2(radius - rise, halfSpan)
  let arrow = NSBezierPath()
  arrow.appendArc(
    withCenter: center, radius: radius,
    startAngle: 180 - endAngle * 180 / .pi,
    endAngle: endAngle * 180 / .pi, clockwise: true)

  let tip = NSPoint(x: 390, y: height - 158)
  let direction = NSPoint(x: sin(endAngle), y: -cos(endAngle))
  let normal = NSPoint(x: -direction.y, y: direction.x)
  let back = NSPoint(x: tip.x - 10 * direction.x, y: tip.y - 10 * direction.y)
  arrow.move(to: NSPoint(x: back.x + 5 * normal.x, y: back.y + 5 * normal.y))
  arrow.line(to: tip)
  arrow.line(to: NSPoint(x: back.x - 5 * normal.x, y: back.y - 5 * normal.y))
  arrow.lineWidth = 2.5
  arrow.lineCapStyle = .round
  arrow.lineJoinStyle = .round
  color(0x737373).setStroke()
  arrow.stroke()

  text("Connect your iPhone or iPad via USB.", top: 282, size: 13, weight: .regular, ink: 0x696969)

  NSGraphicsContext.restoreGraphicsState()
  let suffix = scale == 1 ? "" : "@2x"
  let data = bitmap.representation(using: .png, properties: [:])!
  try data.write(to: output.appendingPathComponent("background\(suffix).png"))
}
