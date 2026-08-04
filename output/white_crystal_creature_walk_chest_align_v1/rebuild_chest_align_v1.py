from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import median

from PIL import Image, ImageChops, ImageDraw


ROWS = 4
COLS = 4
CELL_SIZE = 128
FRAME_COUNT = ROWS * COLS

# Only the circled, forward-facing chest contour is normalized. The curve is
# the row-by-row median of the original 16 frames, kept as explicit versioned
# data so a rebuild cannot silently change the accepted silhouette.
CHEST_EDGE_TARGET = {
    72: 102,
    73: 100,
    74: 100,
    75: 101,
    76: 102,
    77: 103,
    78: 103,
    79: 104,
    80: 104,
    81: 104,
    82: 104,
    83: 104,
    84: 104,
    85: 105,
    86: 105,
    87: 105,
    88: 105,
    89: 104,
    90: 104,
    91: 103,
    92: 102,
    93: 102,
    94: 101,
    95: 101,
    96: 100,
}

CHEST_SEED_X = 88
CHEST_SCAN_LIMIT_X = 116
ALLOWED_CHANGE_BOX = (94, min(CHEST_EDGE_TARGET), 108, max(CHEST_EDGE_TARGET) + 1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Normalize only the chest edge of the 4x4 white crystal creature walk sheet."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("source/white_crystal_creature_walk_original_v1.png"),
    )
    parser.add_argument("--output-dir", type=Path, default=Path("."))
    return parser.parse_args()


def chest_edge(frame: Image.Image, y: int) -> int:
    alpha = frame.getchannel("A")
    if alpha.getpixel((CHEST_SEED_X, y)) == 0:
        raise ValueError(f"Chest seed is transparent at y={y}")
    x = CHEST_SEED_X
    while x + 1 < CHEST_SCAN_LIMIT_X and alpha.getpixel((x + 1, y)) > 0:
        x += 1
    return x


def align_chest(frame: Image.Image) -> tuple[Image.Image, dict[int, int]]:
    original = frame.convert("RGBA")
    edited = original.copy()
    before: dict[int, int] = {}

    for y, target_x in CHEST_EDGE_TARGET.items():
        current_x = chest_edge(original, y)
        before[y] = current_x
        if current_x == target_x:
            continue

        # Preserve each frame's own two-pixel edge treatment. Only the few
        # pixels between the old and new contour are rewritten.
        edge_band = [
            original.getpixel((current_x - 1, y)),
            original.getpixel((current_x, y)),
        ]

        if target_x > current_x:
            interior = original.getpixel((max(CHEST_SEED_X, current_x - 2), y))
            for x in range(current_x - 1, target_x - 1):
                edited.putpixel((x, y), interior)
        else:
            for x in range(target_x - 1, current_x + 1):
                edited.putpixel((x, y), (0, 0, 0, 0))

        edited.putpixel((target_x - 1, y), edge_band[0])
        edited.putpixel((target_x, y), edge_band[1])
        # Keep the new contour terminal even when a disconnected source speck
        # sat one pixel beyond it and would otherwise become newly connected.
        edited.putpixel((target_x + 1, y), (0, 0, 0, 0))

    return edited, before


def build_exact_palette(frames: list[Image.Image]) -> tuple[list[int], dict[tuple[int, int, int, int], int]]:
    colors = sorted(
        {
            pixel
            for frame in frames
            for pixel in frame.getdata()
            if pixel[3] > 0
        }
    )
    if len(colors) > 255:
        raise ValueError(f"Exact GIF palette needs <=255 opaque colors, found {len(colors)}")
    color_to_index = {color: index + 1 for index, color in enumerate(colors)}
    palette = [0, 0, 0]
    for red, green, blue, _alpha in colors:
        palette.extend((red, green, blue))
    palette.extend([0] * (768 - len(palette)))
    return palette, color_to_index


def to_exact_palette_frame(
    frame: Image.Image,
    palette: list[int],
    color_to_index: dict[tuple[int, int, int, int], int],
) -> Image.Image:
    result = Image.new("P", frame.size, color=0)
    result.putpalette(palette)
    result.putdata([0 if pixel[3] == 0 else color_to_index[pixel] for pixel in frame.getdata()])
    result.info["transparency"] = 0
    return result


