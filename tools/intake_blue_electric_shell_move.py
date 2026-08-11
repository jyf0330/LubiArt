#!/usr/bin/env python3
"""Build and verify the approved Blue Electric Shell move animation bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
FRAME_SIZE = 128
ROWS = 4
COLS = 4
FRAME_COUNT = ROWS * COLS
DEFAULT_OUTPUT = (
    ROOT
    / "output/sprite_animation_candidates/spr_003_blue_electric_shell/anim_001_move/delivery"
)
BATTLE_BACKGROUND = ROOT / "art/images/battle/map_controls/maps/grassland_morning.png"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-sheet", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--duration-ms", type=int, default=150)
    parser.add_argument("--slow-duration-ms", type=int, default=360)
    return parser.parse_args()


def connected_component_areas(alpha: Image.Image) -> list[int]:
    pixels = alpha.load()
    width, height = alpha.size
    seen: set[tuple[int, int]] = set()
    areas: list[int] = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == 0 or (x, y) in seen:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen.add((x, y))
            area = 0
            while queue:
                current_x, current_y = queue.popleft()
                area += 1
                for offset_x, offset_y in (
                    (-1, -1), (0, -1), (1, -1),
                    (-1, 0), (1, 0),
                    (-1, 1), (0, 1), (1, 1),
                ):
                    neighbor = (current_x + offset_x, current_y + offset_y)
                    if not (0 <= neighbor[0] < width and 0 <= neighbor[1] < height):
                        continue
                    if neighbor in seen or pixels[neighbor[0], neighbor[1]] == 0:
                        continue
                    seen.add(neighbor)
                    queue.append(neighbor)
            areas.append(area)
    return sorted(areas, reverse=True)


def exact_palette_frames(frames: list[Image.Image]) -> list[Image.Image]:
    visible_colors = sorted(
        {
            pixel[:3]
            for frame in frames
            for pixel in frame.get_flattened_data()
            if pixel[3] > 0
        }
    )
    if len(visible_colors) > 255:
        raise ValueError(f"Exact transparent GIF needs <=255 visible colors; found {len(visible_colors)}")
    color_to_index = {color: index + 1 for index, color in enumerate(visible_colors)}
    palette = [0, 0, 0]
    palette.extend(channel for color in visible_colors for channel in color)
    palette.extend([0] * (768 - len(palette)))
    indexed_frames: list[Image.Image] = []
    for frame in frames:
        indexed = Image.new("P", frame.size, 0)
        indexed.putpalette(palette)
        indexed.putdata(
            [
                0 if pixel[3] == 0 else color_to_index[pixel[:3]]
                for pixel in frame.get_flattened_data()
            ]
        )
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
    disposal_methods: list[int] = []
    for index in range(getattr(gif, "n_frames", 1)):
        gif.seek(index)
        durations.append(int(gif.info.get("duration", 0)))
        disposal_methods.append(int(getattr(gif, "disposal_method", 0)))
    exact: list[bool] = []
    for source, restored in zip(frames, decoded, strict=True):
        exact.append(source.tobytes() == restored.tobytes())
    return {
        "decoded_frame_count": len(decoded),
        "durations_ms": durations,
        "duration_matches": durations == [duration_ms] * FRAME_COUNT,
        "disposal_methods": disposal_methods,
        "disposal_matches": disposal_methods == [2] * FRAME_COUNT,
        "all_frames_exact_rgba_match": len(decoded) == FRAME_COUNT and all(exact),
        "per_frame_exact_rgba_match": exact,
    }


def compose_edge_check(sheet: Image.Image) -> Image.Image:
    light = Image.new("RGBA", sheet.size, (232, 232, 232, 255))
    dark = Image.new("RGBA", sheet.size, (24, 28, 38, 255))
    with Image.open(BATTLE_BACKGROUND) as background_source:
        battle = background_source.convert("RGBA").resize(sheet.size, Image.Resampling.LANCZOS)
    for background in (light, dark, battle):
        background.alpha_composite(sheet)
    result = Image.new("RGBA", (sheet.width * 3, sheet.height), (0, 0, 0, 255))
    result.alpha_composite(light, (0, 0))
    result.alpha_composite(dark, (sheet.width, 0))
    result.alpha_composite(battle, (sheet.width * 2, 0))
    return result


def main() -> None:
    args = parse_args()
    source_path = args.source_sheet.resolve()
    output_dir = args.output_dir.resolve()
    frame_dir = output_dir / "frames"
    frame_dir.mkdir(parents=True, exist_ok=True)

    with Image.open(source_path) as source_image:
        sheet = source_image.convert("RGBA")
    if sheet.size != (FRAME_SIZE * COLS, FRAME_SIZE * ROWS):
        raise ValueError(f"Expected a 512x512 4x4 sheet; found {sheet.size}")

    frames: list[Image.Image] = []
    alpha_bboxes: list[list[int]] = []
    component_areas: list[list[int]] = []
    edge_counts: list[int] = []
    for index in range(FRAME_COUNT):
        column = index % COLS
        row = index // COLS
        frame = sheet.crop(
            (
                column * FRAME_SIZE,
                row * FRAME_SIZE,
                (column + 1) * FRAME_SIZE,
                (row + 1) * FRAME_SIZE,
            )
        )
        alpha = frame.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is None:
            raise ValueError(f"Frame {index + 1} is empty")
        if set(alpha.get_flattened_data()) - {0, 255}:
            raise ValueError(f"Frame {index + 1} contains partial alpha")
        areas = connected_component_areas(alpha)
        if len(areas) != 1:
            raise ValueError(f"Frame {index + 1} has {len(areas)} visible components: {areas}")
        edge_count = sum(
            alpha.getpixel((x, 0)) > 0 or alpha.getpixel((x, FRAME_SIZE - 1)) > 0
            for x in range(FRAME_SIZE)
        ) + sum(
            alpha.getpixel((0, y)) > 0 or alpha.getpixel((FRAME_SIZE - 1, y)) > 0
            for y in range(1, FRAME_SIZE - 1)
        )
        if edge_count:
            raise ValueError(f"Frame {index + 1} touches its canvas edge")
        frames.append(frame)
        alpha_bboxes.append(list(bbox))
        component_areas.append(areas)
        edge_counts.append(edge_count)
        frame.save(frame_dir / f"frame_{index + 1:03d}.png", optimize=False)

    overview_path = output_dir / "anim_spr_003_move_001_overview.png"
    zoom_path = output_dir / "anim_spr_003_move_001_overview_4x.png"
    edge_path = output_dir / "anim_spr_003_move_001_edge_check.png"
    gif_path = output_dir / "anim_spr_003_move_001.gif"
    slow_gif_path = output_dir / "anim_spr_003_move_001_slow.gif"
    sheet.save(overview_path, optimize=False)
    sheet.resize((2048, 2048), Image.Resampling.NEAREST).save(zoom_path, optimize=False)
    compose_edge_check(sheet).save(edge_path, optimize=False)
    write_gif(frames, gif_path, args.duration_ms)
    write_gif(frames, slow_gif_path, args.slow_duration_ms)

    gif_verification = verify_gif(gif_path, frames, args.duration_ms)
    slow_gif_verification = verify_gif(slow_gif_path, frames, args.slow_duration_ms)
    if not gif_verification["all_frames_exact_rgba_match"]:
        raise ValueError("Final GIF does not decode to the exact delivery PNG frames")
    if not slow_gif_verification["all_frames_exact_rgba_match"]:
        raise ValueError("Slow GIF does not decode to the exact delivery PNG frames")

    centers_x = [(bbox[0] + bbox[2]) / 2.0 for bbox in alpha_bboxes]
    bottoms = [bbox[3] for bbox in alpha_bboxes]
    minimum_margin = min(
        min(bbox[0], bbox[1], FRAME_SIZE - bbox[2], FRAME_SIZE - bbox[3])
        for bbox in alpha_bboxes
    )
    report = {
        "sprite_id": "SPR_003",
        "sprite_name": "Blue Electric Shell",
        "runtime_pet_id": "pal_028",
        "animation_id": "ANIM_SPR_003_MOVE_001",
        "animation_name": "Blue Electric Shell Move 001",
        "source": {
            "file_name": source_path.name,
            "sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
            "size": list(sheet.size),
            "grid": [ROWS, COLS],
            "source_cell_size": [FRAME_SIZE, FRAME_SIZE],
            "alpha_values": sorted(set(sheet.getchannel("A").get_flattened_data())),
            "visible_color_count": len(
                {pixel[:3] for pixel in sheet.get_flattened_data() if pixel[3] > 0}
            ),
        },
        "processing": {
            "frame_order": "row_major_top_left_to_bottom_right",
            "resize": "none; exact 128x128 source-cell crop",
            "component_policy": "preserve the single connected subject exactly",
            "creative_changes": "none",
            "generate2dsprite_processor_qc": (
                "output/sprite_animation_intake/spr_003_blue_electric_shell/"
                "anim_001_move/processor_qc_fit/pipeline-meta.json"
            ),
        },
        "output_frame_count": FRAME_COUNT,
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "frame_duration_ms": args.duration_ms,
        "loop_duration_ms": FRAME_COUNT * args.duration_ms,
        "slow_preview_duration_ms": args.slow_duration_ms,
        "alpha_bboxes": alpha_bboxes,
        "component_areas": component_areas,
        "canvas_safety": {
            "opaque_edge_pixel_counts": edge_counts,
            "all_canvas_edges_transparent": not any(edge_counts),
            "minimum_margin_pixels": minimum_margin,
            "single_connected_subject_per_frame": all(len(areas) == 1 for areas in component_areas),
        },
        "anchor_summary": {
            "bottom_min": min(bottoms),
            "bottom_max": max(bottoms),
            "center_x_min": min(centers_x),
            "center_x_max": max(centers_x),
            "frame_footline_y_ratio": max(bottoms) / FRAME_SIZE,
        },
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
        "gif_verification": gif_verification,
        "slow_gif_verification": slow_gif_verification,
        "outputs": {
            "overview": overview_path.name,
            "zoom_overview": zoom_path.name,
            "gif": gif_path.name,
            "slow_gif": slow_gif_path.name,
            "edge_check": edge_path.name,
            "frames": [f"frames/frame_{index:03d}.png" for index in range(1, 17)],
        },
        "status": "PENDING_VISUAL_REVIEW",
    }
    (output_dir / "qa_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"OUTPUT={output_dir}")
    print(f"MINIMUM_MARGIN_PIXELS={minimum_margin}")
    print(f"BOTTOM_RANGE={min(bottoms)}..{max(bottoms)}")
    print(f"CENTER_X_RANGE={min(centers_x)}..{max(centers_x)}")
    print("GIF_EXACT_RGBA_MATCH=YES")


if __name__ == "__main__":
    main()
