#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import run_qa


class QaRunnerTests(unittest.TestCase):
    def test_expand_suite_supports_nested_globs_and_deduplication(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "tests").mkdir()
            (root / "tests" / "smoke_a.gd").write_text("", encoding="utf-8")
            (root / "tests" / "smoke_b.gd").write_text("", encoding="utf-8")
            manifest = {
                "defaults": {"timeout_seconds": 12},
                "suites": {
                    "base": [{"glob": "tests/smoke_*.gd"}],
                    "nested": [
                        {"suite": "base"},
                        {"path": "tests/smoke_a.gd"},
                    ],
                },
            }
            specs = run_qa.expand_suite(manifest, "nested", root=root)
            self.assertEqual([spec.path for spec in specs], [
                "tests/smoke_a.gd",
                "tests/smoke_b.gd",
            ])
            self.assertTrue(all(spec.timeout_seconds == 12 for spec in specs))

    def test_user_data_paths_are_namespaced(self) -> None:
        mac_path = run_qa.user_data_dir("YSBZS_QA/run/test", platform="darwin")
        linux_path = run_qa.user_data_dir("YSBZS_QA/run/test", platform="linux")
        self.assertIn("YSBZS_QA/run/test", mac_path.as_posix())
        self.assertIn("YSBZS_QA/run/test", linux_path.as_posix())
        with self.assertRaises(ValueError):
            run_qa.user_data_dir("YSBZS Godot Singleplayer", platform="darwin")

    def test_overlay_uses_custom_user_directory_without_touching_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "project.godot").write_text(
                'config_version=5\n[application]\nconfig/name="Base"\n',
                encoding="utf-8",
            )
            (root / "tests").mkdir()
            (root / "tests" / "probe.gd").write_text("", encoding="utf-8")
            spec = run_qa.TestSpec(path="tests/probe.gd")
            overlay, custom_name, _ = run_qa.create_overlay(root, "unit-run", spec)
            try:
                override = (overlay / "override.cfg").read_text(encoding="utf-8")
                self.assertIn("config/use_custom_user_dir=true", override)
                self.assertIn(custom_name, override)
                self.assertEqual(
                    (root / "project.godot").read_text(encoding="utf-8"),
                    'config_version=5\n[application]\nconfig/name="Base"\n',
                )
            finally:
                import shutil
                shutil.rmtree(overlay, ignore_errors=True)

    def test_manifest_file_is_valid(self) -> None:
        manifest_path = run_qa.REPO_ROOT / "qa" / "suites.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        for suite in (
            "bot",
            "session",
            "core",
            "features",
            "integration",
            "fast",
            "full",
            "nightly",
            "visual",
            "release",
        ):
            self.assertGreater(
                len(run_qa.expand_suite(manifest, suite)),
                0,
                suite,
            )

    def test_quarantine_inventory_matches_suite_and_is_not_in_full_gate(self) -> None:
        manifest = json.loads(
            (run_qa.REPO_ROOT / "qa" / "suites.json").read_text(encoding="utf-8")
        )
        inventory = json.loads(
            (run_qa.REPO_ROOT / "qa" / "quarantine.json").read_text(encoding="utf-8")
        )
        quarantined = {
            spec.path for spec in run_qa.expand_suite(manifest, "quarantine")
        }
        documented = {entry["path"] for entry in inventory["entries"]}
        gated = {spec.path for spec in run_qa.expand_suite(manifest, "full")}
        self.assertEqual(quarantined, documented)
        self.assertEqual(quarantined, set())
        self.assertTrue(quarantined.isdisjoint(gated))

    def test_runtime_seed_count_replaces_manifest_default(self) -> None:
        spec = run_qa.TestSpec(
            path="tests/qa/seed_bot.gd",
            args=("--qa-seed-count=24", "--qa-probe=kept"),
        )
        self.assertEqual(
            run_qa.runtime_user_args(spec, 7, False),
            ["--qa-probe=kept", "--qa-seed-count=7"],
        )

    def test_process_log_is_bounded_from_the_tail(self) -> None:
        stored, truncated = run_qa.capped_log_text("prefix-" + ("x" * 20) + "-tail", 12)
        self.assertTrue(truncated)
        self.assertTrue(stored.endswith("-tail"))
        self.assertNotIn("prefix", stored)


if __name__ == "__main__":
    unittest.main()