def save_exact_gif(frames: list[Image.Image], path: Path, duration_ms: int) -> None:
    palette, mapping = build_exact_palette(frames)
    encoded = [to_exact_palette_frame(frame, palette, mapping) for frame in frames]
    encoded[0].save(
        path,
        save_all=True,
        append_images=encoded[1:],
        duration=[duration_ms] * len(encoded),
        loop=0,
        transparency=0,
        disposal=2,
        optimize=False,
    )


def composite_on(frame: Image.Image, color: tuple[int, int, int, int]) -> Image.Image:
    background = Image.new("RGBA", frame.size, color)
    background.alpha_composite(frame.convert("RGBA"))
    return background


def verify_gif(gif_path: Path, frames: list[Image.Image]) -> dict[str, object]:
    decoded = Image.open(gif_path)
    if decoded.n_frames != len(frames):
        raise ValueError(f"{gif_path.name}: expected {len(frames)} frames, found {decoded.n_frames}")

    backgrounds = [(238, 238, 238, 255), (42, 45, 50, 255)]
    mismatches: list[dict[str, object]] = []
    durations: list[int] = []
    for index, source in enumerate(frames):
        decoded.seek(index)
        gif_frame = decoded.convert("RGBA")
        durations.append(int(decoded.info.get("duration", 0)))
        for background in backgrounds:
            expected = composite_on(source, background)
            actual = composite_on(gif_frame, background)
            diff = ImageChops.difference(expected, actual)
            if diff.getbbox() is not None:
                mismatches.append(
                    {
                        "frame": index + 1,
                        "background": background[:3],
                        "bbox": diff.getbbox(),
                    }
                )
    if mismatches:
        raise ValueError(f"{gif_path.name}: decoded GIF differs from source PNGs: {mismatches}")
    return {
        "frame_count": decoded.n_frames,
        "durations_ms": durations,
        "pixel_match_on_light_and_dark_backgrounds": True,
    }


def make_overview(sheet: Image.Image, output_path: Path, scale: int = 1) -> None:
    background = Image.new("RGBA", sheet.size, (42, 45, 50, 255))
    background.alpha_composite(sheet)
    if scale != 1:
        background = background.resize(
            (background.width * scale, background.height * scale),
            Image.Resampling.NEAREST,
        )
    background.convert("RGB").save(output_path)


def make_chest_check(sheet: Image.Image, output_path: Path) -> None:
    crop_box = (72, 52, 118, 112)
    scale = 6
    label_height = 24
    crop_width = (crop_box[2] - crop_box[0]) * scale
    crop_height = (crop_box[3] - crop_box[1]) * scale
    canvas = Image.new(
        "RGBA",
        (COLS * (crop_width + label_height), ROWS * (crop_height + label_height)),
        (42, 45, 50, 255),
    )
    draw = ImageDraw.Draw(canvas)
    for index in range(FRAME_COUNT):
        column = index % COLS
        row = index // COLS
        frame = sheet.crop(
            (
                column * CELL_SIZE,
                row * CELL_SIZE,
                (column + 1) * CELL_SIZE,
                (row + 1) * CELL_SIZE,
            )
        )
        crop = frame.crop(crop_box)
        light_background = Image.new("RGBA", crop.size, (238, 238, 238, 255))
        light_background.alpha_composite(crop)
        crop_large = light_background.resize(
            (crop_width, crop_height), Image.Resampling.NEAREST
        )
        x = column * (crop_width + label_height)
        y = row * (crop_height + label_height) + label_height
        canvas.alpha_composite(crop_large, (x, y))
        draw.text(
            (x + 2, row * (crop_height + label_height) + 3),
            f"{index + 1:02d}",
            fill=(255, 210, 80, 255),
        )
    canvas.convert("RGB").save(output_path)


