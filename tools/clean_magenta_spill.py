#!/usr/bin/env python3
"""Remove boundary-connected dark magenta spill from a transparent sprite sheet."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cell-size", type=int, default=128)
    parser.add_argument("--rows", type=int, default=4)
    parser.add_argument("--cols", type=int, default=4)
    return parser.parse_args()


def is_magenta_spill(red: int, green: int, blue: int, alpha: int) -> bool:
    if alpha == 0:
        return False
    return (
        green <= 55
        and min(red, blue) - green >= 20
        and abs(red - blue) <= 45
    )


def clean_frame(frame: Image.Image) -> tuple[Image.Image, int]:
    cleaned = frame.convert("RGBA")
    pixels = cleaned.load()
    width, height = cleaned.size
    spill = {
        (x, y)
        for y in range(height)
        for x in range(width)
        if is_magenta_spill(*pixels[x, y])
    }
    queue: deque[tuple[int, int]] = deque()
    connected: set[tuple[int, int]] = set()
    for x, y in spill:
        if any(
            0 <= next_x < width
            and 0 <= next_y < height
            and pixels[next_x, next_y][3] == 0
            for next_x, next_y in (
                (x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
                (x - 1, y), (x + 1, y),
                (x - 1, y + 1), (x, y + 1), (x + 1, y + 1),
            )
        ):
            connected.add((x, y))
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for next_x, next_y in (
            (x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
            (x - 1, y), (x + 1, y),
            (x - 1, y + 1), (x, y + 1), (x + 1, y + 1),
        ):
            point = (next_x, next_y)
            if point in spill and point not in connected:
                connected.add(point)
                queue.append(point)
    for x, y in connected:
        pixels[x, y] = (0, 0, 0, 0)
    return cleaned, len(connected)


def main() -> None:
    args = parse_args()
    with Image.open(args.input) as source:
        sheet = source.convert("RGBA")
    expected = (args.cols * args.cell_size, args.rows * args.cell_size)
    if sheet.size != expected:
        raise ValueError(f"Expected {expected}; found {sheet.size}")
    output = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    removed_counts: list[int] = []
    for index in range(args.rows * args.cols):
        column = index % args.cols
        row = index // args.cols
        box = (
            column * args.cell_size,
            row * args.cell_size,
            (column + 1) * args.cell_size,
            (row + 1) * args.cell_size,
        )
        cleaned, removed = clean_frame(sheet.crop(box))
        output.alpha_composite(cleaned, (box[0], box[1]))
        removed_counts.append(removed)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output, optimize=False)
    print("REMOVED_MAGENTA_SPILL=" + ",".join(str(value) for value in removed_counts))


if __name__ == "__main__":
    main()
