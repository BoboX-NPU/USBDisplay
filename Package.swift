// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "iPhoneUSBDisplay",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(
      name: "iPhoneUSBDisplay",
      targets: ["iPhoneUSBDisplay"]
    )
  ],
  targets: [
    .executableTarget(
      name: "iPhoneUSBDisplay"
    ),
    .testTarget(
      name: "iPhoneUSBDisplayTests",
      dependencies: ["iPhoneUSBDisplay"]
    ),
  ]
)
