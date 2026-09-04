# Device Corner Reference Profiles

The app bundles a generated catalog of **164 exact product identifiers: 60 iPhone and 104 iPad**. This retains all 80 previous identifiers and adds 84 regional, cellular, memory, and older-device variants. Identifiers are not counts of distinct screen designs or hardware acceptance results. The [generated catalog](device-corner-catalog.md) lists every shipped profile, source revision, reviewed conflict, and excluded entry.

Only an exact USB `ProductType` selects a profile. Capture `modelID`, user-editable device names, and aspect ratio never select a specific model. Runtime loading validates the catalog schema, unique identifiers, and finite geometry; a missing or invalid resource leaves models unmatched. No network download, Xcode installation, simulator access, or private Apple framework is required at runtime. Legacy manual preferences remain stored but are not applied.

## Sources and Units

| Source | Checked-in input | Purpose |
| --- | --- | --- |
| Apple Simulator device profiles | `data/device-profiles/apple-simulator.json` | Logical radius and short side from 85 source bundles covering 80 identifiers; each source plist has a SHA-256 hash. |
| [BezelKit](https://github.com/markbattistella/BezelKit) | `data/device-profiles/bezelkit.json` | Complete upstream radius database, including 63 iPhone and 103 iPad identifiers, used for cross-checks and corroborating older square displays. |
| [DeviceKit](https://github.com/devicekit/DeviceKit) | `data/device-profiles/devicekit.gyb` | Explicit hardware identifier groups and rounded-display flags; aliases are derived from these literal groups. Downloaded source is parsed as metadata and is never executed. |

`data/device-profiles/upstream-lock.json` pins both open-source repositories to full commit hashes and records file hashes, including their MIT licenses. The app bundles the complete notices in `ThirdPartyNotices.txt`. The upstream libraries themselves are not linked into the application.

Apple calibration reads the integrated primary display's four explicitly equal `cornerRadiusUL/UR/LL/LR` values in logical points. Normalization is `radius / (min(width, height) / scale)`, multiplied by the displayed short side. CALayer continuous corners apply this geometry only in compact mode. Rotation uses the same fraction. iPhone 16 Pro and iPhone 17 Pro both use 62 / 402; iPhone 17 Pro Max uses 62 / 440. The sources do not justify an artificial radius difference between every generation.

A rounded DeviceKit group must have an exact Apple reference member with a measured short side. All Apple members of that group must agree. Other identifiers in that explicit group share its geometry. An older square display may use zero without an Apple short-side measurement only when DeviceKit's nonrounded flag and BezelKit's zero radius agree. This avoids inventing missing dimensions.

These are display-reference values, not live physical hardware measurements. Broader metadata coverage does not establish that older devices support the application's USB capture path. The app does not claim to cover every Apple device ever released.

## Conflict Review

`data/device-profiles/decisions.json` records the expected competing values, the selected resolution, and its reason. Changes beyond 0.01 logical points require an explicit matching decision; this tolerance accommodates upstream rounding such as 47.333332 versus 47.33. Changed or stale decisions stop generation.

- iPad Air 3 (`iPad11,3` / `iPad11,4`): use zero. DeviceKit explicitly marks both displays as nonrounded, agreeing with BezelKit; the raw Apple snapshot's 18-point value is preserved as conflicting evidence. [Apple specifications](https://support.apple.com/en-us/111939) confirm the product identity and display dimensions but do not publish a numeric corner radius.
- iPhone 12 / 12 Pro / 12 Pro Max: retain the Apple reference values of 47 / 47 / 53 points instead of BezelKit's 47.33 / 47.33 / 53.33. The source disagreement remains visible in the generated audit.
- `iPad16,8`: DeviceKit explicitly groups this with `iPad16,9` as iPad Air 11-inch (M4). Use that Apple anchor's 18 / 820 geometry; reject BezelKit's first-generation iPad Pro name and zero radius.

Six BezelKit entries have no corroborating Apple or DeviceKit identifier and remain excluded: `iPad1,1`, `iPad13,12`, `iPad16,7`, `iPhone1,1`, `iPhone1,2`, and `iPhone2,1`. Absence from these sources is not proof that an identifier is invalid. Unlisted or unresolved devices use zero custom radius and retain their identification status.

## Reproducible Updates

Python 3.9+ and its standard library are sufficient. Normal generation works offline from the checked-in snapshots:

```sh
python3 script/update_device_profiles.py
python3 script/update_device_profiles.py --check
python3 -m unittest discover -s script -p 'test_device_profiles.py'
```

Re-download the exact pinned open-source files with `--download`. To update upstream versions, supply reviewed full 40-character commit hashes with `--bezelkit-revision` and/or `--devicekit-revision` together with `--download`. Downloads have a 30-second socket timeout and a 2 MB response cap. Network access is confined to this developer command.

To refresh the Apple snapshot from installed profiles:

```sh
python3 script/update_device_profiles.py --simulator-root /Library/Developer/CoreSimulator/Profiles/DeviceTypes
```

A refresh may replace source snapshots before a new conflict stops generation. Review those source changes, then resolve each conflict in `decisions.json` using corroborating evidence and regenerate. Never copy new numbers into decisions merely to bypass a failure. Generated application resources remain untouched until all source checks pass.

Commit source snapshots, pins, reviewed decisions, generated resources, and the generated catalog together. Run the generator checks, Swift tests, Debug/Release builds, and bundle-resource verification. Document physical-device checks separately; unavailable products are not hardware passes.
