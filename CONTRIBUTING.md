# Contributing to USB Display

Use [GitHub Issues](https://github.com/BoboX-NPU/USBDisplay/issues) for public bugs and proposals. Search existing issues first. For a larger feature, discuss the use case and compatibility constraints before implementation. Follow the repository's [collaboration guidelines](AGENTS.md).

## Development environment

- A Mac with the full Xcode installation selected through `xcode-select`.
- Xcode 27.2 is the verified toolchain for the current layered icon and source.
- Python 3.10 or later for offline catalog tooling; no third-party Python dependencies are required.
- A physical iPhone/iPad and USB data cable for capture acceptance. Most unit tests do not require a connected device.

Open `USBDisplay.xcodeproj` and use the shared `USB Display` scheme, or run:

```bash
./script/build_and_run.sh --verify
./script/test.sh
```

The build/run script relaunches the app. To narrow tests:

```bash
./script/test.sh -only-testing:iPhoneUSBDisplayTests/WindowRenderingTests
```

Run relevant data and formatting checks:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 script/test_device_profiles.py
PYTHONDONTWRITEBYTECODE=1 python3 script/update_device_profiles.py --check
xcrun swift-format lint --strict --recursive USBDisplay USBDisplayTests
git diff --check
```

No hosted CI result is currently implied by these commands. Native CI and release automation are tracked on the [roadmap](doc/roadmap.md).

## Change workflow

1. Read `doc/current.md` and relevant entries in `doc/devlog.md`.
2. Create a focused branch from `main` (`codex/` is used for Codex changes).
3. Keep one behavior or closely related change per pull request. Preserve the capture/window ownership boundaries described in current state.
4. Run checks appropriate to the change. For capture, resizing, full screen, or permissions, record physical checks separately from automated tests and identify unavailable hardware.
5. Update user-facing documentation when behavior changes. Append a factual `doc/devlog.md` entry and update `doc/current.md` if the current state changes. Add user-facing changes under `Unreleased` in `CHANGELOG.md`.
6. Write English Markdown and commit messages. Inspect the staged diff and whitespace before committing.
7. Open a pull request describing the problem, final behavior, validation, and limitations. Link the relevant public GitHub issue; maintainers can cross-link their internal Linear task.

Keep `main` releasable. Use `vMAJOR.MINOR.PATCH` tags for published source, and never replace assets under an already published version; publish a new patch version for corrected downloads. The maintainer sets the scope and timing of each next release.

## Temporary files and evidence

`script/test.sh` deletes its build cache and detailed `.xcresult` bundle on success, failure, and normal interruption. Every invocation rebuilds. Redirect console output explicitly if you need a text log. A forced kill, shell crash, or power loss can leave a temporary directory; confirm it is inactive before removing it.

Preserve `.build/Xcode` and `.build/Distribution`. Other one-off validation builds belong in unique temporary directories and must be cleaned up in the same task. Keep durable conclusions in documentation instead of committing binaries, caches, or raw recordings.

## Scope and privacy

Preserve local video display, no companion-app requirement, and the macOS 14 deployment baseline unless a separately discussed change updates the contract. Do not substitute an iOS-only API for a macOS API without checking actual availability.

Device names and on-screen content may be personal. Redact reports and diagnostics before posting. Do not upload signing keys, access tokens, full device identifiers, or unrelated logs. Report sensitive security concerns privately to [the maintainer](https://github.com/BoboX-NPU) rather than including exploit-sensitive or personal details in a public issue.

## License

Contributions are made under the project's [MIT License](LICENSE). Preserve existing copyright and third-party notices, and document the provenance of new code or data.
