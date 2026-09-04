#!/usr/bin/env python3
"""Build the offline corner catalog from pinned, reviewed source snapshots."""

import argparse
import ast
import datetime
import hashlib
import json
import math
from pathlib import Path
import plistlib
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "data/device-profiles"
PRODUCT_TYPE = re.compile(r"(?:iPhone|iPad)[1-9]\d*,[1-9]\d*")
TOLERANCE = 0.01  # BezelKit rounds some floating-point references to two decimals.


def read_json(path):
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique_object)


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def fetch(url):
    with urllib.request.urlopen(url, timeout=30) as response:
        data = response.read(2_000_001)
    if len(data) > 2_000_000:
        raise ValueError("Upstream response exceeds 2 MB")
    return data


def download_sources(revisions):
    lock = read_json(SOURCES / "upstream-lock.json")
    pending = {}
    for key, source in lock.items():
        revision = revisions.get(key) or source["revision"]
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            raise ValueError("Use a full, immutable upstream commit SHA")
        repo = source["repository"].removeprefix("https://github.com/")
        for filename, entry in source["files"].items():
            data = fetch(f"https://raw.githubusercontent.com/{repo}/{revision}/{entry['path']}")
            digest = hashlib.sha256(data).hexdigest()
            if revision == source["revision"] and digest != entry["sha256"]:
                raise ValueError(f"Upstream hash mismatch: {filename}")
            pending[filename] = data
            entry["sha256"] = digest
        source["revision"] = revision
    for filename, data in pending.items():
        (SOURCES / filename).write_bytes(data)
    (SOURCES / "upstream-lock.json").write_bytes(json_bytes(lock))


def extract_simulator(directory):
    profiles = []
    for path in sorted(directory.glob("*.simdevicetype/Contents/Resources/capabilities.plist")):
        raw = path.read_bytes()
        capabilities = plistlib.loads(raw)["capabilities"]
        model = capabilities.get("modelIdentifier", "")
        if not PRODUCT_TYPE.fullmatch(model):
            continue
        displays = [d for d in capabilities.get("displays", [])
                    if d.get("deviceName") == "primary" and d.get("displayType") == "integrated"]
        if len(displays) != 1:
            raise ValueError(f"Ambiguous primary display: {path}")
        display = displays[0]
        radii = [display.get("cornerRadius" + corner) for corner in ("UL", "UR", "LL", "LR")]
        if None in radii or len(set(radii)) != 1:
            raise ValueError(f"Missing or unequal corner radii: {path}")
        profiles.append({
            "productType": model, "name": capabilities.get("marketing-name", path.parents[2].stem),
            "radius": radii[0], "shortSide": min(display["width"], display["height"]) / display["scale"],
            "bundle": path.parents[2].name, "sha256": hashlib.sha256(raw).hexdigest(),
        })
    if not profiles:
        raise ValueError("No Apple device profiles found")
    (SOURCES / "apple-simulator.json").write_bytes(json_bytes({
        "extractedOn": datetime.date.today().isoformat(), "source": str(directory), "profiles": profiles,
    }))


def device_groups(text):
    """Read literal metadata only. Never run downloaded Python/GYB code."""
    signature = re.search(r"def __init__\(self, ([^)]*)\)", text)
    fields = signature.group(1).split(", ") if signature else []
    if len(fields) != 26 or any(fields[i] != name for i, name in
                               {0: "caseName", 3: "identifiers", 7: "safeDescription",
                                17: "hasRoundedDisplayCorners"}.items()):
        raise ValueError("DeviceKit schema changed; review the importer")
    groups = []
    identifiers = set()
    for line in text.splitlines():
        if not re.match(r'\s*Device\("i(?:Phone|Pad)', line):
            continue
        call = ast.parse(line.strip().removesuffix(","), mode="eval").body
        if not isinstance(call, ast.Call) or call.keywords or len(call.args) != 26:
            raise ValueError("DeviceKit schema changed; review the importer")
        args = [ast.literal_eval(arg) for arg in call.args]
        group = {"group": args[0], "ids": args[3], "name": args[7], "rounded": args[17]}
        if not isinstance(group["rounded"], bool) or not group["ids"]:
            raise ValueError("Invalid DeviceKit shape metadata")
        for model in group["ids"]:
            if not PRODUCT_TYPE.fullmatch(model) or model in identifiers:
                raise ValueError(f"Duplicate or invalid identifier: {model}")
            identifiers.add(model)
        groups.append(group)
    if not groups:
        raise ValueError("No DeviceKit groups parsed")
    return groups


