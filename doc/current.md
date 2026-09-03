# USB Display Current Project State

## Overview

USB Display is a native macOS 14+ SwiftUI application that displays the screen of a USB-connected iPhone or iPad. Version 0.3.0 is a standard Xcode macOS application with an app target, a unit-test target, a shared scheme, project-owned bundle metadata, and project-owned entitlements.

The application uses only public AVFoundation and CoreMediaIO APIs. It does not install a mobile companion app and does not send input, control commands, audio, recordings, screenshots, or captured frames to any destination.

## Current Capabilities

- Explicitly enables CoreMediaIO screen-capture-device discovery and disables wireless screen-capture discovery.
- Discovers wired Apple devices that provide external muxed screen media, including sources that macOS reports with the Other transport type.
- Publishes device discovery through one application-level catalog shared by every window.
- Uses a value-based SwiftUI `WindowGroup` keyed by the device unique ID, with at most one window for each selected device.
- Assigns the first selected device to an unassigned window and opens or focuses the existing device-specific window when another device is selected.
- Gives each device window its own `AVCaptureSession`, connection state, retry lifecycle, sidebar state, and live preview aspect ratio.
- Releases only the closing window's capture session; another device window continues independently.
- Uses `AVCaptureVideoPreviewLayer` with `.resizeAspect` for the system-managed direct-preview path supported by wired iPhone and iPad screen sources.
- Reports the effective preview content rectangle back to the window model and updates the display aspect ratio when the source orientation changes.
- Fits the preview proportionally inside the detail area, preserves a 16-point system-background inset, clips it to its viewport, and keeps black inside the media viewport only.
- Uses one native `NavigationSplitView` page with a collapsible system sidebar that contains only device names and selection state.
- Keeps the sidebar below the title bar and separate from the display area in windowed and full-screen layouts.
- Shows only the standard window controls and system sidebar toggle. Device names remain logical window titles for accessibility and the Window menu but are not drawn in the title bar.
- Supports window resizing, native full screen, and double-click full-screen toggling without custom control overlays or pointer hiding.
- Reports no-device, unlock-or-trust, connecting, connected, interrupted, occupied, device-unavailable, camera-permission, and general failure states within the display viewport.
- Retries suspended, occupied, interrupted, and transiently failed devices with bounded delays local to that window.
- Emits structured device, session, interface, and diagnostic error logs without device identifiers or captured content.

## Architecture

- `DeviceCatalog` owns the application-level CoreMediaIO configuration and AVFoundation device discovery monitor.
- `DisplayWindowScene` binds a typed `WindowGroup` value to one window, applies device-window routing, and owns that window's `AppModel`.
- `DeviceWindowRegistry` prevents an unassigned window from claiming a device that already has a window.
- `AppModel` owns one window's selected device ID, presentation state, live aspect ratio, and capture coordinator.
- `CaptureCoordinator` owns one window's independent capture session, permission handling, connection state, reconnect handling, stabilized connection reporting, and bounded retries.
- `PreviewHostView` is the narrow AppKit bridge that hosts `AVCaptureVideoPreviewLayer` and measures its effective content rectangle.
- `PreviewLayoutPolicy` validates source ratios and calculates the largest proportional preview that fits inside the inset display area.
- Pure device filtering, window routing, window ownership, preview layout, error classification, and retry behavior are covered by Swift Testing tests in the Xcode unit-test target.

## Public API Boundaries

The connected iPhone and iPad screen sources expose opaque public formats with `0 x 0` dimensions and no public frame-rate range. Although AVFoundation session presets are real APIs, accepting a preset does not prove that these USB sources transmit at the preset's named resolution. The app therefore provides no Auto, 1080p, or 4K controls, sets no session preset, and leaves stream negotiation to AVFoundation.

The compatible `AVCaptureVideoPreviewLayer` path exposes no public latency-control parameter or per-frame capture-to-display timing. The app provides and claims no latency adjustment. End-to-end latency requires an external measurement.

A previously tested `AVCaptureVideoDataOutput` and `AVSampleBufferDisplayLayer` path was removed because the physical iPad screen source caused CoreMediaIO to reject stream startup with the `!dev` status even with device-native output settings. The direct preview layer remains the compatible public presentation path for this source.

## Build and Run

- `USBDisplay.xcodeproj` defines the USB Display macOS app target, iPhoneUSBDisplayTests unit-test target, and shared USB Display scheme.
- `Config/Info.plist` and `Config/USBDisplay.entitlements` own the version 0.3.0 metadata, unchanged `com.xuemingbo.iPhoneUSBDisplay` bundle identifier, explicit camera-device entitlement, and USB mobile-screen permission explanation.
- `script/build_and_run.sh` is the canonical local entry point with run, debug, logs, telemetry, and verify modes. It builds the Xcode scheme into the project-local `.build/Xcode` DerivedData directory and launches the standard `USB Display.app` product directly.
- `.codex/environments/environment.toml` exposes the Xcode-backed script as the Codex Run action.

## Validation Status

- Swift format lint: Passed with no warnings.
- Xcode Debug build: Passed.
- Xcode Release build: Passed.
- Xcode unit tests: 15 tests passed across four suites.
- Debug build and process verification: Passed through `script/build_and_run.sh --verify`.
- Project file, Info.plist, and entitlements property-list lint: Passed.
- Built application signature: Passed strict ad-hoc `codesign` verification; the camera-device entitlement is present.
- Running-app check on macOS 27: Passed with a connected iPad and iPhone. Both devices produced live previews in separate windows, and selecting either device focused its existing window instead of creating a duplicate.
- Independent lifecycle check: Passed; closing one device window stopped that coordinator without terminating the surviving device window or application.
- Layout check: Passed for the landscape iPad and portrait iPhone previews, 16-point display-area inset, system-background whitespace, hidden visual title, single system sidebar button, and sidebar containment.
- Sidebar and full-screen check: Passed; collapsing the sidebar expanded only the detail area, and native full screen displayed no connection label, quality controls, or custom overlay.

## Constraints and Outstanding Validation

- Apple does not guarantee concurrent capture from two external mobile screen devices on macOS. The current two-device hardware check succeeded, but longer concurrent runs and other device or macOS combinations remain unverified.
- Dynamic rotation was not performed during the latest running-app check. Portrait and landscape sources both fitted correctly, and aspect-ratio updates are unit-tested, but an in-place physical rotation still requires validation.
- Hot unplug/replug, camera permission denial, occupied-device recovery, and a 30-minute two-window soak were not run for this change.
- End-to-end latency and sustained frame rate were not measured. The direct-preview path does not expose the required timing data.
- The local build is ad-hoc signed because no valid development signing identity is installed. Xcode disables hardened runtime for the Debug ad-hoc build, and rebuilds may require camera permission again.
- DRM-protected content may display black; the app intentionally does not bypass platform protection.
- App Store packaging, production signing, notarization, and distribution remain outside this local MVP.
