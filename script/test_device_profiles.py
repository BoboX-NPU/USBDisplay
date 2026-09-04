"""Regression checks for source reconciliation and safe metadata parsing."""

import copy
from pathlib import Path
import tempfile
import unittest

import update_device_profiles as catalog


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.apple = catalog.read_json(catalog.SOURCES / "apple-simulator.json")
        self.bezel = catalog.read_json(catalog.SOURCES / "bezelkit.json")
        self.source = (catalog.SOURCES / "devicekit.gyb").read_text()
        self.groups = catalog.device_groups(self.source)
        self.decisions = catalog.read_json(catalog.SOURCES / "decisions.json")

    def build(self):
        return catalog.build_catalog(self.apple, self.bezel, self.groups, self.decisions)

    def test_reproducible_outputs_and_preserved_apple_coverage(self):
        first = catalog.outputs()
        self.assertEqual(first, catalog.outputs())
        for path, data in first.items():
            self.assertEqual(path.read_bytes(), data)
        result, conflicts, excluded = self.build()
        identifiers = {p["productType"] for p in result["profiles"]}
        self.assertEqual(len(identifiers), 164)
        self.assertTrue({p["productType"] for p in self.apple["profiles"]} <= identifiers)
        self.assertEqual({c["productType"] for c in conflicts}, set(self.decisions))
        self.assertIn("iPad13,12", {e["productType"] for e in excluded})
        self.assertIn("iPad16,7", {e["productType"] for e in excluded})

    def test_new_conflict_requires_review(self):
        self.bezel["devices"]["iPhone"]["iPhone17,1"]["bezel"] = 63
        with self.assertRaisesRegex(ValueError, "Unreviewed source conflict"):
            self.build()

    def test_stale_decision_is_not_silently_reused(self):
        self.decisions["iPhone13,2"]["appleRadius"] = 48
        with self.assertRaisesRegex(ValueError, "Unreviewed source conflict"):
            self.build()

    def test_apple_only_identifier_still_requires_conflict_review(self):
        new = copy.deepcopy(self.apple["profiles"][0])
        new.update(productType="iPhone99,1", name="New iPhone", radius=60, shortSide=400)
        self.apple["profiles"].append(new)
        self.bezel["devices"]["iPhone"]["iPhone99,1"] = {"name": "New iPhone", "bezel": 61}
        with self.assertRaisesRegex(ValueError, "Unreviewed source conflict"):
            self.build()

    def test_conflicting_apple_memory_variants_are_rejected(self):
        duplicate = copy.deepcopy(self.apple["profiles"][0])
        duplicate["radius"] += 1
        self.apple["profiles"].append(duplicate)
        with self.assertRaisesRegex(ValueError, "Conflicting Apple profiles"):
            self.build()

    def test_new_rounded_device_cannot_borrow_geometry_by_name(self):
        self.groups.append({"group": "new", "ids": ["iPhone99,1"],
                            "name": "iPhone 16 Pro", "rounded": True})
        self.bezel["devices"]["iPhone"]["iPhone99,1"] = {"name": "iPhone 16 Pro", "bezel": 62}
        with self.assertRaisesRegex(ValueError, "no measured short side"):
            self.build()

    def test_nonfinite_upstream_radius_is_rejected(self):
        self.bezel["devices"]["iPhone"]["iPhone17,1"]["bezel"] = float("nan")
        with self.assertRaisesRegex(ValueError, "Invalid BezelKit"):
            self.build()

    def test_downloaded_code_is_never_executed(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "executed"
            line = next(line for line in self.source.splitlines() if 'Device("iPhone4",' in line)
            malicious = line.replace('"iPhone 4", "iPhone 4",',
                                     f'"iPhone 4", open({str(marker)!r}, "w"),')
            self.assertNotEqual(line, malicious)
            with self.assertRaises(ValueError):
                catalog.device_groups(self.source.replace(line, malicious))
            self.assertFalse(marker.exists())

    def test_schema_reordering_and_duplicate_identifiers_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "schema changed"):
            catalog.device_groups(self.source.replace("safeDescription, ppi", "ppi, safeDescription", 1))
        line = next(line for line in self.source.splitlines() if 'Device("iPhone4",' in line)
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            catalog.device_groups(self.source + "\n" + line)


if __name__ == "__main__":
    unittest.main()