def build_catalog(apple_snapshot, bezel_snapshot, groups, decisions):
    apple = {}
    for profile in sorted(apple_snapshot["profiles"], key=lambda p: (len(p["bundle"]), p["bundle"])):
        model = profile["productType"]
        radius, short = profile["radius"], profile["shortSide"]
        if not PRODUCT_TYPE.fullmatch(model) or not (math.isfinite(radius) and math.isfinite(short)
                                                    and short > 0 and 0 <= radius / short <= 0.2):
            raise ValueError(f"Invalid Apple geometry: {model}")
        if model in apple and any(apple[model][k] != profile[k] for k in ("radius", "shortSide")):
            raise ValueError(f"Conflicting Apple profiles: {model}")
        apple.setdefault(model, profile)
    bezel = {k: v for family in ("iPhone", "iPad")
             for k, v in bezel_snapshot["devices"][family].items()}
    for model, entry in bezel.items():
        radius = entry["bezel"]
        if (not PRODUCT_TYPE.fullmatch(model) or not entry.get("name")
                or type(radius) not in (int, float) or not math.isfinite(radius) or radius < 0):
            raise ValueError(f"Invalid BezelKit reference: {model}")
    profiles, used_decisions, conflicts = {}, set(), []

    def decision(model, reference, rounded, resolution):
        observed = {"appleRadius": reference["radius"], "bezelRadius": bezel.get(model, {}).get("bezel"),
                    "rounded": rounded, "resolution": resolution}
        reviewed = decisions.get(model, {})
        if any(reviewed.get(k) != value for k, value in observed.items()) or not reviewed.get("reason"):
            raise ValueError(f"Unreviewed source conflict for {model}: {observed}")
        used_decisions.add(model)
        conflicts.append({"productType": model, **observed, "reason": reviewed["reason"]})

    for group in groups:
        references = [apple[model] for model in sorted(group["ids"]) if model in apple]
        if references and any((p["radius"], p["shortSide"]) !=
                              (references[0]["radius"], references[0]["shortSide"]) for p in references):
            raise ValueError(f"Group has differing Apple geometry: {group['group']}")
        reference = references[0] if references else None
        corrected_square = False
        if reference and bool(reference["radius"]) != group["rounded"]:
            decision(reference["productType"], reference, group["rounded"], "square")
            if group["rounded"]:
                raise ValueError("Cannot invent a missing rounded radius")
            corrected_square = True
        if group["rounded"] and reference is None:
            raise ValueError(f"Rounded device has no measured short side: {group['group']}")
        for model in group["ids"]:
            radius = reference["radius"] if group["rounded"] else 0
            if model in bezel and abs(bezel[model]["bezel"] - radius) > TOLERANCE:
                if reference is None:
                    raise ValueError(f"Square-display sources disagree: {model}")
                decision(model, reference, group["rounded"], "apple")
            if reference is None and (model not in bezel or bezel[model]["bezel"] != 0):
                raise ValueError(f"Square display needs corroborating BezelKit data: {model}")
            own_reference = apple.get(model, reference)
            profiles[model] = {
                "productType": model, "name": group["name"], "radius": radius,
                "shortSide": own_reference["shortSide"] if own_reference else None,
                "reference": "Apple Simulator display profile" if reference and not corrected_square
                             else "BezelKit square-display reference, corroborated by DeviceKit",
                "simulatorProductType": own_reference["productType"] if own_reference else None,
                "deviceKitGroup": group["group"],
            }
    # Keep exact Apple records even when the supplemental identity source lags behind.
    for model, reference in apple.items():
        if model not in profiles:
            if model in bezel and abs(bezel[model]["bezel"] - reference["radius"]) > TOLERANCE:
                decision(model, reference, bool(reference["radius"]), "apple")
            profiles[model] = {k: reference[k] for k in ("productType", "name", "radius", "shortSide")}
            profiles[model].update(reference="Apple Simulator display profile",
                                   simulatorProductType=model, deviceKitGroup=None)
    if set(decisions) != used_decisions:
        raise ValueError(f"Stale conflict decisions: {sorted(set(decisions) - used_decisions)}")
    excluded = [{"productType": k, "name": v["name"],
                 "reason": "Identifier absent from both Apple profiles and DeviceKit; not guessed"}
                for k, v in sorted(bezel.items()) if k not in profiles]
    return {"schemaVersion": 1, "profiles": [profiles[k] for k in sorted(profiles)]}, conflicts, excluded


