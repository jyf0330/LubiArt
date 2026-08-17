#!/usr/bin/env python3
"""Build exactly ten left-art/right-formal battle operation comparisons."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


EXPECTED_NAMES = [
    "01_battle_entry",
    "02_player_pet_hover",
    "03_player_pet_detail",
    "04_empty_floor_click",
    "05_drag_preview",
    "06_drag_cancelled",
    "07_auto_arrange_hover",
    "08_auto_arrange_complete",
    "09_begin_action_pressed",
    "10_first_round_complete",
]


def _manifest(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    names = [row["name"] for row in value.get("captures", [])]
    if value.get("captureCount") != 10 or names != EXPECTED_NAMES:
        raise ValueError(f"unexpected capture sequence in {path}: {names}")
    return value


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in (
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        try:
            return ImageFont.truetype(candidate, size=size)
        except OSError:
            pass
    return ImageFont.load_default()


def build(art_dir: Path, formal_dir: Path, output_dir: Path) -> dict:
    art = _manifest(art_dir / "capture_manifest.json")
    formal = _manifest(formal_dir / "capture_manifest.json")
    output_dir.mkdir(parents=True, exist_ok=True)
    title_font = _font(34)
    label_font = _font(25)
    rows = []
    for art_row, formal_row in zip(art["captures"], formal["captures"]):
        if art_row["name"] != formal_row["name"]:
            raise ValueError("art/formal operation names diverged")
        left = Image.open(art_dir / art_row["file"]).convert("RGB")
        right = Image.open(formal_dir / formal_row["file"]).convert("RGB")
        if left.size != (1920, 1080) or right.size != (1920, 1080):
            raise ValueError(f"unexpected screenshot size: {left.size}, {right.size}")
        header = 112
        canvas = Image.new("RGB", (3840, 1080 + header), "#11151c")
        canvas.paste(left, (0, header))
        canvas.paste(right, (1920, header))
        draw = ImageDraw.Draw(canvas)
        draw.text((32, 14), f"{art_row['step']:02d}  {art_row['operation']}", font=title_font, fill="#f7e7b4")
        draw.text((32, 66), "左：独立美术项目（Mock 离线重放）", font=label_font, fill="#c9d8ff")
        draw.text((1952, 66), "右：正式项目（LocalGameSession 权威）", font=label_font, fill="#c9ffd7")
        draw.line((1919, 0, 1919, 1192), fill="#f5c451", width=2)
        file_name = f"{art_row['step']:02d}_{art_row['name']}_comparison.png"
        canvas.save(output_dir / file_name, optimize=True)
        rows.append(
            {
                "step": art_row["step"],
                "name": art_row["name"],
                "operation": art_row["operation"],
                "file": file_name,
                "art": {k: art_row[k] for k in ("stateVersion", "stateHash", "phase", "battleRound")},
                "formal": {k: formal_row[k] for k in ("stateVersion", "stateHash", "phase", "battleRound")},
                "state_identity_match": all(
                    art_row[key] == formal_row[key]
                    for key in ("stateVersion", "stateHash", "phase", "battleRound")
                ),
            }
        )
    manifest = {
        "schemaVersion": 1,
        "layout": "left_art_mock_right_formal_authority",
        "comparisonCount": len(rows),
        "copiedMockRuntimeCode": False,
        "comparisons": rows,
    }
    (output_dir / "comparison_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--art-dir", type=Path, required=True)
    parser.add_argument("--formal-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = build(args.art_dir, args.formal_dir, args.output_dir)
    print(f"BATTLE_OPERATION_COMPARISON_PASS count={manifest['comparisonCount']} output={args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
