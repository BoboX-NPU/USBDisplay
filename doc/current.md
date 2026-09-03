# USB Display Current Project State

## Overview

USB Display is a native macOS 14+ SwiftUI application that displays the screen of a USB-connected iPhone or iPad. Version 0.3.0 is a standard Xcode macOS application with an app target, a unit-test target, a shared scheme, project-owned bundle metadata, and project-owned entitlements.

The application uses only public AVFoundation and CoreMediaIO APIs. It does not install a mobile companion app and does not send input, control commands, audio, recordings, screenshots, or captured frames to any destination.

## Current Capabilities

- Explicitly enables CoreMediaIO screen-capture-device discovery and disables wireless screen-capture discovery.
- Discovers wired Apple devices that provide external muxed screen media, including sources that macOS reports with the Other transport type.
- Publishes device discovery through one application-level catalog shared by every window.
- Uses a value-based SwiftUI `WindowGroup` keyed by the device unique ID and retains at most one window for each selected device.
- Switches the current window directly when the user left-clicks an unclaimed device.
- Provides `Open in New Window` from each device row's context menu; selecting a device that already owns a window focuses that window instead of duplicating its capture session.
- Gives each device window its own `AVCaptureSession`, connection state, retry lifecycle, sidebar state, and live preview aspect ratio.
- Releases only the closing window's capture session; another device window continues independently.
- Uses `AVCaptureVideoPreviewLayer` with `.resizeAspect` for the system-managed direct-preview path supported by wired iPhone and iPad screen sources.
- Reports the effective preview content rectangle back to the window model and updates the window aspect ratio when the source orientation changes.
- Keeps a normal window's detail area at the exact source aspect ratio, with no white inset, letterbox, stretching, or cropping.
- Preserves the current height when the device ratio changes and adjusts width, shrinking proportionally when the result would exceed the current display's visible area.
- Constrains manual window resizing to the source ratio while accounting for the current sidebar width; sidebar collapse, expansion, and width changes resize the outer window instead of squeezing the preview.
- Uses a native `NavigationSplitView` with a collapsible system sidebar containing only device names and selection state.
- Uses a separate native title bar with its system background and separator, keeps the logical window title visually hidden, and places the sidebar and display surface below it.
- Keeps the native close, minimize, and zoom buttons visible while the sidebar is expanded. When the sidebar is collapsed, the buttons appear while the pointer is inside the title bar and hide 0.5 seconds after it leaves; the system sidebar button remains visible.
- Uses aspect-fit black bars only as the explicit native full-screen exception, where the display ratio cannot be changed to match the device.
- Reports no-device, unlock-or-trust, connecting, connected, interrupted, occupied, device-unavailable, camera-permission, and general failure states within the display surface.
- Retries suspended, occupied, interrupted, and transiently failed devices with bounded delays local to that window.
- Emits structured device, session, interface, and diagnostic error logs without device identifiers or captured content.

## Architecture

- `DeviceCatalog` owns the application-level CoreMediaIO configuration and AVFoundation device discovery monitor.
- `DisplayWindowScene` owns a window's `AppModel`, routes left-click switching, and opens or focuses context-menu device windows.
- `DeviceWindowRegistry` atomically transfers device ownership between the current selection and other windows.
- `AppModel` owns one window's selected device ID, sidebar presentation and measured width, live aspect ratio, and capture coordinator.
- `CaptureCoordinator` owns one window's independent capture session, permission handling, connection state, reconnect handling, stabilized connection reporting, and bounded retries.
- `PreviewHostView` is the narrow AppKit bridge that hosts `AVCaptureVideoPreviewLayer` and measures its effective content rectangle.
- `WindowLayoutPolicy` provides testable aspect validation, sidebar-aware sizing, screen-bound fitting, manual-resize correction, and the full-screen exception.
- `WindowLayoutCoordinator` is the narrow AppKit window bridge that applies native title-bar chrome, tracks title-bar hover per window, manages the three standard window buttons, observes window and screen changes, and corrects the `NSWindow` frame without replacing SwiftUI's window ownership.
- Pure device filtering, device-window routing, ownership transfer, proportional window layout, error classification, and retry behavior are covered by Swift Testing tests.

