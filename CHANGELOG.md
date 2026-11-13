# Changelog

Public releases follow `MAJOR.MINOR.PATCH` versioning. Development builds before 1.0.0 were not published GitHub releases.

## Unreleased

No changes scheduled yet. See the [roadmap](doc/roadmap.md) for unscheduled follow-up work.

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