def main() -> None:
    args = parse_args()
    output_dir = args.output_dir.resolve()
    input_path = args.input if args.input.is_absolute() else (output_dir / args.input)
    frames_dir = output_dir / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)

    source_sheet = Image.open(input_path).convert("RGBA")
    expected_size = (COLS * CELL_SIZE, ROWS * CELL_SIZE)
    if source_sheet.size != expected_size:
        raise ValueError(f"Expected {expected_size}, found {source_sheet.size}")

    output_sheet = Image.new("RGBA", source_sheet.size, (0, 0, 0, 0))
    edited_frames: list[Image.Image] = []
    qa_frames: list[dict[str, object]] = []

    for index in range(FRAME_COUNT):
        column = index % COLS
        row = index // COLS
        box = (
            column * CELL_SIZE,
            row * CELL_SIZE,
            (column + 1) * CELL_SIZE,
            (row + 1) * CELL_SIZE,
        )
        source_frame = source_sheet.crop(box)
        edited_frame, before_edges = align_chest(source_frame)
        after_edges = {y: chest_edge(edited_frame, y) for y in CHEST_EDGE_TARGET}
        if after_edges != CHEST_EDGE_TARGET:
            raise ValueError(f"Frame {index + 1}: chest edge did not match target")

        diff = ImageChops.difference(source_frame, edited_frame)
        diff_bbox = diff.getbbox()
        changed_pixels: list[tuple[int, int]] = []
        if diff_bbox is not None:
            for y in range(CELL_SIZE):
                for x in range(CELL_SIZE):
                    if source_frame.getpixel((x, y)) != edited_frame.getpixel((x, y)):
                        changed_pixels.append((x, y))
        if any(
            not (
                ALLOWED_CHANGE_BOX[0] <= x < ALLOWED_CHANGE_BOX[2]
                and ALLOWED_CHANGE_BOX[1] <= y < ALLOWED_CHANGE_BOX[3]
            )
            for x, y in changed_pixels
        ):
            raise ValueError(f"Frame {index + 1}: pixel changed outside chest protection box")

        # The animated legs and feet are protected as requested.
        source_legs = source_frame.crop((0, 97, CELL_SIZE, CELL_SIZE))
        edited_legs = edited_frame.crop((0, 97, CELL_SIZE, CELL_SIZE))
        if ImageChops.difference(source_legs, edited_legs).getbbox() is not None:
            raise ValueError(f"Frame {index + 1}: leg/foot protection check failed")

        frame_path = frames_dir / f"frame_{index + 1:03d}.png"
        edited_frame.save(frame_path)
        output_sheet.alpha_composite(edited_frame, (column * CELL_SIZE, row * CELL_SIZE))
        edited_frames.append(edited_frame)
        qa_frames.append(
            {
                "frame": index + 1,
                "chest_edges_before": before_edges,
                "chest_edges_after": after_edges,
                "changed_pixel_count": len(changed_pixels),
                "changed_bbox": diff_bbox,
                "leg_and_foot_pixels_y_97_to_127_unchanged": True,
            }
        )

    sheet_path = output_dir / "white_crystal_creature_walk_sheet_chest_aligned_v1.png"
    output_sheet.save(sheet_path)
    make_overview(
        output_sheet,
        output_dir / "white_crystal_creature_walk_overview_v1.png",
    )
    make_overview(
        output_sheet,
        output_dir / "white_crystal_creature_walk_overview_4x_v1.png",
        scale=4,
    )
    make_chest_check(
        output_sheet,
        output_dir / "white_crystal_creature_walk_chest_check_6x_v1.png",
    )

    preview_path = output_dir / "white_crystal_creature_walk_preview_v1.gif"
    slow_path = output_dir / "white_crystal_creature_walk_slow_check_v1.gif"
    save_exact_gif(edited_frames, preview_path, duration_ms=100)
    save_exact_gif(edited_frames, slow_path, duration_ms=320)

    qa = {
        "input": input_path.relative_to(output_dir).as_posix(),
        "sheet": sheet_path.name,
        "grid": {"rows": ROWS, "columns": COLS, "cell_size": CELL_SIZE},
        "edit_scope": {
            "description": "Only the forward chest contour is normalized; walk poses are preserved.",
            "allowed_local_pixel_box": ALLOWED_CHANGE_BOX,
            "target_chest_edge_by_local_y": CHEST_EDGE_TARGET,
        },
        "target_edge_is_row_median_of_source_frames": all(
            target_x
            == int(median([frame["chest_edges_before"][y] for frame in qa_frames]))
            for y, target_x in CHEST_EDGE_TARGET.items()
        ),
        "frames": qa_frames,
        "normal_gif": verify_gif(preview_path, edited_frames),
        "slow_gif": verify_gif(slow_path, edited_frames),
    }
    (output_dir / "qa_report_v1.json").write_text(
        json.dumps(qa, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
