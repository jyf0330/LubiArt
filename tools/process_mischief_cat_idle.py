from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = Path(r"C:\Users\jyf\Downloads\rika_660b791a.png")
DELIVERY_ROOT = (
    ROOT
    / "output/sprite_animation_candidates/spr_001_gold_mascot/idle/legacy_mischief_processor"
)
FRAME_ROOT = DELIVERY_ROOT / "frames"
MANIFEST_ROOT = DELIVERY_ROOT / "qa"
INTAKE_ROOT = (
    ROOT
    / "output/sprite_animation_intake/spr_001_gold_mascot/anim_001_idle_mischief_cat"
)
PROCESSOR_ROOT = INTAKE_ROOT / "processor_qc"
SKILL_PROCESSOR = (
    Path.home() / ".codex/skills/generate2dsprite/scripts/generate2dsprite.py"
)

ROWS = 4
COLS = 4
FRAME_SIZE = 128
FRAME_COUNT = ROWS * COLS
FRAME_DURATION_MS = 120
SLOW_FRAME_DURATION_MS = 360
TRANSPARENT_KEY = (255, 0, 254)
LIGHT_BACKGROUND = (224, 226, 230)
DARK_BACKGROUND = (28, 31, 38)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Clean and integrate the user-supplied Mischief Cat idle sheet."
    )
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    return parser.parse_args()


def green_background_mask(rgb: np.ndarray) -> np.ndarray:
    red = rgb[:, :, 0].astype(np.float32)
    green = rgb[:, :, 1].astype(np.float32)
    blue = rgb[:, :, 2].astype(np.float32)
    return (
        (green >= 40.0)
        & (green > red * 1.05)
        & (green > blue * 1.05)
        & ((green - np.maximum(red, blue)) >= 4.0)
    )


def keep_largest_component(alpha: np.ndarray) -> np.ndarray:
    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(
        (alpha > 0).astype(np.uint8), connectivity=8
    )
    if count <= 1:
        raise ValueError("Frame became empty after background removal")
    largest_label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    return np.where(labels == largest_label, 255, 0).astype(np.uint8)


def extract_clean_frames(source: Image.Image) -> list[Image.Image]:
    if source.size != (COLS * FRAME_SIZE, ROWS * FRAME_SIZE):
        raise ValueError(
            f"Expected a 512x512 4x4 sheet, got {source.size[0]}x{source.size[1]}"
        )
    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        row, column = divmod(index, COLS)
        cell = source.crop(
            (
                column * FRAME_SIZE,
                row * FRAME_SIZE,
                (column + 1) * FRAME_SIZE,
                (row + 1) * FRAME_SIZE,
            )
        ).convert("RGB")
        rgb = np.array(cell)
        alpha = keep_largest_component(
            np.where(green_background_mask(rgb), 0, 255).astype(np.uint8)
        )
        rgba = np.dstack((rgb, alpha))
        frames.append(Image.fromarray(rgba, "RGBA"))
    return frames


