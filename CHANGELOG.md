# Changelog

Public releases follow `MAJOR.MINOR.PATCH` versioning. Development builds before 1.0.0 were not published GitHub releases.

## Unreleased

No additional changes scheduled. See the [roadmap](doc/roadmap.md) for follow-up work.

## 1.1.0 — 2026-11-14

### New Features

- Integrate Sparkle 2.10.1 with automatic update checks, in-app download progress, and an explicit Install and Relaunch action. Normal quit cancels an unconfirmed update.
- Add Check for Updates and an automatic-check toggle to the application menu.
- Add signed update-feed preparation for notarized universal GitHub release ZIPs.

### Bug Fixes

- Keep Sparkle licensing in a separate bundled resource so device-catalog regeneration preserves the updater license and remains reproducible.

Version 1.1.0 (build 8) is Developer ID signed and notarized. Users of 1.0.3 and earlier must install 1.1.0 manually once to adopt in-app updates.

## 1.0.3 — 2026-11-13

### Improvements

- Use the approved minimal installer: a pure-white canvas, one flat circular-arc arrow, and the English footer "Connect your iPhone or iPad via USB."
- Use a compact layout with clear spacing around the native app and Applications icons.
- Update both README language sections to the new downloads while preserving existing releases.

The app remains Developer ID signed and notarized. Capture/window behavior is unchanged; existing runtime validation and intermittent full-screen test follow-ups remain open.

## 1.0.2 — 2026-11-13

### Improvements

- Add a branded Retina installer background with matching Chinese/English drag-to-install instructions, aligned app/Applications icons, and a clear directional arrow.
- Save the Finder icon view and initial window layout. Keep only the two installation targets visible and preserve the user's global Finder preferences.
- Make the installer artwork and layout reproducible through a native asset generator and pinned release-only tools, cleaned up after packaging.
- Preserve Developer ID signing, Apple notarization, and the app's stapled ticket throughout packaging.

Application capture/window behavior is unchanged. Finder can retain its own tab, path, or status bars; the layout accommodates them. Previously published downloads remain unchanged.

## 1.0.1 — 2026-11-13

### Bug fixes

- Replace the initial release's ad-hoc distribution signature with Developer ID signing and Apple notarization. Both downloads contain the stapled app, which passes Gatekeeper checks.

### Improvements

- Provide matching Simplified Chinese and English README sections with language navigation and updated installation guidance.
- Add a packaging mode that accepts an already notarized app and verifies Developer ID identity, the stapled ticket, and Gatekeeper acceptance before and after packaging.
- Document the Xcode account-based archive, notarization, export, and validation workflow without storing credentials in the repository.

Application capture/window behavior is unchanged. Normal first-launch confirmation and Camera permission prompts still apply. Version 1.0.0 tags and downloads remain available without replacement.

## 1.0.0 — 2026-11-13

First public source and binary release.

### Features

- Wired iPhone/iPad video display through AVFoundation and CoreMediaIO, with no companion app or account.
- Independent device windows, proportional resizing, a resizable sidebar, compact hover controls, and native full-screen behavior.
- Connection/recovery status and conservative model identification with 164 bundled device-reference profiles.
- Native layered application icon and universal Apple Silicon/Intel packages targeting macOS 14+.

### Open-source project

- MIT license, installation and contribution guides, public issue/PR templates, release procedure, and a maintainer backlog in Linear.
- Disposable application-test builds and documented local catalog checks.

### Known limits

- Downloads are ad-hoc signed and not notarized; first launch can be blocked by macOS.
- Startup delays and black-preview reports need further investigation; protected content may also appear black.
- Physical compatibility, continuous interaction, multi-device soak, and performance coverage remain incomplete. The model catalog is metadata coverage, not hardware certification.
- No recording, audio capture, remote transmission, device control, or built-in update mechanism.

See the [release notes](doc/releases/v1.0.0.md) and [current verification limits](doc/current.md#constraints-and-outstanding-validation).
