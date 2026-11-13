# Roadmap and issue tracking

Version 1.0.0 establishes the first public baseline. The maintainer will choose the scope and timing of subsequent releases; the items below are a backlog, not promises or scheduled milestones.

## Public contributions and maintainer planning

Use [GitHub Issues](https://github.com/BoboX-NPU/USBDisplay/issues) for public feedback. Maintainer tasks live in the [USB Display Linear project](https://linear.app/question-king/project/usb-display-954f744f1c76), which requires workspace access. Public contributors do not need a Linear account. The table below keeps the planning topics readable without internal access.

Link a GitHub issue and its corresponding Linear task when they refer to the same work. Record the public resolution in the GitHub issue/PR and the shipped behavior in the changelog. No automatic GitHub/Linear synchronization is configured.

## Current backlog

| Maintainer task | Topic | Kind |
| --- | --- | --- |
| [QUE-20](https://linear.app/question-king/issue/QUE-20/investigate-slow-capture-startup-and-intermittent-black-previews) | Investigate slow capture startup and intermittent black previews | Observed issue |
| [QUE-21](https://linear.app/question-king/issue/QUE-21/add-a-clear-permission-recovery-action-after-camera-access-changes) | Add a clear permission-recovery action after camera access changes | Proposed feature |
| [QUE-22](https://linear.app/question-king/issue/QUE-22/ship-developer-id-signed-and-notarized-github-downloads) | Ship Developer ID signed and notarized GitHub downloads | Distribution |
| [QUE-23](https://linear.app/question-king/issue/QUE-23/validate-the-release-on-macos-1415-and-intel-hardware) | Validate the release on macOS 14/15 and Intel hardware | Validation |
| [QUE-24](https://linear.app/question-king/issue/QUE-24/verify-continuous-resizing-sidebar-dragging-and-hover-transitions) | Verify continuous resizing, sidebar dragging, and hover transitions | Validation |
| [QUE-25](https://linear.app/question-king/issue/QUE-25/exercise-rotation-reconnects-multiple-devices-and-display-removal) | Exercise rotation, reconnects, multiple devices, and display removal | Validation |
| [QUE-26](https://linear.app/question-king/issue/QUE-26/measure-capture-latency-frame-pacing-cpu-memory-and-energy) | Measure capture latency, frame pacing, CPU, memory, and energy | Validation |
| [QUE-27](https://linear.app/question-king/issue/QUE-27/run-a-multi-window-soak-and-real-interruption-recovery-tests) | Run a multi-window soak and real interruption-recovery tests | Validation |
| [QUE-28](https://linear.app/question-king/issue/QUE-28/check-accessibility-reduce-motion-and-keyboard-operation) | Check accessibility, Reduce Motion, and keyboard operation | Validation |
| [QUE-29](https://linear.app/question-king/issue/QUE-29/review-new-device-profiles-and-the-six-excluded-identifiers) | Review new device profiles and the six excluded identifiers | Engineering follow-up |
| [QUE-30](https://linear.app/question-king/issue/QUE-30/evaluate-event-driven-source-geometry-updates) | Evaluate event-driven source geometry updates | Engineering follow-up |
| [QUE-31](https://linear.app/question-king/issue/QUE-31/automate-native-ci-and-reproducible-release-verification) | Automate native CI and reproducible release verification | Engineering follow-up |

The observed startup/black-preview issue needs diagnosis; the hardware and interaction rows describe incomplete verification, not confirmed defects. The permission-recovery feature and event-driven geometry exploration are proposals whose final design is not settled.

The September audit's F1–F9 and the subsequent toolbar/divider fixes are already implemented. Their evidence remains in the [audit report](code-audit-2026-09-05.md) and [development log](devlog.md); they are not reopened as outstanding bugs.

## Release policy

- Keep the default branch usable and use focused pull requests for future work.
- Use patch releases for compatible fixes, minor releases for compatible features, and major releases for breaking changes.
- Publish source tags, readable release notes, download assets, and checksums together.
- Preserve old tags and downloads. Correct a shipped package with a new version rather than silently replacing it.
- Record signing/notarization and physical validation honestly for each release. Follow the [release procedure](releases.md).