def make_shared_palette(frames: list[Image.Image]) -> list[tuple[int, int, int]]:
    visible_colors: Counter[tuple[int, int, int]] = Counter()
    for frame in frames:
        data = np.array(frame)
        visible = data[:, :, :3][data[:, :, 3] > 0]
        visible_colors.update(map(tuple, visible.tolist()))
    if len(visible_colors) <= 255:
        return [color for color, _count in visible_colors.most_common()]

    weighted_pixels = np.array(
        [color for color, count in visible_colors.items() for _ in range(count)],
        dtype=np.uint8,
    )
    sample = Image.fromarray(weighted_pixels.reshape((1, -1, 3)), "RGB")
    quantized = sample.quantize(
        colors=255,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    palette_data = quantized.getpalette()[: 255 * 3]
    return [
        tuple(palette_data[index : index + 3])
        for index in range(0, len(palette_data), 3)
    ]


def quantize_frames(
    frames: list[Image.Image], palette_colors: list[tuple[int, int, int]]
) -> list[Image.Image]:
    palette_array = np.array(palette_colors, dtype=np.int32)
    flat_palette = list(TRANSPARENT_KEY)
    for color in palette_colors:
        flat_palette.extend(color)
    flat_palette.extend([0] * (768 - len(flat_palette)))

    color_cache: dict[tuple[int, int, int], int] = {}
    result: list[Image.Image] = []
    for frame in frames:
        rgba = np.array(frame)
        indexed = np.zeros((FRAME_SIZE, FRAME_SIZE), dtype=np.uint8)
        visible_mask = rgba[:, :, 3] > 0
        for color in map(tuple, np.unique(rgba[:, :, :3][visible_mask], axis=0).tolist()):
            if color not in color_cache:
                delta = palette_array - np.array(color, dtype=np.int32)
                distances = np.sum(delta * delta, axis=1)
                color_cache[color] = 1 + int(np.argmin(distances))
            indexed[
                visible_mask & np.all(rgba[:, :, :3] == np.array(color), axis=2)
            ] = color_cache[color]
        output = Image.fromarray(indexed, "P")
        output.putpalette(flat_palette)
        output.info["transparency"] = 0
        result.append(output)
    return result


def compose_transparent_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new(
        "RGBA", (COLS * FRAME_SIZE, ROWS * FRAME_SIZE), (0, 0, 0, 0)
    )
    for index, frame in enumerate(frames):
        row, column = divmod(index, COLS)
        sheet.alpha_composite(
            frame.convert("RGBA"), (column * FRAME_SIZE, row * FRAME_SIZE)
        )
    return sheet


def save_gif(frames: list[Image.Image], path: Path, duration_ms: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    gif_frames: list[Image.Image] = []
    for source_frame in frames:
        palette = list(source_frame.getpalette() or [])
        palette = (palette + [0] * 768)[:768]
        frame = Image.new("P", source_frame.size)
        frame.putdata(list(source_frame.get_flattened_data()))
        frame.putpalette(palette)
        gif_frames.append(frame)
    gif_frames[0].save(
        path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=[duration_ms] * len(frames),
        loop=0,
        transparency=0,
        disposal=2,
        optimize=False,
    )


def verify_gif(
    frames: list[Image.Image], path: Path, duration_ms: int
) -> tuple[list[int], bool]:
    expected = [frame.convert("RGBA") for frame in frames]
    with Image.open(path) as gif:
        decoded = [frame.convert("RGBA") for frame in ImageSequence.Iterator(gif)]
        durations: list[int] = []
        for index in range(getattr(gif, "n_frames", 1)):
            gif.seek(index)
            durations.append(int(gif.info.get("duration", 0)))
    exact = len(decoded) == len(expected) and all(
        left.tobytes() == right.tobytes()
        for left, right in zip(decoded, expected, strict=True)
    )
    if not exact:
        raise ValueError(f"Decoded GIF pixels do not match delivery PNG frames: {path}")
    if durations != [duration_ms] * FRAME_COUNT:
        raise ValueError(f"Unexpected GIF durations: {durations}")
    return durations, exact


def make_overview(frames: list[Image.Image], path: Path, scale: int = 1) -> None:
    cell = FRAME_SIZE * scale
    canvas = Image.new("RGB", (COLS * cell, ROWS * cell), DARK_BACKGROUND)
    for index, frame in enumerate(frames):
        row, column = divmod(index, COLS)
        rgba = frame.convert("RGBA").resize(
            (cell, cell), Image.Resampling.NEAREST
        )
        canvas.paste(rgba.convert("RGB"), (column * cell, row * cell), rgba.getchannel("A"))
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path, optimize=False)


def checker_background(size: tuple[int, int]) -> Image.Image:
    output = Image.new("RGB", size, (52, 58, 72))
    draw = ImageDraw.Draw(output)
    tile = 16
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(83, 69, 84))
    return output


def make_edge_check(frames: list[Image.Image], path: Path) -> None:
    representative_indices = [0, 5, 10, 15]
    scale = 4
    cell = FRAME_SIZE * scale
    backgrounds = [
        Image.new("RGB", (cell, cell), LIGHT_BACKGROUND),
        Image.new("RGB", (cell, cell), DARK_BACKGROUND),
        checker_background((cell, cell)),
    ]
    canvas = Image.new("RGB", (len(representative_indices) * cell, 3 * cell))
    for row, base in enumerate(backgrounds):
        for column, frame_index in enumerate(representative_indices):
            frame = frames[frame_index].convert("RGBA").resize(
                (cell, cell), Image.Resampling.NEAREST
            )
            preview = base.copy()
            preview.paste(frame.convert("RGB"), (0, 0), frame.getchannel("A"))
            canvas.paste(preview, (column * cell, row * cell))
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path, optimize=False)


