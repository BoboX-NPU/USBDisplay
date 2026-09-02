import OSLog

enum AppLogger {
  static let subsystem = "com.xuemingbo.iPhoneUSBDisplay"

  static let device = Logger(subsystem: subsystem, category: "Device")
  static let session = Logger(subsystem: subsystem, category: "Session")
  static let interface = Logger(subsystem: subsystem, category: "Interface")
}
