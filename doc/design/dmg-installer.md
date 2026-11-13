# DMG installer design

The current working artwork follows the maintainer's revised request: a plain white background, one flat gray circular-arc arrow from the app to Applications, and the English footer `Connect your iPhone or iPad via USB.`. Native app/folder icons and filenames remain Finder-owned. The published 1.0.2 installer retains its previous artwork; this revision is a local preview until reviewed.

## Composition

- A 640-by-360-point pure-white canvas, with no background gradient, circles, panels, divider, title, device copy, or extra installation instructions.
- Native 112-point app and folder icons at `(180, 158)` and `(460, 158)`.
- A single 2.5-point neutral-gray circular arc runs from the app toward Applications, with a tangent arrowhead and rounded ends. It has no filled face, bevel, extrusion, or shadow.
- The requested footer is centered near the bottom, with its text box starting at `y = 282`. The initial position at `y = 314` touched Finder's path-bar divider during native inspection and was raised for clearance.
- A 640-by-452-point initial Finder window in icon view. Toolbar/sidebar metadata are hidden; Finder can retain the user's tab/path/status preferences. No global Finder setting is changed.

The background itself contains only the arrow and the English connection guidance. It is a fixed raster image referenced by Finder metadata and does not select text based on the viewing Mac's system language; English is the maintainer's chosen fallback. Native filenames, volume titles, and Finder chrome are not baked into the artwork and are not renamed or hidden by modifying the signed app.

## Assets and regeneration

- `Packaging/DMG/background.png`: 640 by 360 pixels at 72 DPI.
- `Packaging/DMG/background@2x.png`: 1280 by 720 pixels at 144 DPI.
- `script/generate_dmg_background.swift`: editable AppKit drawing source.
- `script/dmg_settings.py`: icon positions, window/view settings, shortcut, and artwork selection.
- `script/requirements-dmg.txt`: exact versions and wheel hashes for the release-only DMG tools.

```bash
DMG_ART_CACHE=$(mktemp -d "${TMPDIR:-/tmp}/usb-display-art.XXXXXX")
xcrun swift -module-cache-path "$DMG_ART_CACHE" script/generate_dmg_background.swift
rm -rf "$DMG_ART_CACHE"
```

`NSBitmapImageRep.size` supplies the logical size; do not add a second Retina scale. The DMG builder combines the standard and Retina images into a multi-resolution TIFF. The package script creates disposable tooling by default or accepts a prepared interpreter through `DMGBUILD_PYTHON`.

## Signing and validation boundary

Installer artwork and Finder metadata stay outside the signed app. Do not apply `SetFile` or extension-hiding FinderInfo to the app after signing; the earlier attempt failed strict signature checks. The local preview reuses the already notarized 1.0.2 app without changing any app file contents or publishing replacement release assets.

Final native Finder inspection confirmed the flat circular arc, two icons, pure-white background, fully visible English footer, and no extra background headings or frames. The exact final preview was opened and left frontmost for the maintainer. Image dimensions/DPI and white-background samples are checked separately. Strict signature, stapled-ticket, and Gatekeeper checks apply to the app inside the preview. This artwork change does not modify app behavior or resolve the existing full-screen test instability.

## References

- [Apple HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout), installed Xcode 27.2 documentation.
- [dmgbuild](https://github.com/dmgbuild/dmgbuild) and its [settings reference](https://dmgbuild.readthedocs.io/en/latest/settings.html).
