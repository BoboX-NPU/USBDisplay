# In-app updates

Version 1.1.0 (build 8) integrates Sparkle 2.10.1. Version 1.0.3 and earlier do not contain an updater; those users must manually install 1.1.0 once.

## User experience

- Automatic checks are enabled by default, with Sparkle's daily interval. `USB Display > Automatically Check for Updates` lets users turn scheduled checks off.
- `USB Display > Check for Updates…` checks immediately or brings an ongoing update into focus.
- Ordinary updates download in the app with Sparkle's standard progress and cancellation controls. Sparkle verifies the archive before extraction. The ready window waits for `Install and Relaunch`.
- An ordinary quit cancels an unconfirmed update and waits for the update cycle to finish before exiting. During extraction, cancellation waits for the ready callback. Clicking `Install and Relaunch` authorizes Sparkle's quit and restart. Force-killing the process or an OS crash is outside this normal-termination contract.
- Major and informational updates retain Sparkle's explicit update prompt. Recovered installations also require confirmation.
- Disabling scheduled checks does not cancel an update already in progress. Use the progress window's Cancel button while downloading, or quit to cancel a prepared update.
- System profiling is disabled. Update requests retrieve release metadata and binaries; captured video is never sent to the update host.

`SUAutomaticallyUpdate` and `SUAllowsAutomaticUpdates` are deliberately false: Sparkle's stock automatic-download mode also installs on quit. `UpdateUserDriver` instead starts the foreground download path for ordinary updates and keeps the separate ready-to-install confirmation. `UpdateInstallationGate` bridges normal AppKit termination to cancellation so an unconfirmed prepared update is not installed by quitting. One app-owned `UpdateController` serves all windows.

## Hosting and signing

The production feed is:

```text
https://github.com/BoboX-NPU/USBDisplay/releases/latest/download/appcast.xml
```

Every stable release starting with the first updater release must attach `appcast.xml` alongside its ZIP. The feed uses immutable version-specific ZIP URLs under the same repository. No GitHub API token, custom backend, or Pages configuration is needed at runtime. Prereleases do not replace the stable feed. The stable release must always carry the signed appcast; a missing feed is an update error, not proof that the app is current.

Sparkle is pinned exactly in the Xcode project and `Package.resolved`. Its license and bundled notices are reproduced in the separate bundled `Sparkle-LICENSE.txt`; generated device-data notices remain in `ThirdPartyNotices.txt`. Use Xcode Archive/Developer ID export so nested framework helpers are re-signed along with the application, then notarize and staple the exported app before packaging.

Update archives and the appcast are signed with an app-specific Ed25519 key in the login Keychain, account `com.xuemingbo.iPhoneUSBDisplay.sparkle`. Only the public key is in `Config/Info.plist`. The key is separate from the Developer ID certificate. Never commit/export the private key into source or release assets. Keep a secure backup before migrating or erasing the signing Mac; losing it requires a reviewed key-rotation plan.

`SURequireSignedFeed` and `SUVerifyUpdateBeforeExtraction` are enabled. The feed embeds release notes, covered by the feed signature. Any byte-level change to a signed feed requires re-signing.

## Preparing and publishing an update

1. Increase the marketing version and integer build in both app configurations. Keep the bundle identifier and update public key stable.
2. Run the project validation, archive, and follow [notarization](notarization.md). Package the exact notarized export with `script/package_local_release.sh --notarized-app`.
3. Download the previous production appcast to a temporary path for every release after the first updater release. Keep it as input, not as the output file. The script verifies its signature and requires the new build to be greater than every previous item.
4. Generate the next feed locally:

```bash
python3 script/prepare_update.py \
  .build/Distribution/RELEASE_DIRECTORY/USBDisplay-1.1.0-macOS-universal.zip \
  doc/releases/v1.1.0.md \
  --first-release \
  --output .build/Distribution/RELEASE_DIRECTORY/appcast.xml
```

For subsequent releases replace `--first-release` with `--previous-appcast /temporary/path/previous-appcast.xml`. The default tools come from `.build/Xcode/SourcePackages/artifacts/sparkle/Sparkle/bin`; resolve/build the pinned dependency first, or supply `--sparkle-bin`. The script uses the Keychain, checks the exact release ZIP's identity, public key, feed settings, architectures, Developer ID team, hardened runtime, signature, ticket, and Gatekeeper status, then signs/verifies both archive and feed. It refuses to overwrite output. All extracted validation files are temporary and removed, including on failure. It never publishes anything.

5. Inspect the resulting versions, notes, ZIP URL, size, and signature. Add `appcast.xml` to the release draft together with the exact ZIP, DMG, and checksums. Publish only after the normal maintainer release review; all assets must exist before the release becomes latest.
6. Download the public appcast and ZIP anonymously, verify feed/archive signatures and package hashes, and test an actual upgrade from an earlier updater-enabled build. Keep earlier items when raising OS requirements so compatible older releases remain discoverable.

## Validation boundaries

Use an isolated app identifier, temporary app copies, a signed local feed, and a localhost server for updater acceptance. Never publish fake newer versions to the production feed. Verify automatic check/download, visible progress, cancellation, ready-state ordinary quit without replacement, explicit installation/relaunch, no-update, and malformed or tampered feed handling. Production Developer ID/notarization and public delivery are separate checks from local ad-hoc update fixtures.

Official references: [Sparkle setup](https://sparkle-project.org/documentation/), [configuration](https://sparkle-project.org/documentation/customization/), [user-driver lifecycle](https://sparkle-project.org/documentation/api-reference/Protocols/SPUUserDriver.html), and [Apple menu conventions](https://developer.apple.com/design/human-interface-guidelines/menus). Integration targets macOS 14+ and was developed with Xcode 27.2.
