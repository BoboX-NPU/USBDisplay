#!/usr/bin/env python3
"""Validate a notarized release ZIP and prepare a signed Sparkle appcast locally."""

import argparse
import datetime
import email.utils
import html
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ACCOUNT = "com.xuemingbo.iPhoneUSBDisplay.sparkle"
REPOSITORY = "https://github.com/BoboX-NPU/USBDisplay"
FEED_URL = REPOSITORY + "/releases/latest/download/appcast.xml"
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE)


def run(*args):
    return subprocess.check_output([str(arg) for arg in args], text=True).strip()


def prepare(archive, notes, output, previous, tools):
    if archive.suffix != ".zip":
        raise ValueError("Use the universal release ZIP produced by package_local_release.sh")
    if output.exists():
        raise ValueError("Output already exists; choose a new path to preserve the previous signed feed")
    expected = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())
    public_key = run(tools / "generate_keys", "--account", ACCOUNT, "-p")
    if public_key != expected["SUPublicEDKey"]:
        raise ValueError("Keychain signing key does not match the project's update public key")
    with tempfile.TemporaryDirectory(prefix="usb-display-update-") as directory:
        scratch = Path(directory)
        with zipfile.ZipFile(archive) as zipped:
            for member in zipped.namelist():
                parts = Path(member).parts
                if Path(member).is_absolute() or ".." in parts:
                    raise ValueError("Archive contains an unsafe path")
                if parts and parts[0] not in ("USB Display.app", "__MACOSX"):
                    raise ValueError("Archive must contain only USB Display.app")
        run("ditto", "-x", "-k", archive, scratch)
        app = scratch / "USB Display.app"
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        version = info["CFBundleShortVersionString"]
        build = info["CFBundleVersion"]
        if not re.fullmatch(r"\d+\.\d+\.\d+", version) or not build.isdecimal():
            raise ValueError("Release version must be MAJOR.MINOR.PATCH with an integer build")
        if info["CFBundleIdentifier"] != "com.xuemingbo.iPhoneUSBDisplay":
            raise ValueError("Wrong application bundle identifier")
        if archive.name != f"USBDisplay-{version}-macOS-universal.zip":
            raise ValueError("Archive filename must match the release version")
        for key in ("SUPublicEDKey", "SUFeedURL", "SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction"):
            if info.get(key) != expected[key]:
                raise ValueError(f"Release has an unexpected {key}")
        run("codesign", "--verify", "--deep", "--strict", app)
        run("codesign", "--verify", "--strict", "-R=anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13] exists", app)
        signature = subprocess.run(["codesign", "-dv", "--verbose=4", str(app)], capture_output=True, text=True, check=True).stderr
        if "TeamIdentifier=9PSN33WBG7" not in signature or "runtime" not in signature:
            raise ValueError("Release must use the project's Developer ID team and hardened runtime")
        run("xcrun", "stapler", "validate", app)
        run("spctl", "--assess", "--type", "execute", app)
        architectures = run("xcrun", "lipo", "-archs", app / "Contents/MacOS/USB Display").split()
        if not {"arm64", "x86_64"}.issubset(architectures):
            raise ValueError("Release must include Apple Silicon and Intel")

        if previous:
            run(tools / "sign_update", "--account", ACCOUNT, "--verify", previous)
            root = ET.parse(previous).getroot()
            channel = root.find("channel")
            if root.tag != "rss" or channel is None:
                raise ValueError("Previous feed is not a Sparkle RSS appcast")
            for item in channel.findall("item"):
                old_build = item.findtext(f"{{{SPARKLE}}}version")
                if old_build is None or not old_build.isdecimal() or int(old_build) >= int(build):
                    raise ValueError("Build must increase beyond every previous appcast item")
        else:
            root = ET.Element("rss", version="2.0")
            channel = ET.SubElement(root, "channel")
            ET.SubElement(channel, "title").text = "USB Display Updates"
            ET.SubElement(channel, "link").text = REPOSITORY
            ET.SubElement(channel, "description").text = "Signed updates for USB Display."
            ET.SubElement(channel, "language").text = "en"

        item = ET.Element("item")
        ET.SubElement(item, "title").text = f"USB Display {version}"
        ET.SubElement(item, "pubDate").text = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
        ET.SubElement(item, f"{{{SPARKLE}}}version").text = build
        ET.SubElement(item, f"{{{SPARKLE}}}shortVersionString").text = version
        ET.SubElement(item, f"{{{SPARKLE}}}minimumSystemVersion").text = info["LSMinimumSystemVersion"]
        ET.SubElement(item, "description").text = "<pre>" + html.escape(notes.read_text()) + "</pre>"
        update_signature = run(tools / "sign_update", "--account", ACCOUNT, "-p", archive)
        run(tools / "sign_update", "--account", ACCOUNT, "--verify", archive, update_signature)
        ET.SubElement(item, "enclosure", {
            "url": f"{REPOSITORY}/releases/download/v{version}/{archive.name}",
            "length": str(archive.stat().st_size),
            "type": "application/octet-stream",
            f"{{{SPARKLE}}}edSignature": update_signature,
        })
        channel.append(item)
        feed = scratch / "appcast.xml"
        ET.indent(root)
        ET.ElementTree(root).write(feed, encoding="utf-8", xml_declaration=True)
        run(tools / "sign_update", "--account", ACCOUNT, feed)
        run(tools / "sign_update", "--account", ACCOUNT, "--verify", feed)
        output.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive creation prevents accidental replacement of a published feed.
        with output.open("xb") as destination:
            destination.write(feed.read_bytes())
    print(f"Signed appcast: {output}")
    print(f"Upload as appcast.xml with the ZIP to release v{version}; publish only after review.")
    print(f"Verify the public feed after publication: {FEED_URL}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("notes", type=Path, help="UTF-8 release notes, embedded in the signed feed")
    parser.add_argument("--output", type=Path, required=True)
    history = parser.add_mutually_exclusive_group(required=True)
    history.add_argument("--previous-appcast", type=Path, help="Previously published signed appcast, preserving compatible older releases")
    history.add_argument("--first-release", action="store_true", help="Explicitly bootstrap the first updater-enabled release")
    parser.add_argument("--sparkle-bin", type=Path, default=ROOT / ".build/Xcode/SourcePackages/artifacts/sparkle/Sparkle/bin")
    args = parser.parse_args()
    try:
        prepare(args.archive.resolve(), args.notes.resolve(), args.output.resolve(), args.previous_appcast, args.sparkle_bin)
    except (ValueError, OSError, KeyError, ET.ParseError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Cannot prepare update: {error}\n")


if __name__ == "__main__":
    main()
