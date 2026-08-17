#!/usr/bin/env python3
"""Remove chroma and near-transparent background noise from a raster asset.

The flood fill starts at the outer border, so similarly coloured pixels inside
the subject are preserved by default. Generated assets that forbid magenta in
the subject can opt into clearing enclosed key-colour islands as well. Output
uses a hard alpha edge for pixel-art assets.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--min-red-blue", type=int, default=140)
    parser.add_argument("--max-green-ratio", type=float, default=0.68)
    parser.add_argument("--max-red-blue-delta", type=int, default=100)
    parser.add_argument("--edge-cleanup-passes", type=int, default=2)
    parser.add_argument("--edge-min-red-blue", type=int, default=40)
    parser.add_argument("--edge-min-green-gap", type=int, default=20)
    parser.add_argument("--edge-max-red-blue-delta", type=int, default=120)
    parser.add_argument("--remove-enclosed-key", action="store_true")
    parser.add_argument(
        "--clear-alpha-at-or-below",
        type=int,
        default=0,
        metavar="N",
        help="clear pixels whose alpha is at or below N (0-254)",
    )
    return parser.parse_args()


def is_magenta_background(
    pixel: tuple[int, int, int, int],
    min_red_blue: int,
    max_green_ratio: float,
    max_red_blue_delta: int,
) -> bool:
    red, green, blue, _alpha = pixel
    weaker_magenta_channel = min(red, blue)
    return (
        weaker_magenta_channel >= min_red_blue
        and green <= weaker_magenta_channel * max_green_ratio
        and abs(red - blue) <= max_red_blue_delta
    )


def remove_connected_background(
    image: Image.Image,
    min_red_blue: int,
    max_green_ratio: float,
    max_red_blue_delta: int,
) -> tuple[Image.Image, int]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    queue: deque[tuple[int, int]] = deque()
    visited = bytearray(width * height)

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    cleared = 0
    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if visited[index]:
            continue
        visited[index] = 1
        if not is_magenta_background(
            pixels[x, y], min_red_blue, max_green_ratio, max_red_blue_delta
        ):
            continue
        pixels[x, y] = (0, 0, 0, 0)
        cleared += 1
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))

    return rgba, cleared


def remove_magenta_edge_spill(
    image: Image.Image,
    passes: int,
    min_red_blue: int,
    min_green_gap: int,
    max_red_blue_delta: int,
) -> int:
    pixels = image.load()
    width, height = image.size
    cleared = 0
    for _pass in range(max(0, passes)):
        alpha = image.getchannel("A")
        alpha_pixels = alpha.load()
        spill: list[tuple[int, int]] = []
        for y in range(height):
            for x in range(width):
                red, green, blue, pixel_alpha = pixels[x, y]
                if pixel_alpha == 0:
                    continue
                touches_transparency = (
                    (x > 0 and alpha_pixels[x - 1, y] == 0)
                    or (x + 1 < width and alpha_pixels[x + 1, y] == 0)
                    or (y > 0 and alpha_pixels[x, y - 1] == 0)
                    or (y + 1 < height and alpha_pixels[x, y + 1] == 0)
                )
                if not touches_transparency:
                    continue
                if (
                    red >= min_red_blue
                    and blue >= min_red_blue
                    and green + min_green_gap <= min(red, blue)
                    and abs(red - blue) <= max_red_blue_delta
                ):
                    spill.append((x, y))
        if not spill:
            break
        for x, y in set(spill):
            pixels[x, y] = (0, 0, 0, 0)
            cleared += 1
    return cleared


def remove_enclosed_key_pixels(
    image: Image.Image,
    min_red_blue: int,
    max_green_ratio: float,
    max_red_blue_delta: int,
) -> int:
    pixels = image.load()
    width, height = image.size
    cleared = 0
    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] == 0:
                continue
            if is_magenta_background(
                pixels[x, y], min_red_blue, max_green_ratio, max_red_blue_delta
            ):
                pixels[x, y] = (0, 0, 0, 0)
                cleared += 1
    return cleared


def clear_near_transparent_pixels(image: Image.Image, threshold: int) -> int:
    if threshold < 0 or threshold > 254:
        raise ValueError("--clear-alpha-at-or-below must be between 0 and 254")
    if threshold == 0:
        return 0
    pixels = image.load()
    width, height = image.size
    cleared = 0
    for y in range(height):
        for x in range(width):
            if 0 < pixels[x, y][3] <= threshold:
                pixels[x, y] = (0, 0, 0, 0)
                cleared += 1
    return cleared


def main() -> int:
    args = parse_args()
    if not args.input.is_file():
        raise FileNotFoundError(args.input)
    with Image.open(args.input) as source:
        output, background_cleared = remove_connected_background(
            source,
            args.min_red_blue,
            args.max_green_ratio,
            args.max_red_blue_delta,
        )
    alpha_noise_cleared = clear_near_transparent_pixels(
        output, args.clear_alpha_at_or_below
    )
    if background_cleared == 0 and alpha_noise_cleared == 0:
        raise ValueError("no connected magenta background pixels found")
    enclosed_cleared = 0
    if args.remove_enclosed_key:
        enclosed_cleared = remove_enclosed_key_pixels(
            output,
            args.min_red_blue,
            args.max_green_ratio,
            args.max_red_blue_delta,
        )
    edge_cleared = remove_magenta_edge_spill(
        output,
        args.edge_cleanup_passes,
        args.edge_min_red_blue,
        args.edge_min_green_gap,
        args.edge_max_red_blue_delta,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)
    alpha_bbox = output.getchannel("A").getbbox()
    print(
        "CHROMA_BACKGROUND_REMOVED "
        f"background_cleared={background_cleared} enclosed_cleared={enclosed_cleared} "
        f"edge_cleared={edge_cleared} alpha_noise_cleared={alpha_noise_cleared} "
        f"size={output.width}x{output.height} "
        f"alpha_bbox={alpha_bbox} output={args.output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