def write_processor_input(source: Image.Image, path: Path) -> None:
    rgb = np.array(source.convert("RGB"))
    rgb[green_background_mask(rgb)] = (255, 0, 255)
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgb, "RGB").save(path, optimize=False)


def run_skill_processor(processor_input: Path) -> dict:
    if not SKILL_PROCESSOR.exists():
        raise FileNotFoundError(f"generate2dsprite processor is missing: {SKILL_PROCESSOR}")
    command = [
        sys.executable,
        str(SKILL_PROCESSOR),
        "process",
        "--input",
        str(processor_input),
        "--target",
        "creature",
        "--mode",
        "idle",
        "--output-dir",
        str(PROCESSOR_ROOT),
        "--rows",
        str(ROWS),
        "--cols",
        str(COLS),
        "--cell-size",
        str(FRAME_SIZE),
        "--label-prefix",
        "idle",
        "--fit-scale",
        "0.88",
        "--align",
        "feet",
        "--shared-scale",
        "--component-mode",
        "largest",
        "--component-padding",
        "1",
        "--strict-qc",
        "--max-body-scale-cv",
        "0.08",
        "--max-anchor-y-std",
        "0.05",
        "--duration",
        str(FRAME_DURATION_MS),
    ]
    subprocess.run(command, cwd=ROOT, check=True)
    return json.loads((PROCESSOR_ROOT / "pipeline-meta.json").read_text(encoding="utf-8"))


