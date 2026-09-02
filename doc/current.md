# iPhoneUSBDisplay Current Project State

## Overview

iPhoneUSBDisplay is a native macOS 14+ SwiftUI application that displays the screen of a USB-connected iPhone. The current implementation is a local-development MVP built as a Swift Package executable and staged as an ad-hoc-signed `.app` bundle.

The application uses only public AVFoundation and CoreMediaIO APIs. It does not install an iOS companion app and does not send input, control commands, audio, recordings, screenshots, or captured frames to any destination.

## Current Capabilities

- Explicitly enables CoreMediaIO screen-capture-device discovery and disables wireless screen-capture discovery.
- Discovers external Apple devices that provide muxed media over USB.
- Automatically selects a sole iPhone and preserves the last user selection when multiple eligible devices are present.
- Displays the selected device through `AVCaptureVideoPreviewLayer` with aspect-fit scaling and a black background.
- Keeps capture-session configuration and blocking start/stop operations off the main thread.
- Reports no-device, unlock-or-trust, connecting, connected, interrupted, occupied, camera-permission, and general failure states.
- Retries suspended, occupied, interrupted, and transiently failed devices with bounded delays.
- Supports a resizable window, native full screen, a full-screen button, and double-click full-screen toggling.
- Hides connected-state controls after three seconds of inactivity and hides the pointer only in full screen.
- Emits structured device, session, and interface logs without device identifiers or captured content.

## Architecture

- `AppModel` owns main-actor UI state and inactivity behavior.
- `CaptureCoordinator` owns discovery, selection, permissions, `AVCaptureSession`, reconnection, and error handling on a serial queue.
- `PreviewHostView` is the narrow AppKit bridge that hosts `AVCaptureVideoPreviewLayer`, tracks pointer activity, balances cursor visibility, and observes native full-screen transitions.
- Pure selection, device-filtering, error-classification, retry, absence-state, and auto-hide policies are covered by Swift Testing tests.

`AVCaptureVideoPreviewLayer.isPreviewing` is unavailable on macOS, so connected readiness is based on the key-value-observable `AVCaptureSession.isRunning` state and the blocking result of `startRunning()`.

## Build and Run

- `Package.swift` defines the macOS 14 executable and test targets.
- `script/build_and_run.sh` is the canonical local entry point. It supports `run`, `--debug`, `--logs`, `--telemetry`, and `--verify`.
- The script builds the executable, stages `dist/iPhoneUSBDisplay.app`, writes the permission-aware `Info.plist`, ad-hoc signs the bundle, and launches it as a foreground application.
- `.codex/environments/environment.toml` exposes the script as the Codex Run action.

## Validation Status

- Swift format lint: Passed with no warnings.
- Swift Testing: 14 tests passed across three suites.
- Debug build: Passed.
- Release build: Passed.
- Generated `Info.plist`: Passed `plutil -lint` and contains the macOS 14 minimum version, bundle identity, version, and camera usage description.
- Ad-hoc signature: Passed strict `codesign` verification.
- App launch: `script/build_and_run.sh --verify` completed successfully and confirmed the process.
- Visual no-device UI: Verified in the running app, including the black canvas, required connection guidance, device/status controls, and window presentation.
- Full screen: Verified entry and exit through the custom button and entry through a double-click on the preview surface; the full-screen background is black.

## Constraints and Outstanding Validation

- A discoverable USB-connected iPhone was not available during implementation, so live capture, device naming, camera permission prompting, portrait/landscape changes, hot unplug/replug, occupied-device recovery, and connected-state control hiding are not yet hardware-validated.
- Two iPhones were not available, so the multiple-device picker is covered by policy tests but not hardware-validated.
- The 30-minute soak, frame-rate measurement, and 240 fps latency measurement were not run.
- DRM-protected content may display black; the app intentionally does not attempt to bypass platform content protection.
- The bundle is for local development only. App Store packaging, production signing, notarization, and distribution are not implemented.
