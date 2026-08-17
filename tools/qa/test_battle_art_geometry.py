#!/usr/bin/env python3

import unittest
from pathlib import Path

from check_battle_art_geometry import check


class BattleArtGeometryTest(unittest.TestCase):
    def test_current_round_passes_all_geometry_checks(self) -> None:
        project = Path(__file__).resolve().parents[2]
        round_dir = project / "output/validation/battle-art-roundtrip/round-001"
        report = check(round_dir / "art-project", round_dir / "formal-project", round_dir / "comparison")
        self.assertTrue(report["passed"], report)
        self.assertGreaterEqual(len(report["checks"]), 10)


if __name__ == "__main__":
    unittest.main()
