# USB Display Current Project State

## Overview

USB Display is a native macOS 14+ SwiftUI application that displays the screen of a USB-connected iPhone or iPad. Version 0.2.0 is a local-development Swift Package executable staged as an ad-hoc-signed app bundle.

The application uses only public AVFoundation and CoreMediaIO APIs. It does not install a mobile companion app and does not send input, control commands, audio, recordings, screenshots, or captured frames to any destination.

## Current Capabilities

- Explicitly enables CoreMediaIO screen-capture-device discovery and disables wireless screen-capture discovery.
- Discovers external Apple devices that provide muxed screen media, including wired iPhone and iPad sources exposed by macOS.
- Accepts wired Apple mobile screen devices that macOS reports with the Other transport type instead of requiring the unreliable AVFoundation USB transport value.
- Automatically selects a sole device, preserves the last selection when multiple devices are available, and exposes all available devices in a native sidebar.
- Switches one active capture session between sidebar selections and invalidates frames from the previous device generation.
- Uses AVCaptureVideoPreviewLayer for the public system-managed direct-preview path supported by wired iPhone and iPad screen sources.
- Preserves the source aspect ratio with black letterboxing and performs no encoding, recording, frame copying, or SwiftUI image conversion.
- Reports no-device, unlock-or-trust, connecting, connected, interrupted, occupied, device-unavailable, camera-permission, and general failure states.
- Retries suspended, occupied, interrupted, and transiently failed devices with bounded delays.
- Uses a native NavigationSplitView, system sidebar list, unified toolbar, and a black media detail canvas.
- Uses native Liquid Glass for custom full-screen controls on macOS 26+ and regular material fallback on macOS 14–15.
- Supports window resizing, native full screen, double-click full-screen toggling, automatic sidebar collapse and restoration, and full-screen-only pointer hiding.
- Emits structured device, session, interface, and diagnostic error logs without device identifiers or captured content.

## Architecture

- AppModel owns main-actor UI state, selection presentation, split-view visibility, full-screen restoration, inactivity behavior, and access to the capture session.
- CaptureCoordinator owns discovery, permissions, one AVCaptureSession, device switching, reconnect handling, stabilized connection reporting, and bounded retries.
- PreviewHostView is the narrow AppKit bridge that hosts AVCaptureVideoPreviewLayer, tracks pointer activity, balances cursor visibility, and observes native full-screen transitions.
- SidebarView and DisplayCanvasView provide the native device list and media surface without duplicating capture state.
- Pure selection, device filtering, error classification, retry, sidebar-restoration, and auto-hide policies are covered by Swift Testing tests.

AVCaptureSession.Preset.inputPriority is unavailable on macOS. The capture session therefore retains the highest supported high preset. A tested AVCaptureVideoDataOutput and AVSampleBufferDisplayLayer path was removed because the physical iPad screen source caused CoreMediaIO to reject stream startup with the !dev status even when using device-native output settings. The direct preview layer remains the compatible public zero-copy presentation path for this source.

## Build and Run

- Package.swift defines the macOS 14 executable and test targets.
- script/build_and_run.sh is the canonical local entry point with run, debug, logs, telemetry, and verify modes.
- The script builds the executable, stages the stable dist/iPhoneUSBDisplay.app path, removes the temporary renamed bundle path, writes the version 0.2.0 permission-aware Info.plist with the USB Display name, ad-hoc signs the bundle, and launches it as a foreground application.
- .codex/environments/environment.toml exposes the script as the Codex Run action.

## Validation Status

- Swift format lint: Passed with no warnings.
- Swift Testing: 16 tests passed across three suites.
- Debug build and process verification: Passed through script/build_and_run.sh --verify.
- Release build: Passed.
- Generated Info.plist: Passed plutil lint and contains the unchanged bundle identifier, macOS 14 minimum, version 0.2.0, display name, and generalized camera usage description.
- Ad-hoc signature: Passed strict codesign verification.
- Generated app identity: The bundle identifier and bundle path remain stable while the visible name is USB Display.
- Generated bundle cleanup: Passed; only dist/iPhoneUSBDisplay.app remains.
- Physical iPhone and iPad screen-source discovery: Previously confirmed independently through AVFoundation.

## Constraints and Outstanding Validation

- The connected iPad was discovered and named correctly, but its current iOSScreenCaptureAssistant instance rejected stream startup as an invalid device state with AVFoundation error -11800 and underlying CoreMediaIO status !dev. Unlocking the iPad, closing other capture applications, and reconnecting the USB cable remain required before live preview can be revalidated.
- Ad-hoc signature hashes change after rebuilds, so local development builds may require camera permission again even when the bundle identifier and path remain stable.
- Two simultaneously discoverable physical devices were not available, so multiple-device switching is covered by policy and generation tests but not yet by a two-device hardware check.
- Camera permission denial, portrait-to-landscape changes, hot unplug/replug, occupied-device recovery, and connected-state control hiding require hardware validation.
- The macOS 14–15 material fallback compiled but was not runtime-checked on those operating systems.
- The 30-minute soak, 240 fps end-to-end latency comparison, and sustained frame-rate measurement were not run.
- The public direct-preview path does not expose per-frame capture-to-display timing; end-to-end latency requires external measurement.
- DRM-protected content may display black; the app intentionally does not bypass platform protection.
- App Store packaging, production signing, notarization, and distribution remain outside this local MVP.
