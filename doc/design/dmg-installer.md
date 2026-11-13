# DMG installer design

The installation window uses the app's established white and blue-gray palette. It presents one task: drag the real USB Display app onto the real Applications shortcut. The custom background contains guidance, not simulated controls or a second copy of either icon.

## Composition

- A 720-by-460-point canvas with a quiet white-to-pale-blue background.
- A centered app name, followed by Chinese and English drag-to-install instructions.
- Native 112-point app and folder icons centered at `(200, 226)` and `(520, 226)`, with a thin directional arrow between them and restrained circular backings.
- Small bilingual next-step guidance below a divider, plus minimum macOS/architecture information.
- Only the app and Applications shortcut are visible in the disk root. Detailed text installation notes remain beside local package outputs; public instructions are also in the README and installation guide.

`script/dmg_settings.py` requests an icon-view Finder window at 720 by 552 points, with toolbar/sidebar/path/status/tab settings disabled in the folder metadata. Finder can override some options with the user's preferences. The extra height accommodates the observed tab/path/status bars without changing global settings. Users can still resize the Finder window themselves.

## Assets and tooling

- `Packaging/DMG/background.png`: 720 by 460 pixels at 72 DPI.
- `Packaging/DMG/background@2x.png`: 1440 by 920 pixels at 144 DPI.
- `script/generate_dmg_background.swift`: editable native AppKit drawing source.
- `script/dmg_settings.py`: icon positions, view options, shortcut, volume icon, and artwork selection.
- `script/requirements-dmg.txt`: exact wheel versions/hashes for `dmgbuild`, `ds-store`, and `mac-alias`.

Regenerate artwork from the repository root with a temporary module cache, then remove that cache:

```bash
DMG_ART_CACHE=$(mktemp -d "${TMPDIR:-/tmp}/usb-display-art.XXXXXX")
xcrun swift -module-cache-path "$DMG_ART_CACHE" script/generate_dmg_background.swift
rm -rf "$DMG_ART_CACHE"
```

The image representation declares its logical size before creating the graphics context. Do not apply a second Retina transform: AppKit already supplies the backing scale. The two images are combined into a multi-resolution TIFF by the DMG builder.

The packaging script normally installs the small pinned wheels from PyPI into its own temporary environment and removes it with staging. For an already prepared environment, set `DMGBUILD_PYTHON` to its Python executable. These are release tools, not application/runtime dependencies. Failed packaging removes only that run's newly created incomplete output directory.

## Signing boundary

Keep all installer artwork and Finder metadata outside the signed `.app`. Do not use `SetFile` or `hide_extensions` on the app after signing: adding FinderInfo caused strict signature verification to fail during the first preview, even though Gatekeeper still accepted the notarized app. That option is disabled. Finder controls whether the `.app` suffix is visible according to the user's preference.

The final packaging workflow verifies the unmodified app's Developer ID signature and stapled ticket on the source, mounted DMG, and extracted ZIP. The disk image itself is a transport container; separate container notarization is not claimed.

## Design and contrast validation

The existing accepted app icon provided the palette and product context. Apple's installed Xcode 27.2 HIG Layout guidance informed hierarchy and familiar control/content relationships. No Finder-installer-specific Apple skill was available; the exported Apple Sufficient Contrast guidance was used for authored colors, together with the macOS packaging workflow and direct Finder inspection.

Verdict: PASS for the authored background's known colors. Against the darkest background endpoint (`#F1F6FC`), the title (`#213650`) measures 11.32:1; Chinese instruction text (`#435D79`) 6.27:1; English/footer text (`#526A83`) 5.16:1; and the meaningful arrow (`#708CA9`) 3.21:1. The decorative rings/divider are not controls. Native Finder icon labels are owned by the system; broad accessibility/appearance coverage is not certified by this artwork check.

The first preview exposed double Retina scaling and clipped content. After removing the duplicate transform and increasing the stored window height, Finder inspection at 1440-by-1104 screenshot pixels showed complete bilingual instructions/footer, native icons centered in the circles, a visible arrow, readable filename labels, and no overlap, clipping, scrollbars, or unintended empty panel. Toolbar/sidebar were hidden while the host's tab/path/status bars remained visible. No global Finder preferences were changed and no app was installed during inspection.

## References

- [Apple HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout), installed documentation release 2236 / Xcode 27.2.
- [dmgbuild](https://github.com/dmgbuild/dmgbuild) and its [settings reference](https://dmgbuild.readthedocs.io/en/latest/settings.html), with the installed 1.6.7 implementation checked for file copying and Finder metadata behavior.
