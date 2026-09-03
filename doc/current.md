# USB Display Current Project State

## Overview

USB Display is a native macOS 14+ SwiftUI application that displays the screen of a USB-connected iPhone or iPad. Version 0.3.0 is a standard Xcode macOS application with an app target, a unit-test target, a shared scheme, project-owned bundle metadata, and project-owned entitlements.

The application uses only public AVFoundation and CoreMediaIO APIs. It does not install a mobile companion app and does not send input, control commands, audio, recordings, screenshots, or captured frames to any destination.

## Current Capabilities

- Explicitly enables CoreMediaIO screen-capture-device discovery and disables wireless screen-capture discovery.
- Discovers external Apple devices that provide muxed screen media, including wired iPhone and iPad sources exposed by macOS.
- Accepts wired Apple mobile screen devices that macOS reports with the Other transport type instead of requiring the unreliable AVFoundation USB transport value.
- Automatically selects a sole device, preserves the last selection when multiple devices are available, and exposes all available devices in a native sidebar.
- Switches one active capture session between sidebar selections and invalidates frames from the previous device generation.
- Uses AVCaptureVideoPreviewLayer for the public system-managed direct-preview path supported by wired iPhone and iPad screen sources.
- Preserves the source aspect ratio with black letterboxing and performs no encoding, recording, frame copying, or SwiftUI image conversion.
- Offers persistent Auto, 1080p, and 4K (Experimental) capture-quality choices in the window toolbar and full-screen controls.
- Applies the first supported session preset for the selected quality: High for Auto, 1920 x 1080 then High for 1080p, and 3840 x 2160 then 1920 x 1080 then High for 4K.
- Logs the requested quality, applied session preset, and any format dimensions and frame-rate range that the external source publicly exposes.
- Reports no-device, unlock-or-trust, connecting, connected, interrupted, occupied, device-unavailable, camera-permission, and general failure states.
- Retries suspended, occupied, interrupted, and transiently failed devices with bounded delays.
- Uses a native NavigationSplitView, system sidebar list, unified toolbar, and a black media detail canvas.
- Uses native Liquid Glass for custom full-screen controls on macOS 26+ and regular material fallback on macOS 14–15.
- Supports window resizing, native full screen, double-click full-screen toggling, automatic sidebar collapse and restoration, and full-screen-only pointer hiding.
- Emits structured device, session, interface, and diagnostic error logs without device identifiers or captured content.

## Architecture

- AppModel owns main-actor UI state, selection presentation, split-view visibility, full-screen restoration, inactivity behavior, and access to the capture session.
- CaptureCoordinator owns discovery, permissions, one AVCaptureSession, device switching, capture-quality application, reconnect handling, stabilized connection reporting, and bounded retries.
- PreviewHostView is the narrow AppKit bridge that hosts AVCaptureVideoPreviewLayer, tracks pointer activity, balances cursor visibility, and observes native full-screen transitions.
- SidebarView and DisplayCanvasView provide the native device list and media surface without duplicating capture state.
- Pure selection, device filtering, quality fallback, error classification, retry, sidebar-restoration, and auto-hide policies are covered by Swift Testing tests in the Xcode unit-test target.

AVCaptureSession.Preset.inputPriority is unavailable on macOS. The connected iPhone and iPad currently expose one opaque public format with 0 x 0 dimensions and no public frame-rate range, so the app cannot safely select a concrete AVCaptureDevice activeFormat. It instead requests standard session presets and lets the system negotiate the underlying mobile screen stream. A tested AVCaptureVideoDataOutput and AVSampleBufferDisplayLayer path was removed because the physical iPad screen source caused CoreMediaIO to reject stream startup with the !dev status even when using device-native output settings. The direct preview layer remains the compatible public zero-copy presentation path for this source.

## Build and Run

- USBDisplay.xcodeproj defines the USB Display macOS app target, iPhoneUSBDisplayTests unit-test target, and shared USB Display scheme.
- Config/Info.plist and Config/USBDisplay.entitlements own the version 0.3.0 metadata, unchanged com.xuemingbo.iPhoneUSBDisplay bundle identifier, explicit camera-device entitlement, and a permission explanation that distinguishes the USB mobile screen source from the Mac camera.
- script/build_and_run.sh is the canonical local entry point with run, debug, logs, telemetry, and verify modes. It builds the Xcode scheme into the project-local .build/Xcode DerivedData directory and launches the standard USB Display.app product directly.
- .codex/environments/environment.toml exposes the Xcode-backed script as the Codex Run action.
- Package.swift, the generated .swiftpm workspace, and the manually staged dist application were removed after the Xcode migration.

## Validation Status

- Swift format lint: Passed with no warnings.
- Xcode Debug build: Passed.
- Xcode Release build: Passed.
- Xcode unit tests: 19 tests passed across four suites.
- Debug build and process verification: Passed through script/build_and_run.sh --verify.
- Info.plist: Passed plutil lint and contains the unchanged bundle identifier, macOS 14 minimum, version 0.3.0, USB Display executable and display names, high-resolution capability, and the USB screen-specific camera usage explanation.
- Entitlements and ad-hoc signature: Passed strict codesign verification; the built application contains the camera-device entitlement.
- Running-app hardware check on macOS 27: Passed for simultaneous iPhone and iPad discovery, live iPad preview, live iPhone preview, and sidebar switching in both directions without stale content or connection failure.
- Capture-quality hardware check on the connected iPad: Auto applied AVCaptureSessionPresetHigh, 1080p applied AVCaptureSessionPreset1920x1080, and 4K applied AVCaptureSessionPreset3840x2160. Every setting started and remained connected. No obvious visual sharpness difference was observed at the tested window size.
- Native Liquid Glass running-app check on macOS 27: Passed for the system sidebar, toolbar, status surface, quality menu, and full-screen controls.

## Constraints and Outstanding Validation

- The earlier iOSScreenCaptureAssistant invalid-state failure did not recur in the Xcode-built application; both connected devices currently start successfully. A future macOS helper failure may still require closing capture applications, reconnecting USB, or restarting macOS.
- The connected mobile screen sources continue to report public format dimensions and frame-rate data as 0, so successful acceptance of a 1080p or 4K session preset is not proof that the USB source sends that native resolution. The system helper also emitted no usable stream-dimension telemetry during the comparison.
- Auto, 1080p, and 4K looked substantially similar at the tested display size. A controlled resolution chart and pixel-level external capture remain required before claiming a resolution improvement.
- End-to-end visual latency was not measured. The approximately 0.25-second connected-state stabilization gate is application status handling and must not be reported as capture latency.
- The local build is ad-hoc signed because no valid development signing identity is installed. Xcode disables hardened runtime for the Debug ad-hoc build, and rebuilds may require camera permission again.
- Camera permission denial, portrait-to-landscape changes, hot unplug/replug, occupied-device recovery, and connected-state control hiding require hardware validation.
- The macOS 14–15 material fallback compiled but was not runtime-checked on those operating systems.
- The 30-minute soak, 240 fps end-to-end latency comparison, and sustained frame-rate measurement were not run.
- The public direct-preview path does not expose per-frame capture-to-display timing; end-to-end latency requires external measurement.
- DRM-protected content may display black; the app intentionally does not bypass platform protection.
- App Store packaging, production signing, notarization, and distribution remain outside this local MVP.