def outputs():
    lock = read_json(SOURCES / "upstream-lock.json")
    for source in lock.values():
        for filename, entry in source["files"].items():
            if hashlib.sha256((SOURCES / filename).read_bytes()).hexdigest() != entry["sha256"]:
                raise ValueError(f"Source hash mismatch: {filename}")
    apple = read_json(SOURCES / "apple-simulator.json")
    catalog, conflicts, excluded = build_catalog(
        apple, read_json(SOURCES / "bezelkit.json"),
        device_groups((SOURCES / "devicekit.gyb").read_text()), read_json(SOURCES / "decisions.json"))
    catalog["sources"] = lock
    catalog["appleSnapshotSHA256"] = hashlib.sha256((SOURCES / "apple-simulator.json").read_bytes()).hexdigest()
    lines = ["# Generated Device Corner Catalog", "", "Generated by `script/update_device_profiles.py`. Do not edit.", "",
             f"Matched product identifiers: **{len(catalog['profiles'])}**. These are reference profiles, not physical-device test results.", "",
             "## Source Revisions", ""]
    for key, source in lock.items():
        lines.append(f"- [{key}]({source['repository']}/tree/{source['revision']}): `{source['revision']}`.")
    lines += [f"- Apple Simulator snapshot: {apple['extractedOn']}; {len(apple['profiles'])} source bundles.", "",
              "## Reviewed Conflicts", ""]
    for c in sorted(conflicts, key=lambda c: c["productType"]):
        lines.append(f"- `{c['productType']}`: Apple {c['appleRadius']}, BezelKit {c['bezelRadius']}; {c['reason']}")
    lines += ["", "## Excluded BezelKit Entries", ""]
    for e in excluded:
        lines.append(f"- `{e['productType']}` ({e['name']}): {e['reason']}.")
    lines += ["", "## Shipped Profiles", "", "| ProductType | Model | Radius (pt) | Short side (pt) | Reference model |",
              "| --- | --- | ---: | ---: | --- |"]
    for p in catalog["profiles"]:
        lines.append(f"| {p['productType']} | {p['name']} | {p['radius']:g} | {p['shortSide'] or 'Not needed (square)'} | {p['simulatorProductType'] or 'Corroborated square display'} |")
    notices = "Third-party data notices\n\n"
    for key, source in lock.items():
        notices += f"{key}: {source['repository']}\nRevision: {source['revision']}\n\n"
        notices += (SOURCES / f"{key}-LICENSE.txt").read_text() + "\n\n"
    return {
        ROOT / "USBDisplay/Resources/device-corner-profiles.json": json_bytes(catalog),
        ROOT / "USBDisplay/Resources/ThirdPartyNotices.txt": (notices.rstrip() + "\n").encode(),
        ROOT / "doc/device-corner-catalog.md": ("\n".join(lines) + "\n").encode(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify generated outputs without writing")
    parser.add_argument("--download", action="store_true", help="Download sources at pinned revisions")
    parser.add_argument("--bezelkit-revision")
    parser.add_argument("--devicekit-revision")
    parser.add_argument("--simulator-root", type=Path, help="Refresh the local Apple reference snapshot")
    args = parser.parse_args()
    revisions = {"bezelkit": args.bezelkit_revision, "devicekit": args.devicekit_revision}
    if args.check and (args.download or args.simulator_root or any(revisions.values())):
        parser.error("--check cannot refresh sources")
    if any(revisions.values()) and not args.download:
        parser.error("Revision overrides require --download")
    if args.download:
        download_sources(revisions)
    if args.simulator_root:
        extract_simulator(args.simulator_root)
    generated = outputs()  # Validate every input/conflict before replacing outputs.
    for path, content in generated.items():
        if args.check:
            if not path.exists() or path.read_bytes() != content:
                raise ValueError(f"Generated output is stale: {path.relative_to(ROOT)}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    print("Device profile catalog " + ("verified" if args.check else "generated"))


if __name__ == "__main__":
    main()
