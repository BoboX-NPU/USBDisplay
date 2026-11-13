# Release procedure

GitHub Releases owns public downloads. Source control owns documentation and reproducible build inputs. Linear owns maintainer planning; it is not required for public contributions.

## Prepare a release

1. Select the release scope and close/link the relevant issues. Do not implement unrelated backlog items during release preparation.
2. Start from a clean, reviewed branch. Set `MARKETING_VERSION` to the release version in both app configurations and increment `CURRENT_PROJECT_VERSION`. Preserve the bundle identifier.
3. Move completed user-facing changes from `Unreleased` into a dated changelog entry. Write `doc/releases/vVERSION.md`, including installation, signing status, known limits, and validation.
4. Run `./script/test.sh`, the catalog tests/check, shell/plist/project validation, and checks specific to the changes. Record physical acceptance separately. Temporary test directories must be removed when the run ends.
5. Follow the [Developer ID and notarization workflow](notarization.md) to archive, sign, submit, and export the stapled app. Package that exact export with `./script/package_local_release.sh --notarized-app "/absolute/path/to/USB Display.app"`. The script verifies trust and both architectures, then writes a unique directory under `.build/Distribution`. For explicitly local ad-hoc packages only, use the no-argument or `--github` build modes.
6. Confirm the app's version/build, architectures, minimum macOS, license/notices, icon, and entitlements. Check the final archives and `SHA256SUMS.txt`. Inspect Gatekeeper separately; an ad-hoc integrity check does not establish Developer ID signing or notarization.
7. Update `doc/current.md` and append the completed validation to `doc/devlog.md`. Commit only the source/configuration/documentation changes. Package files stay ignored and are uploaded as release assets.

The no-argument packaging command retains local-package naming. Both `--github` and `--notarized-app` use stable names such as `USBDisplay-1.0.2-macOS-universal.dmg` and `.zip`, with the exact build number stored in the app. `--github` builds an ad-hoc app; `--notarized-app` only packages a pre-verified signed/stapled app and refuses untrusted input. Do not confuse those modes.

The styled DMG uses the [installer artwork/layout](design/dmg-installer.md). Packaging creates an isolated temporary Python environment and downloads only the exact hash-pinned release-tool wheels from PyPI. It removes the environment afterward, including on failure. A prepared interpreter can be supplied through `DMGBUILD_PYTHON`; install `script/requirements-dmg.txt` with `--require-hashes` into that environment first. No Python tooling is included in the app or required by end users.

## Publish

1. Push the reviewed commit without rewriting remote history.
2. Create an annotated `vMAJOR.MINOR.PATCH` tag at that exact commit and push it. Never move an existing published tag.
3. Create a draft GitHub release from the pushed tag. Upload the DMG, ZIP, and `SHA256SUMS.txt`; use the versioned notes as the release body.
4. Check the draft's version, notes, and assets, then publish it. For the first open-source release, the repository must be public so unauthenticated visitors can read the source and download assets.
5. Verify public repository/release links and download the uploaded assets to a temporary directory. Match their hashes to the local packages, then delete that verification directory.
6. Record the published URLs and final verification in `doc/current.md` and `doc/devlog.md`. Documentation-only follow-up commits may follow the tagged release source; binary provenance must continue to point to the release tag.

Publishing remains an explicit maintainer operation. There is no automatic updater, background publishing job, or hosted release workflow in version 1.0.2. Native CI and signed release automation are tracked in Linear.

## Signing and notarization

Version 1.0.1 establishes the verified [Xcode workflow](notarization.md). For trusted direct downloads, use a Developer ID Application identity, hardened runtime, Apple notarization, and a stapled ticket, then validate the quarantined download on another Mac. Apple Distribution certificates are not the direct-distribution Developer ID identity. Follow [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). Store credentials outside the repository and do not expose them to untrusted pull requests.
