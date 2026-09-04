@preconcurrency import AVFoundation
@preconcurrency import CoreMediaIO
import Foundation
import Observation

@MainActor
@Observable
final class DeviceCatalog {
  private(set) var devices: [DisplayDevice] = []

  @ObservationIgnored private let identityService = DeviceIdentityService()
  @ObservationIgnored private var monitor: DeviceDiscoveryMonitor!

  init() {
    monitor = DeviceDiscoveryMonitor { [weak self] devices in
      guard let self else { return }
      self.identityService.refresh(devices) { [weak self] resolved in
        self?.devices = resolved
      }
    }
  }

  func start() {
    monitor.start()
  }
}

@MainActor
final class DeviceDiscoveryMonitor {
  typealias DevicesHandler = @MainActor @Sendable ([DisplayDevice]) -> Void

  private let devicesHandler: DevicesHandler
  private var discoverySession: AVCaptureDevice.DiscoverySession?
  private var discoveryObservation: NSKeyValueObservation?
  private var notificationObservers: [NSObjectProtocol] = []
  private var started = false

  init(devicesHandler: @escaping DevicesHandler) {
    self.devicesHandler = devicesHandler
  }

  func start() {
    guard !started else { return }
    started = true

    MobileScreenDeviceDiscovery.configureCoreMediaIO()
    let discoverySession = MobileScreenDeviceDiscovery.makeSession()
    self.discoverySession = discoverySession
    discoveryObservation = discoverySession.observe(\.devices, options: [.initial, .new]) {
      [weak self] _, _ in
      Task { @MainActor in
        self?.publishDevices()
      }
    }

    let center = NotificationCenter.default
    notificationObservers = [
      center.addObserver(
        forName: AVCaptureDevice.wasConnectedNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        Task { @MainActor in
          self?.publishDevices()
        }
      },
      center.addObserver(
        forName: AVCaptureDevice.wasDisconnectedNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        Task { @MainActor in
          self?.publishDevices()
        }
      },
    ]

    AppLogger.device.info("Device catalog started")
  }

  private func publishDevices() {
    guard started, let discoverySession else { return }

    let devices = MobileScreenDeviceDiscovery.eligibleDevices(in: discoverySession).map {
      DisplayDevice(
        id: $0.uniqueID,
        name: $0.localizedName,
        modelID: $0.modelID
      )
    }
    for device in devices {
      AppLogger.device.debug("Capture model: \(device.modelID, privacy: .public)")
    }
    let devicesHandler = devicesHandler

    AppLogger.device.info("Found \(devices.count) eligible wired Apple mobile device(s)")
    Task { @MainActor in
      devicesHandler(devices)
    }
  }

}

enum MobileScreenDeviceDiscovery {
  static func configureCoreMediaIO() {
    setCoreMediaIOProperty(
      kCMIOHardwarePropertyAllowScreenCaptureDevices,
      value: 1,
      description: "wired screen capture"
    )
    setCoreMediaIOProperty(
      kCMIOHardwarePropertyAllowWirelessScreenCaptureDevices,
      value: 0,
      description: "wireless screen capture"
    )
  }

  static func makeSession() -> AVCaptureDevice.DiscoverySession {
    AVCaptureDevice.DiscoverySession(
      deviceTypes: [.external],
      mediaType: .muxed,
      position: .unspecified
    )
  }

  static func eligibleDevices(
    in discoverySession: AVCaptureDevice.DiscoverySession
  ) -> [AVCaptureDevice] {
    discoverySession.devices
      .filter { CaptureDeviceFilter.isEligible(descriptor(for: $0)) }
      .sorted {
        $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending
      }
  }

  static func device(withID id: String) -> AVCaptureDevice? {
    eligibleDevices(in: makeSession()).first { $0.uniqueID == id }
  }

  private static func descriptor(for device: AVCaptureDevice) -> CaptureDeviceDescriptor {
    CaptureDeviceDescriptor(
      isExternal: device.deviceType == .external,
      hasMuxedMedia: device.hasMediaType(.muxed),
      manufacturer: device.manufacturer
    )
  }

  private static func setCoreMediaIOProperty(
    _ selector: Int,
    value: UInt32,
    description: String
  ) {
    var propertyAddress = CMIOObjectPropertyAddress(
      mSelector: CMIOObjectPropertySelector(selector),
      mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
    var mutableValue = value
    let status = CMIOObjectSetPropertyData(
      CMIOObjectID(kCMIOObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      UInt32(MemoryLayout<UInt32>.size),
      &mutableValue
    )

    if status == noErr {
      AppLogger.device.info("Configured \(description, privacy: .public) discovery")
    } else {
      AppLogger.device.error(
        "Failed to configure \(description, privacy: .public) discovery: \(status)"
      )
    }
  }
}
