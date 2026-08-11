#!/usr/bin/env python3
"""Prepare the reviewed frost fox idle/move sheets for Godot.

The source art is supplied by the artist. This tool only performs deterministic
chroma cleanup, frame extraction, nearest-neighbour normalization, QA preview
assembly, and exact transparent GIF export.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageSequence


IDLE_ROWS = 3
IDLE_COLS = 4
MOVE_ROWS = 4
MOVE_COLS = 4
OUTPUT_CELL = 128
TARGET_SPAN = 107
FEET_Y = 118


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--idle-sheet", type=Path, required=True)
    parser.add_argument("--move-sheet", type=Path, required=True)
    parser.add_argument("--identity-anchor", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--qa-root", type=Path, required=True)
    parser.add_argument("--manifest-root", type=Path)
    parser.add_argument("--battle-background", type=Path, required=True)
    parser.add_argument("--idle-duration-ms", type=int, default=240)
    parser.add_argument("--move-duration-ms", type=int, default=100)
    parser.add_argument("--slow-duration-ms", type=int, default=320)
    return parser.parse_args()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def is_strong_magenta(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return (
        a > 0
        and r >= 145
        and b >= 115
        and g <= 90
        and min(r, b) - g >= 65
        and abs(r - b) <= 105
    )


def is_magenta_fringe(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a == 0:
        return True
    peak = max(r, b)
    return (
        peak >= 36
        and min(r, b) >= 28
        and g <= max(18, int(min(r, b) * 0.32))
        and abs(r - b) <= max(58, int(peak * 0.42))
    )


def is_magenta_spill(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return (
        a > 0
        and r >= 50
        and b >= 50
        and g <= 50
        and abs(r - b) <= 12
        and g < min(r, b) * 0.65
    )


def is_teal_spill(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return (
        a > 0
        and r <= 60
        and 50 <= g <= 120
        and 50 <= b <= 120
        and min(g, b) - r >= 20
        and abs(g - b) <= 15
    )


def key_idle_frame(frame: Image.Image) -> Image.Image:
    image = frame.convert("RGBA")
    pixels = list(image.get_flattened_data())
    width, height = image.size
    transparent = [pixel[3] == 0 or is_strong_magenta(pixel) for pixel in pixels]

    queue: deque[tuple[int, int]] = deque()
    visited = [False] * (width * height)
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(1, height - 1):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if visited[index]:
            continue
        visited[index] = True
        if not transparent[index] and not is_magenta_fringe(pixels[index]):
            continue
        transparent[index] = True
        for nx, ny in (
            (x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
            (x - 1, y),                     (x + 1, y),
            (x - 1, y + 1), (x, y + 1), (x + 1, y + 1),
        ):
            if 0 <= nx < width and 0 <= ny < height:
                queue.append((nx, ny))

    cleaned = []
    for index, (r, g, b, a) in enumerate(pixels):
        if transparent[index] or is_magenta_spill((r, g, b, a)):
            cleaned.append((0, 0, 0, 0))
        else:
            cleaned.append((r, g, b, 255))
    image.putdata(cleaned)
    return keep_largest_component(image)


def keep_largest_component(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    alpha = list(rgba.getchannel("A").get_flattened_data())
    visited = [False] * (width * height)
    components: list[list[int]] = []
    for start in range(width * height):
        if visited[start] or alpha[start] == 0:
            continue
        visited[start] = True
        queue = deque([start])
        component: list[int] = []
        while queue:
            index = queue.popleft()
            component.append(index)
            x = index % width
            y = index // width
            for nx, ny in (
                (x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
                (x - 1, y),                     (x + 1, y),
                (x - 1, y + 1), (x, y + 1), (x + 1, y + 1),
            ):
                if not (0 <= nx < width and 0 <= ny < height):
                    continue
                neighbor = ny * width + nx
                if not visited[neighbor] and alpha[neighbor] > 0:
                    visited[neighbor] = True
                    queue.append(neighbor)
        components.append(component)
    if not components:
        raise ValueError("Frame contains no visible subject")
    keep = set(max(components, key=len))
    pixels = list(rgba.get_flattened_data())
    rgba.putdata([
        (r, g, b, 255) if index in keep else (0, 0, 0, 0)
        for index, (r, g, b, _a) in enumerate(pixels)
    ])
    return rgba


def split_sheet(
    path: Path,
    rows: int,
    cols: int,
    clean_magenta: bool,
) -> list[Image.Image]:
    source = Image.open(path).convert("RGBA")
    if source.width % cols or source.height % rows:
        raise ValueError(
            f"{path.name} is not an exact {rows}x{cols} grid: {source.size}"
        )
    cell_width = source.width // cols
    cell_height = source.height // rows
    if cell_width != cell_height:
        raise ValueError(f"{path.name} cells are not square: {cell_width}x{cell_height}")
    frames: list[Image.Image] = []
    for index in range(rows * cols):
        row, column = divmod(index, cols)
        frame = source.crop((
            column * cell_width,
            row * cell_height,
            (column + 1) * cell_width,
            (row + 1) * cell_height,
        ))
        if clean_magenta:
            frame = key_idle_frame(frame)
        else:
            pixels = [
                (r, g, b, 255)
                if a > 0 and not is_teal_spill((r, g, b, a))
                else (0, 0, 0, 0)
                for r, g, b, a in frame.get_flattened_data()
            ]
            frame.putdata(pixels)
            frame = keep_largest_component(frame)
        frames.append(frame)
    return frames


def normalize_action(frames: list[Image.Image]) -> list[Image.Image]:
    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("Animation contains an empty frame")
    widths = [box[2] - box[0] for box in boxes if box is not None]
    heights = [box[3] - box[1] for box in boxes if box is not None]
    scale = min(TARGET_SPAN / max(widths), TARGET_SPAN / max(heights))
    normalized: list[Image.Image] = []
    for frame, box in zip(frames, boxes, strict=True):
        assert box is not None
        crop = frame.crop(box)
        size = (
            max(1, round(crop.width * scale)),
            max(1, round(crop.height * scale)),
        )
        crop = crop.resize(size, Image.Resampling.NEAREST)
        output = Image.new("RGBA", (OUTPUT_CELL, OUTPUT_CELL), (0, 0, 0, 0))
        x = round((OUTPUT_CELL - crop.width) / 2)
        y = FEET_Y - crop.height
        if x <= 0 or y <= 0 or x + crop.width >= OUTPUT_CELL or y + crop.height >= OUTPUT_CELL:
            raise ValueError(f"Normalized frame lacks safe margins: {(x, y, crop.width, crop.height)}")
        output.alpha_composite(crop, (x, y))
        normalized.append(keep_largest_component(output))
    return normalized


def component_areas(image: Image.Image) -> list[int]:
    width, height = image.size
    alpha = list(image.getchannel("A").get_flattened_data())
    visited = [False] * (width * height)
    areas: list[int] = []
    for start in range(width * height):
        if visited[start] or alpha[start] == 0:
            continue
        visited[start] = True
        queue = deque([start])
        area = 0
        while queue:
            index = queue.popleft()
            area += 1
            x = index % width
            y = index // width
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if not (0 <= nx < width and 0 <= ny < height):
                    continue
                neighbor = ny * width + nx
                if not visited[neighbor] and alpha[neighbor] > 0:
                    visited[neighbor] = True
                    queue.append(neighbor)
        areas.append(area)
    return sorted(areas, reverse=True)


def exact_palette_frames(frames: list[Image.Image]) -> list[Image.Image]:
    visible_colors = sorted({
        pixel[:3]
        for frame in frames
        for pixel in frame.get_flattened_data()
        if pixel[3] > 0
    })
    if len(visible_colors) > 255:
        raise ValueError(f"Exact transparent GIF requires <=255 visible colors; found {len(visible_colors)}")
    color_to_index = {color: index + 1 for index, color in enumerate(visible_colors)}
    palette = [0, 0, 0]
    palette.extend(channel for color in visible_colors for channel in color)
    palette.extend([0] * (768 - len(palette)))
    indexed_frames: list[Image.Image] = []
    for frame in frames:
        indexed = Image.new("P", frame.size, 0)
        indexed.putpalette(palette)
        indexed.putdata([
            0 if pixel[3] == 0 else color_to_index[pixel[:3]]
            for pixel in frame.get_flattened_data()
        ])
        indexed.info["transparency"] = 0
        indexed_frames.append(indexed)
    return indexed_frames


def write_gif(frames: list[Image.Image], path: Path, duration_ms: int) -> None:
    indexed = exact_palette_frames(frames)
    indexed[0].save(
        path,
        save_all=True,
        append_images=indexed[1:],
        duration=[duration_ms] * len(indexed),
        loop=0,
        disposal=2,
        transparency=0,
        optimize=False,
    )


def verify_gif(path: Path, frames: list[Image.Image], duration_ms: int) -> dict:
    gif = Image.open(path)
    decoded = [frame.convert("RGBA") for frame in ImageSequence.Iterator(gif)]
    durations: list[int] = []
    disposals: list[int] = []
    for index in range(getattr(gif, "n_frames", 1)):
        gif.seek(index)
        durations.append(int(gif.info.get("duration", 0)))
        disposals.append(int(getattr(gif, "disposal_method", 0)))
    per_frame = [
        source.tobytes() == restored.tobytes()
        for source, restored in zip(frames, decoded, strict=True)
    ] if len(frames) == len(decoded) else []
    return {
        "decoded_frame_count": len(decoded),
        "durations_ms": durations,
        "duration_matches": durations == [duration_ms] * len(frames),
        "disposal_methods": disposals,
        "disposal_matches": disposals == [2] * len(frames),
        "per_frame_exact_rgba_match": per_frame,
        "all_frames_exact_rgba_match": len(per_frame) == len(frames) and all(per_frame),
    }


def make_sheet(frames: list[Image.Image], cols: int) -> Image.Image:
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGBA", (OUTPUT_CELL * cols, OUTPUT_CELL * rows), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        row, column = divmod(index, cols)
        sheet.alpha_composite(frame, (column * OUTPUT_CELL, row * OUTPUT_CELL))
    return sheet


def fit_background(path: Path, size: tuple[int, int]) -> Image.Image:
    source = Image.open(path).convert("RGB")
    source_ratio = source.width / source.height
    target_ratio = size[0] / size[1]
    if source_ratio > target_ratio:
        crop_width = round(source.height * target_ratio)
        left = (source.width - crop_width) // 2
        source = source.crop((left, 0, left + crop_width, source.height))
    else:
        crop_height = round(source.width / target_ratio)
        top = (source.height - crop_height) // 2
        source = source.crop((0, top, source.width, top + crop_height))
    return source.resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def edge_check(sheet: Image.Image, battle_background: Path) -> Image.Image:
    backgrounds = [
        Image.new("RGBA", sheet.size, (232, 232, 232, 255)),
        Image.new("RGBA", sheet.size, (24, 28, 38, 255)),
        fit_background(battle_background, sheet.size),
    ]
    result = Image.new("RGBA", (sheet.width * 3, sheet.height), (0, 0, 0, 255))
    for index, background in enumerate(backgrounds):
        background.alpha_composite(sheet)
        result.alpha_composite(background, (index * sheet.width, 0))
    return result


def action_report(
    action: str,
    frames: list[Image.Image],
    rows: int,
    cols: int,
    duration_ms: int,
    source_path: Path,
    gif_verification: dict,
    processor_meta: str,
) -> dict:
    boxes = [list(frame.getchannel("A").getbbox() or (0, 0, 0, 0)) for frame in frames]
    components = [component_areas(frame) for frame in frames]
    alpha_values = sorted({
        value
        for frame in frames
        for value in frame.getchannel("A").get_flattened_data()
    })
    visible_colors = {
        pixel[:3]
        for frame in frames
        for pixel in frame.get_flattened_data()
        if pixel[3] > 0
    }
    minimum_margin = min(
        min(box[0], box[1], OUTPUT_CELL - box[2], OUTPUT_CELL - box[3])
        for box in boxes
    )
    return {
        "sprite_id": "SPR_057",
        "sprite_name": "Frost Fox",
        "runtime_pet_id": "pal_057",
        "animation_id": f"ANIM_SPR_057_{action.upper()}_001",
        "animation_name": f"Frost Fox {action.title()} 001",
        "source": {
            "file_name": source_path.name,
            "sha256": sha256(source_path),
            "size": list(Image.open(source_path).size),
            "grid": [rows, cols],
        },
        "processing": {
            "frame_order": "row_major_top_left_to_bottom_right",
            "creative_changes": "none",
            "resize_filter": "nearest_neighbor",
            "component_policy": "single largest connected body",
            "anchor": "feet",
            "feet_y": FEET_Y,
            "generate2dsprite_processor_qc": processor_meta,
        },
        "output_frame_count": len(frames),
        "frame_size": [OUTPUT_CELL, OUTPUT_CELL],
        "frame_duration_ms": duration_ms,
        "loop_duration_ms": duration_ms * len(frames),
        "alpha_values": alpha_values,
        "visible_color_count": len(visible_colors),
        "alpha_bboxes": boxes,
        "component_areas": components,
        "canvas_safety": {
            "minimum_margin_pixels": minimum_margin,
            "all_canvas_edges_transparent": all(
                box[0] > 0 and box[1] > 0 and box[2] < OUTPUT_CELL and box[3] < OUTPUT_CELL
                for box in boxes
            ),
            "single_connected_subject_per_frame": all(len(areas) == 1 for areas in components),
        },
        "anchor_summary": {
            "bottom_min": min(box[3] for box in boxes),
            "bottom_max": max(box[3] for box in boxes),
            "frame_footline_y_ratio": FEET_Y / OUTPUT_CELL,
        },
        "gif_verification": gif_verification,
        "visual_review": {
            "source_original_size": "PENDING",
            "frame_original_size_128": "PENDING",
            "nearest_neighbor_4x_overview": "PENDING",
            "sequence_overview": "PENDING",
            "light_background_edges": "PENDING",
            "dark_background_edges": "PENDING",
            "battle_background_edges": "PENDING",
            "slow_gif": "PENDING",
            "final_speed_gif": "PENDING",
            "identity_structure_and_use": "PENDING",
            "in_engine_battle_ui": "PENDING",
        },
        "status": "PENDING_VISUAL_REVIEW",
    }


def export_action(
    action: str,
    frames: list[Image.Image],
    rows: int,
    cols: int,
    duration_ms: int,
    slow_duration_ms: int,
    source_path: Path,
    output_root: Path,
    qa_root: Path,
    battle_background: Path,
) -> dict:
    animation_id = f"anim_spr_057_{action}_001"
    output_dir = output_root / f"anim_001_{action}"
    frame_dir = output_dir / "frames"
    qa_dir = qa_root / f"anim_001_{action}"
    frame_dir.mkdir(parents=True, exist_ok=True)
    qa_dir.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames, start=1):
        frame.save(frame_dir / f"frame_{index:03d}.png", optimize=False)
        frame.resize((OUTPUT_CELL * 4, OUTPUT_CELL * 4), Image.Resampling.NEAREST).save(
            qa_dir / f"frame_{index:03d}_4x.png",
            optimize=False,
        )
    sheet = make_sheet(frames, cols)
    overview_path = output_dir / f"{animation_id}_overview.png"
    gif_path = output_dir / f"{animation_id}.gif"
    sheet.save(overview_path, optimize=False)
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.Resampling.NEAREST).save(
        qa_dir / f"{animation_id}_overview_4x.png",
        optimize=False,
    )
    edge_check(sheet, battle_background).save(
        qa_dir / f"{animation_id}_edge_check.png",
        optimize=False,
    )
    write_gif(frames, gif_path, duration_ms)
    slow_gif_path = qa_dir / f"{animation_id}_slow.gif"
    write_gif(frames, slow_gif_path, slow_duration_ms)
    gif_verification = verify_gif(gif_path, frames, duration_ms)
    slow_verification = verify_gif(slow_gif_path, frames, slow_duration_ms)
    if not gif_verification["all_frames_exact_rgba_match"]:
        raise ValueError(f"{action} final GIF does not exactly decode to delivery PNGs")
    if not slow_verification["all_frames_exact_rgba_match"]:
        raise ValueError(f"{action} slow GIF does not exactly decode to delivery PNGs")
    processor_meta = (
        f"output/sprite_animation_intake/spr_057_frost_fox/"
        f"anim_001_{action}/processor_qc/pipeline-meta.json"
    )
    report = action_report(
        action,
        frames,
        rows,
        cols,
        duration_ms,
        source_path,
        gif_verification,
        processor_meta,
    )
    report["slow_gif_verification"] = slow_verification
    (qa_dir / "qa_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return report


def main() -> None:
    args = parse_args()
    idle_source = split_sheet(
        args.idle_sheet.resolve(),
        IDLE_ROWS,
        IDLE_COLS,
        clean_magenta=True,
    )
    move_source = split_sheet(
        args.move_sheet.resolve(),
        MOVE_ROWS,
        MOVE_COLS,
        clean_magenta=False,
    )
    idle_frames = normalize_action(idle_source)
    move_frames = normalize_action(move_source)
    output_root = args.output_root.resolve()
    qa_root = args.qa_root.resolve()
    reports = {
        "identity_anchor": {
            "file_name": args.identity_anchor.name,
            "sha256": sha256(args.identity_anchor.resolve()),
            "size": list(Image.open(args.identity_anchor.resolve()).size),
            "role": "identity and style anchor only",
        },
        "asset_spec": {
            "asset_type": "creature",
            "runtime_pet_id": "pal_057",
            "runtime_name": "吹雪狐",
            "use": "battle idle and auto-arrange movement",
            "view": "front three-quarter",
            "canvas": [OUTPUT_CELL, OUTPUT_CELL],
            "actual_display": "battle prefab authored 180x180 inside 1920x1080 UI",
            "subject_span_pixels": TARGET_SPAN,
            "safe_margin_pixels": OUTPUT_CELL - FEET_Y,
            "feet_y": FEET_Y,
            "visual_center": [OUTPUT_CELL // 2, FEET_Y],
            "light": "upper-left cyan-white pixel highlights",
            "value_structure": "white body, cyan midtone, blue tail shadow, dark outline",
            "outline": "project-native dark pixel outline",
            "shadow": "runtime battle prefab ground shadow; not baked into frames",
            "background": "true transparent RGBA",
            "export": "128x128 transparent PNG frames and exact transparent GIF",
        },
    }
    reports["idle"] = export_action(
        "idle",
        idle_frames,
        IDLE_ROWS,
        IDLE_COLS,
        args.idle_duration_ms,
        args.slow_duration_ms,
        args.idle_sheet.resolve(),
        output_root,
        qa_root,
        args.battle_background.resolve(),
    )
    reports["move"] = export_action(
        "move",
        move_frames,
        MOVE_ROWS,
        MOVE_COLS,
        args.move_duration_ms,
        args.slow_duration_ms,
        args.move_sheet.resolve(),
        output_root,
        qa_root,
        args.battle_background.resolve(),
    )
    if args.manifest_root is not None:
        manifest_root = args.manifest_root.resolve()
        for action in ("idle", "move"):
            manifest_dir = manifest_root / f"anim_001_{action}"
            manifest_dir.mkdir(parents=True, exist_ok=True)
            (manifest_dir / "qa_report.json").write_text(
                json.dumps(reports[action], ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
    (qa_root / "bundle_qa_report.json").write_text(
        json.dumps(reports, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"OUTPUT_ROOT={output_root}")
    print(f"QA_ROOT={qa_root}")
    for action in ("idle", "move"):
        report = reports[action]
        print(
            f"{action.upper()} frames={report['output_frame_count']} "
            f"margin={report['canvas_safety']['minimum_margin_pixels']} "
            f"colors={report['visible_color_count']} "
            f"gif_exact={report['gif_verification']['all_frames_exact_rgba_match']}"
        )


if __name__ == "__main__":
    main()