def main() -> None:
    args = parse_args()
    source_path = args.input.resolve()
    source = Image.open(source_path).convert("RGB")

    INTAKE_ROOT.mkdir(parents=True, exist_ok=True)
    raw_copy = INTAKE_ROOT / "raw-sheet.png"
    shutil.copyfile(source_path, raw_copy)
    processor_input = INTAKE_ROOT / "raw-sheet-magenta.png"
    write_processor_input(source, processor_input)
    skill_meta = run_skill_processor(processor_input)

    unquantized_frames = extract_clean_frames(source)
    palette_colors = make_shared_palette(unquantized_frames)
    frames = quantize_frames(unquantized_frames, palette_colors)

    FRAME_ROOT.mkdir(parents=True, exist_ok=True)
    frame_paths: list[Path] = []
    for index, frame in enumerate(frames, start=1):
        frame_path = FRAME_ROOT / f"frame_{index:03d}.png"
        frame.copy().save(frame_path, transparency=0, optimize=False)
        frame_paths.append(frame_path)

    sheet = compose_transparent_sheet(frames)
    sheet_path = DELIVERY_ROOT / "anim_spr_001_idle_001_sheet.png"
    sheet.save(sheet_path, optimize=False)
    overview_path = DELIVERY_ROOT / "anim_spr_001_idle_001_overview.png"
    make_overview(frames, overview_path)
    overview_4x_path = INTAKE_ROOT / "anim_spr_001_idle_001_overview_4x.png"
    make_overview(frames, overview_4x_path, scale=4)
    edge_check_path = INTAKE_ROOT / "anim_spr_001_idle_001_edge_check.png"
    make_edge_check(frames, edge_check_path)

    gif_path = DELIVERY_ROOT / "anim_spr_001_idle_001.gif"
    slow_gif_path = DELIVERY_ROOT / "anim_spr_001_idle_001_slow.gif"
    save_gif(frames, gif_path, FRAME_DURATION_MS)
    save_gif(frames, slow_gif_path, SLOW_FRAME_DURATION_MS)
    gif_durations, gif_exact = verify_gif(frames, gif_path, FRAME_DURATION_MS)
    slow_durations, slow_exact = verify_gif(
        frames, slow_gif_path, SLOW_FRAME_DURATION_MS
    )

    rgba_frames = [frame.convert("RGBA") for frame in frames]
    boxes = [frame.getchannel("A").getbbox() for frame in rgba_frames]
    if any(box is None for box in boxes):
        raise ValueError("A delivery frame is empty")
    valid_boxes = [box for box in boxes if box is not None]
    edge_touch_frames = [
        index + 1
        for index, box in enumerate(valid_boxes)
        if box[0] == 0 or box[1] == 0 or box[2] == FRAME_SIZE or box[3] == FRAME_SIZE
    ]
    alpha_values = sorted(
        {
            alpha
            for frame in rgba_frames
            for alpha in frame.getchannel("A").get_flattened_data()
        }
    )
    if edge_touch_frames:
        raise ValueError(f"Delivery frames touch the canvas edge: {edge_touch_frames}")
    if alpha_values != [0, 255]:
        raise ValueError(f"Expected hard pixel-art alpha, got {alpha_values}")

    qa_report = {
        "version": 1,
        "asset_id": "ANIM_SPR_001_IDLE_001",
        "asset_name": "Mischief Cat Idle 001",
        "source": "user_supplied_rika_sheet",
        "source_file_name": source_path.name,
        "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "sheet": {"rows": ROWS, "cols": COLS, "size": [512, 512]},
        "frame_count": FRAME_COUNT,
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "frame_duration_ms": FRAME_DURATION_MS,
        "alpha_values": alpha_values,
        "alpha_bounding_boxes": [list(box) for box in valid_boxes],
        "body_center_x_range": [
            min((box[0] + box[2]) / 2 for box in valid_boxes),
            max((box[0] + box[2]) / 2 for box in valid_boxes),
        ],
        "footline_bottom_range": [
            min(box[3] for box in valid_boxes),
            max(box[3] for box in valid_boxes),
        ],
        "edge_touch_frames": edge_touch_frames,
        "palette_color_count_including_transparency": len(palette_colors) + 1,
        "gif": {
            "path": gif_path.relative_to(ROOT).as_posix(),
            "durations_ms": gif_durations,
            "disposal": 2,
            "decoded_pixel_and_alpha_match": gif_exact,
        },
        "slow_gif": {
            "path": slow_gif_path.relative_to(ROOT).as_posix(),
            "durations_ms": slow_durations,
            "disposal": 2,
            "decoded_pixel_and_alpha_match": slow_exact,
        },
        "delivery_frames": [path.relative_to(ROOT).as_posix() for path in frame_paths],
        "delivery_sheet": sheet_path.relative_to(ROOT).as_posix(),
        "delivery_overview": overview_path.relative_to(ROOT).as_posix(),
        "qa_overview_4x": overview_4x_path.relative_to(ROOT).as_posix(),
        "qa_edge_check": edge_check_path.relative_to(ROOT).as_posix(),
        "skill_processor": {
            "pipeline_meta": (PROCESSOR_ROOT / "pipeline-meta.json")
            .relative_to(ROOT)
            .as_posix(),
            "empty_frames": skill_meta.get("empty_frames"),
            "source_edge_touch_frames": skill_meta.get("source_edge_touch_frames"),
            "output_edge_touch_frames": skill_meta.get("output_edge_touch_frames"),
            "paste_clamped_frames": skill_meta.get("paste_clamped_frames"),
            "qc_summary": skill_meta.get("qc_summary"),
        },
        "technical_qa_status": "PASS",
        "visual_qa_status": "PENDING_GODOT_REVIEW",
        "visual_qa_notes": [],
    }
    MANIFEST_ROOT.mkdir(parents=True, exist_ok=True)
    (MANIFEST_ROOT / "qa_report.json").write_text(
        json.dumps(qa_report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (MANIFEST_ROOT / "pipeline_meta.json").write_text(
        json.dumps(skill_meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print(f"DELIVERY_ROOT={DELIVERY_ROOT}")
    print(f"FRAME_COUNT={FRAME_COUNT}")
    print(f"PALETTE_COLORS={len(palette_colors) + 1}")
    print(f"BBOX_BOTTOM_RANGE={min(box[3] for box in valid_boxes)}..{max(box[3] for box in valid_boxes)}")
    print(f"EDGE_TOUCH_FRAMES={edge_touch_frames}")
    print(f"GIF_EXACT={gif_exact}")
    print(f"SLOW_GIF_EXACT={slow_exact}")
    print(f"EDGE_CHECK={edge_check_path}")


if __name__ == "__main__":
    main()
