#!/usr/bin/env python3

import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from build_battle_operation_comparison import EXPECTED_NAMES, build


class BattleOperationComparisonTest(unittest.TestCase):
    def test_builds_exactly_ten_in_order(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            art = root / "art"
            formal = root / "formal"
            output = root / "comparison"
            art.mkdir()
            formal.mkdir()
            rows = []
            for index, name in enumerate(EXPECTED_NAMES, start=1):
                file_name = name + ".png"
                Image.new("RGB", (1920, 1080), (index, 0, 0)).save(art / file_name)
                Image.new("RGB", (1920, 1080), (0, index, 0)).save(formal / file_name)
                rows.append({
                    "step": index,
                    "name": name,
                    "operation": name,
                    "file": file_name,
                    "stateVersion": index,
                    "stateHash": str(index),
                    "phase": "battle",
                    "battleRound": 1,
                })
            manifest = {"captureCount": 10, "captures": rows}
            (art / "capture_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            (formal / "capture_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            result = build(art, formal, output)
            self.assertEqual(result["comparisonCount"], 10)
            self.assertTrue(all(row["state_identity_match"] for row in result["comparisons"]))
            self.assertEqual(len(list(output.glob("*.png"))), 10)


if __name__ == "__main__":
    unittest.main()
