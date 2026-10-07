#!/usr/bin/env swift
import AppKit
import Foundation

// Run from the repository root:
// swift -module-cache-path .build/IconModuleCache script/generate_app_icon.swift
let root = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("doc/design/usb-display-icon-ipad-iphone-v8.svg")
let catalog = root.appendingPathComponent("USBDisplay/Resources/Assets.xcassets")
let destination = catalog.appendingPathComponent("AppIcon.appiconset")

guard let image = NSImage(contentsOf: source), image.isValid else {
  fatalError("Cannot load the app icon SVG: \(source.path)")
}
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

struct IconImage: Encodable {
  let filename: String
  let idiom = "mac"
  let scale: String
  let size: String
}

struct AssetInfo: Encodable {
  let author = "xcode"
  let version = 1
}

struct IconContents: Encodable {
  let images: [IconImage]
  let info = AssetInfo()
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
var images: [IconImage] = []
for points in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = points * scale
    let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    guard
      let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
        bytesPerRow: pixels * 4, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      fatalError("Cannot create a \(pixels)-pixel icon context")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    image.draw(
      in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
      from: .zero, operation: .copy, fraction: 1,
      respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let rendered = context.makeImage(),
      let png = NSBitmapImageRep(cgImage: rendered).representation(using: .png, properties: [:])
    else {
      fatalError("Cannot encode \(filename)")
    }
    try png.write(to: destination.appendingPathComponent(filename), options: .atomic)
    images.append(IconImage(filename: filename, scale: "\(scale)x", size: "\(points)x\(points)"))
  }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(IconContents(images: images))
  .write(to: destination.appendingPathComponent("Contents.json"), options: .atomic)
try encoder.encode(["info": AssetInfo()])
  .write(to: catalog.appendingPathComponent("Contents.json"), options: .atomic)
print("Generated \(images.count) macOS AppIcon variants from \(source.lastPathComponent)")
