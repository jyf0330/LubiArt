from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image


GRID_ROWS = 4
GRID_COLUMNS = 4
FRAME_SIZE = 128
MAGENTA = np.array([255, 0, 255], dtype=np.uint8)

# Palette colors left by the source sheet's deep-teal staging background.
# They are removed only when connected to already-cleared background pixels,
# so similarly dark colors inside the creature remain intact.
FRINGE_COLORS = {
    (2, 68, 60),
    (7, 20, 19),
    (5, 81, 53),
    (3, 58, 19),
    (2, 65, 43),
    (4, 81, 37),
    (48, 107, 70),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Normalize the supplied crystal-shell idle sheet for generate2dsprite."
    )
    parser.add_argument("--sheet", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args()


def neighbor_mask(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    adjacent = np.zeros_like(mask)
    for y_offset in range(3):
        for x_offset in range(3):
            if x_offset == 1 and y_offset == 1:
                continue
            adjacent |= padded[
                y_offset : y_offset + mask.shape[0],
                x_offset : x_offset + mask.shape[1],
            ]
    return adjacent


def normalize_sheet(sheet: Image.Image) -> tuple[Image.Image, dict[str, object]]:
    if sheet.size != (GRID_COLUMNS * FRAME_SIZE, GRID_ROWS * FRAME_SIZE):
        raise ValueError(f"Expected a 512x512 4x4 sheet, got {sheet.size}")

    rgba = np.asarray(sheet.convert("RGBA")).copy()
    rgb = rgba[:, :, :3]
    counts = Counter(map(tuple, rgb.reshape(-1, 3).tolist()))
    background_colors = [color for color, _count in counts.most_common(2)]
    expected = {(0, 61, 62), (0, 62, 63)}
    if set(background_colors) != expected:
        raise ValueError(
            f"Unexpected staging background colors: {background_colors}; expected {sorted(expected)}"
        )

    cleared = np.zeros(rgb.shape[:2], dtype=bool)
    for color in background_colors:
        cleared |= np.all(rgb == np.array(color, dtype=np.uint8), axis=2)

    fringe_candidates = np.zeros_like(cleared)
    for color in FRINGE_COLORS:
        fringe_candidates |= np.all(rgb == np.array(color, dtype=np.uint8), axis=2)

    fringe_removed = np.zeros_like(cleared)
    while True:
        newly_removed = fringe_candidates & ~fringe_removed & neighbor_mask(cleared | fringe_removed)
        if not np.any(newly_removed):
            break
        fringe_removed |= newly_removed

    transparent = cleared | fringe_removed
    normalized = rgba.copy()
    normalized[:, :, :3][transparent] = MAGENTA
    normalized[:, :, 3] = 255

    cell_reports: list[dict[str, object]] = []
    for index in range(GRID_ROWS * GRID_COLUMNS):
        row, column = divmod(index, GRID_COLUMNS)
        x0 = column * FRAME_SIZE
        y0 = row * FRAME_SIZE
        cell_transparent = transparent[y0 : y0 + FRAME_SIZE, x0 : x0 + FRAME_SIZE]
        foreground = ~cell_transparent
        ys, xs = np.nonzero(foreground)
        bbox = None
        if xs.size:
            bbox = [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]
        cell_reports.append(
            {
                "frame": index + 1,
                "foreground_bbox": bbox,
                "foreground_pixels": int(foreground.sum()),
                "source_edge_touch": bool(
                    bbox
                    and (bbox[0] == 0 or bbox[1] == 0 or bbox[2] == FRAME_SIZE or bbox[3] == FRAME_SIZE)
                ),
            }
        )

    report = {
        "source_size": list(sheet.size),
        "grid": [GRID_ROWS, GRID_COLUMNS],
        "cell_size": [FRAME_SIZE, FRAME_SIZE],
        "background_colors": [list(color) for color in background_colors],
        "background_pixels_removed": int(cleared.sum()),
        "fringe_palette": [list(color) for color in sorted(FRINGE_COLORS)],
        "fringe_pixels_removed": int(fringe_removed.sum()),
        "cells": cell_reports,
    }
    return Image.fromarray(normalized, "RGBA"), report


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    with Image.open(args.sheet) as source_sheet:
        normalized, report = normalize_sheet(source_sheet)
    normalized.save(args.output_dir / "raw-sheet-magenta.png", optimize=True)

    with Image.open(args.reference) as reference:
        reference.convert("RGBA").save(args.output_dir / "identity-reference.png", optimize=True)

    (args.output_dir / "normalization-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
