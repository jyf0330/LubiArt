#!/usr/bin/env python3
"""Check the ten battle comparison captures for semantic and image geometry parity."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _image_size(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        return image.size


def check(art_dir: Path, formal_dir: Path, comparison_dir: Path) -> dict:
    art = _load(art_dir / "capture_manifest.json")
    formal = _load(formal_dir / "capture_manifest.json")
    comparison = _load(comparison_dir / "comparison_manifest.json")
    checks = []

    def add(name: str, passed: bool, detail: str) -> None:
        checks.append({"name": name, "passed": bool(passed), "detail": detail})

    add("exactly_ten_art", art.get("captureCount") == 10, str(art.get("captureCount")))
    add("exactly_ten_formal", formal.get("captureCount") == 10, str(formal.get("captureCount")))
    add("exactly_ten_comparisons", comparison.get("comparisonCount") == 10, str(comparison.get("comparisonCount")))
    art_rows = art.get("captures", [])
    formal_rows = formal.get("captures", [])
    add(
        "operation_names_match",
        [row.get("name") for row in art_rows] == [row.get("name") for row in formal_rows],
        "same ordered operation names",
    )
    add(
        "all_state_identities_match",
        all(row.get("state_identity_match") for row in comparison.get("comparisons", [])),
        "stateVersion/stateHash/phase/battleRound",
    )
    sizes_ok = True
    for row in art_rows:
        sizes_ok = sizes_ok and _image_size(art_dir / row["file"]) == (1920, 1080)
    for row in formal_rows:
        sizes_ok = sizes_ok and _image_size(formal_dir / row["file"]) == (1920, 1080)
    add("all_source_images_1920x1080", sizes_ok, "20 source screenshots")
    comparison_sizes_ok = all(
        _image_size(comparison_dir / row["file"]) == (3840, 1192)
        for row in comparison.get("comparisons", [])
    )
    add("all_comparisons_3840x1192", comparison_sizes_ok, "10 labeled comparisons")

    for side, rows in (("art", art_rows), ("formal", formal_rows)):
        by_name = {row["name"]: row for row in rows}
        add(
            f"{side}_detail_closes_on_empty_floor",
            not bool(by_name["04_empty_floor_click"]["interaction"]["detail"].get("visible", False)),
            "step 04 detail.visible=false",
        )
        add(
            f"{side}_drag_preview_active",
            bool(by_name["05_drag_preview"]["interaction"]["drag"].get("dragging", False)),
            "step 05 drag.dragging=true",
        )
        add(
            f"{side}_drag_cancel_recovers",
            not bool(by_name["06_drag_cancelled"]["interaction"]["drag"].get("dragging", True)),
            "step 06 drag.dragging=false",
        )
        add(
            f"{side}_drag_cancel_keeps_detail_closed",
            not bool(by_name["06_drag_cancelled"]["interaction"]["detail"].get("visible", True)),
            "step 06 detail.visible=false",
        )
    report = {
        "schemaVersion": 1,
        "passed": all(row["passed"] for row in checks),
        "checks": checks,
        "known_visual_scope": "art direction and board composition may differ; geometry gate covers operation state, capture size, detail and drag recovery",
    }
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--art-dir", type=Path, required=True)
    parser.add_argument("--formal-dir", type=Path, required=True)
    parser.add_argument("--comparison-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = check(args.art_dir, args.formal_dir, args.comparison_dir)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"BATTLE_ART_GEOMETRY_{'PASS' if report['passed'] else 'FAIL'} checks={len(report['checks'])} output={args.output}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