## Public API Boundaries

The connected iPhone and iPad screen sources expose opaque public formats with `0 x 0` dimensions and no public frame-rate range. Although AVFoundation session presets are real APIs, accepting a preset does not prove that these USB sources transmit at the preset's named resolution. The app therefore provides no Auto, 1080p, or 4K controls, sets no session preset, and leaves stream negotiation to AVFoundation.

The compatible `AVCaptureVideoPreviewLayer` path exposes no public latency-control parameter or per-frame capture-to-display timing. The app provides and claims no latency adjustment. End-to-end latency requires an external measurement.

A previously tested `AVCaptureVideoDataOutput` and `AVSampleBufferDisplayLayer` path was removed because the physical iPad screen source caused CoreMediaIO to reject stream startup with the `!dev` status even with device-native output settings. The direct preview layer remains the compatible public presentation path for this source.

## Build and Run

- `USBDisplay.xcodeproj` defines the USB Display macOS app target, iPhoneUSBDisplayTests unit-test target, and shared USB Display scheme.
- `Config/Info.plist` and `Config/USBDisplay.entitlements` own the version 0.3.0 metadata, unchanged `com.xuemingbo.iPhoneUSBDisplay` bundle identifier, explicit camera-device entitlement, and USB mobile-screen permission explanation.
- `script/build_and_run.sh` is the canonical local entry point with run, debug, logs, telemetry, and verify modes. It builds into the project-local `.build/Xcode` DerivedData directory and launches `USB Display.app` directly.
- `.codex/environments/environment.toml` exposes the Xcode-backed script as the Codex Run action.

## Validation Status

- Swift format lint: Passed with no warnings.
- Xcode Debug build: Passed.
- Xcode Release build: Passed.
- Xcode unit tests: 32 tests passed across four suites.
- Debug build and process verification: Passed through `script/build_and_run.sh --verify`.
- Project file, Info.plist, and entitlements property-list lint: Passed.
- Built application signature: Passed strict ad-hoc `codesign` verification; the camera-device entitlement is present.
- Running-app title-bar check on macOS 27: Passed. The native title bar and separator are visible, the logical title remains visually hidden, and the display surface begins below the title bar.
- Running-app sidebar and hover check: Passed. The three standard window buttons remain visible with the sidebar expanded, disappear when it is collapsed, reappear when the pointer enters the title bar, and hide again after the pointer leaves. The system sidebar button remains visible throughout.
- Native full-screen round trip: Passed. The system hid its title-bar controls in full screen and restored the correct expanded-sidebar state after exit.
- Running-app context-menu check: Passed. `Open in New Window` is available and selecting it for the current device focuses the existing typed window instead of creating a duplicate.
- The connected iPhone produced a live preview during the initial title-bar check. After later rebuilds, the system capture helper remained in Connecting, so live aspect-ratio resizing, physical rotation, and updated two-device behavior were not revalidated in the final build.

## Constraints and Outstanding Validation

- Apple does not guarantee concurrent capture from two external mobile screen devices on macOS. Earlier two-device capture succeeded, but the updated left-click and context-menu interaction requires another live two-device run.
- Normal-window sizing is driven by the effective live preview rectangle. Until a valid stream ratio is available, the window keeps its current size and shows the black connection surface.
- Dynamic physical rotation, free-edge resize behavior with a live stream, sidebar-width changes with a live stream, hot unplug/replug, camera permission denial, occupied-device recovery, and a 30-minute two-window soak remain to be run.
- Native full screen cannot simultaneously match an arbitrary device ratio and the fixed display ratio; the application preserves the complete image and uses black bars in that mode.
- Title-bar hover is monitored only inside each application window and does not require a global event monitor or Accessibility permission.
- End-to-end latency and sustained frame rate were not measured. The direct-preview path does not expose the required timing data.
- The local build is ad-hoc signed because no valid development signing identity is installed. Xcode disables hardened runtime for the Debug ad-hoc build, and rebuilds may require camera permission again.
- DRM-protected content may display black; the app intentionally does not bypass platform protection.
- App Store packaging, production signing, notarization, and distribution remain outside this local MVP.
