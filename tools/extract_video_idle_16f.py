#!/usr/bin/env python3
"""Extract a seamless 16-frame transparent idle loop from a white-background video."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


FRAME_COUNT = 16
OUTPUT_SIZE = 128
FRAME_DURATION_MS = 170
SLOW_DURATION_MS = 340
LOOP_START_FRAME = 32
LOOP_PERIOD_FRAMES = 65
BACKGROUND_DISTANCE_THRESHOLD = 180.0
OVERVIEW_BACKGROUND = (31, 35, 42, 255)
EDGE_CHECK_LIGHT_BACKGROUND = (224, 226, 230, 255)
EDGE_CHECK_DARK_BACKGROUND = (31, 35, 42, 255)
TOP_SMOKE_SEARCH_RECT = (220, 0, 420, 165)
SMOKE_RED_RANGE = (40, 210)
SMOKE_RED_GREEN_DELTA_RANGE = (4, 30)
SMOKE_RED_BLUE_DELTA_RANGE = (4, 30)
SMOKE_GREEN_BLUE_MAX_DELTA = 8
WHITE_BACKGROUND_FLOOD_THRESHOLD = 100.0
WHITE_EDGE_DISTANCE_THRESHOLD = 90.0
WHITE_EDGE_MAX_PASSES = 4
SOURCE_MASK_EROSION_PIXELS = 2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--asset-prefix", default="anim_spr_002_idle_001")
    parser.add_argument("--sprite-id", default="SPR_002")
    parser.add_argument("--sprite-name", default="Gold Shell")
    parser.add_argument("--animation-id", default="ANIM_SPR_002_IDLE_001")
    parser.add_argument("--animation-name", default="Gold Shell Idle 001")
    parser.add_argument(
        "--remove-top-smoke",
        action="store_true",
        help="Remove detached warm-gray smoke above the subject before foreground extraction.",
    )
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_video(path: Path) -> tuple[list[np.ndarray], dict[str, object]]:
    capture = cv2.VideoCapture(str(path))
    if not capture.isOpened():
        raise RuntimeError(f"Could not open video: {path}")

    fps = float(capture.get(cv2.CAP_PROP_FPS))
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    frames: list[np.ndarray] = []
    while True:
        ok, bgr = capture.read()
        if not ok:
            break
        frames.append(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
    capture.release()

    if len(frames) < LOOP_START_FRAME + LOOP_PERIOD_FRAMES + 1:
        raise RuntimeError(
            "Video is too short for the approved loop window: "
            f"{len(frames)} frames"
        )
    return frames, {
        "frame_count": len(frames),
        "fps": fps,
        "duration_seconds": len(frames) / fps if fps else None,
        "size": [width, height],
    }


def selected_indices() -> list[int]:
    return [
        LOOP_START_FRAME + math.floor(index * LOOP_PERIOD_FRAMES / FRAME_COUNT + 0.5)
        for index in range(FRAME_COUNT)
    ]


def largest_component(mask: np.ndarray) -> np.ndarray:
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    if count <= 1:
        raise RuntimeError("No foreground component found")
    largest_label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    return np.where(labels == largest_label, 255, 0).astype(np.uint8)


def strip_near_white_boundary(frame: Image.Image) -> Image.Image:
    rgba = np.asarray(frame.convert("RGBA")).copy()
    mask = np.where(rgba[:, :, 3] > 0, 255, 0).astype(np.uint8)
    rgb_float = rgba[:, :, :3].astype(np.float32)
    distance = np.sqrt(np.sum((255.0 - rgb_float) ** 2, axis=2))
    kernel = np.ones((3, 3), dtype=np.uint8)

    for _ in range(WHITE_EDGE_MAX_PASSES):
        eroded = cv2.erode(mask, kernel, iterations=1)
        boundary = (mask > 0) & (eroded == 0)
        remove = boundary & (distance < WHITE_EDGE_DISTANCE_THRESHOLD)
        if not np.any(remove):
            break
        mask[remove] = 0

    mask = largest_component(mask)
    rgba[mask == 0] = 0
    return Image.fromarray(rgba, "RGBA")


def disconnect_top_smoke(rgb: np.ndarray, subject: np.ndarray) -> np.ndarray:
    """Cut only the warm-gray smoke bridge so the body remains the largest component."""
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    red_green_delta = red - green
    red_blue_delta = red - blue

    smoke_color = (
        (red >= SMOKE_RED_RANGE[0])
        & (red <= SMOKE_RED_RANGE[1])
        & (red_green_delta >= SMOKE_RED_GREEN_DELTA_RANGE[0])
        & (red_green_delta <= SMOKE_RED_GREEN_DELTA_RANGE[1])
        & (red_blue_delta >= SMOKE_RED_BLUE_DELTA_RANGE[0])
        & (red_blue_delta <= SMOKE_RED_BLUE_DELTA_RANGE[1])
        & (np.abs(green - blue) <= SMOKE_GREEN_BLUE_MAX_DELTA)
    )
    left, top, right, bottom = TOP_SMOKE_SEARCH_RECT
    search_area = np.zeros(subject.shape, dtype=bool)
    search_area[top:bottom, left:right] = True

    disconnected = subject.copy()
    disconnected[(subject > 0) & search_area & smoke_color] = 0
    return disconnected


def remove_white_background(
    rgb: np.ndarray,
    *,
    remove_top_smoke: bool = False,
) -> Image.Image:
    if remove_top_smoke:
        border = np.concatenate(
            [
                rgb[:8].reshape(-1, 3),
                rgb[-8:].reshape(-1, 3),
                rgb[:, :8].reshape(-1, 3),
                rgb[:, -8:].reshape(-1, 3),
            ]
        )
        background_color = np.median(border, axis=0).astype(np.float32)
        distance = np.sqrt(
            np.sum(
                (rgb.astype(np.float32) - background_color) ** 2,
                axis=2,
            )
        )
        passable_background = np.where(
            distance <= WHITE_BACKGROUND_FLOOD_THRESHOLD,
            255,
            0,
        ).astype(np.uint8)
        _, labels, _, _ = cv2.connectedComponentsWithStats(
            passable_background,
            connectivity=8,
        )
        border_labels = np.unique(
            np.concatenate(
                [labels[0], labels[-1], labels[:, 0], labels[:, -1]]
            )
        )
        subject = np.where(~np.isin(labels, border_labels), 255, 0).astype(np.uint8)
        subject = disconnect_top_smoke(rgb, subject)
        body_component = largest_component(subject)
        contours, _ = cv2.findContours(
            body_component,
            cv2.RETR_EXTERNAL,
            cv2.CHAIN_APPROX_SIMPLE,
        )
        silhouette = np.zeros_like(body_component)
        cv2.drawContours(silhouette, contours, -1, 255, thickness=cv2.FILLED)
        silhouette = cv2.erode(
            silhouette,
            np.ones((3, 3), dtype=np.uint8),
            iterations=SOURCE_MASK_EROSION_PIXELS,
        )

        rgba = np.zeros((*rgb.shape[:2], 4), dtype=np.uint8)
        foreground = silhouette > 0
        rgba[foreground, :3] = rgb[foreground]
        rgba[foreground, 3] = 255

        full_frame = Image.fromarray(rgba, "RGBA").resize(
            (OUTPUT_SIZE, OUTPUT_SIZE), resample=Image.Resampling.NEAREST
        )
        return strip_near_white_boundary(full_frame)

    rgb_float = rgb.astype(np.float32)
    distance = np.sqrt(np.sum((255.0 - rgb_float) ** 2, axis=2))
    seed = np.where(distance >= BACKGROUND_DISTANCE_THRESHOLD, 255, 0).astype(np.uint8)
    seed = cv2.morphologyEx(
        seed,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3)),
    )
    component = largest_component(seed)

    contours, _ = cv2.findContours(component, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    silhouette = np.zeros_like(component)
    cv2.drawContours(silhouette, contours, -1, 255, thickness=cv2.FILLED)

    rgba = np.zeros((*rgb.shape[:2], 4), dtype=np.uint8)
    foreground = silhouette > 0
    rgba[foreground, :3] = rgb[foreground]
    rgba[foreground, 3] = 255

    full_frame = Image.fromarray(rgba, "RGBA")
    return full_frame.resize(
        (OUTPUT_SIZE, OUTPUT_SIZE),
        resample=Image.Resampling.NEAREST,
    )


def lock_footline(frames: list[Image.Image]) -> list[Image.Image]:
    bboxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(bbox is None for bbox in bboxes):
        raise RuntimeError("Cannot align an empty frame")
    target_bottom = max(bbox[3] for bbox in bboxes if bbox is not None)
    aligned: list[Image.Image] = []
    for frame, bbox in zip(frames, bboxes, strict=True):
        assert bbox is not None
        offset_y = target_bottom - bbox[3]
        canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
        canvas.alpha_composite(frame, (0, offset_y))
        aligned.append(canvas)
    return aligned


def make_shared_palette(frames: list[Image.Image]) -> Image.Image:
    foreground = []
    for frame in frames:
        array = np.asarray(frame.convert("RGBA"))
        foreground.append(array[array[:, :, 3] > 0, :3])
    pixels = np.concatenate(foreground, axis=0)
    source = Image.fromarray(pixels.reshape(1, -1, 3).astype(np.uint8), "RGB")
    quantized = source.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    opaque_palette = quantized.getpalette()[: 255 * 3]
    opaque_palette += [0] * (255 * 3 - len(opaque_palette))

    palette = [255, 0, 255] + opaque_palette
    palette_image = Image.new("P", (1, 1), 0)
    palette_image.putpalette(palette)
    return palette_image


def quantize_frame(frame: Image.Image, palette_image: Image.Image) -> Image.Image:
    rgba = np.asarray(frame.convert("RGBA"))
    rgb = rgba[:, :, :3].copy()
    transparent = rgba[:, :, 3] == 0
    rgb[transparent] = (255, 0, 255)
    quantized = Image.fromarray(rgb, "RGB").quantize(
        palette=palette_image,
        dither=Image.Dither.NONE,
    )
    indices = np.asarray(quantized).copy()
    indices[transparent] = 0
    if np.any((~transparent) & (indices == 0)):
        raise RuntimeError("Opaque sprite pixels used the reserved transparency index")
    result = Image.fromarray(indices.astype(np.uint8), "P")
    result.putpalette(palette_image.getpalette())
    result.info["transparency"] = 0
    return result


def save_gif(path: Path, frames: list[Image.Image], duration_ms: int) -> None:
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0,
        transparency=0,
        disposal=2,
        optimize=False,
    )


def normalize_palette_frame(frame: Image.Image) -> Image.Image:
    buffer = io.BytesIO()
    frame.save(buffer, format="PNG", transparency=0, optimize=True)
    buffer.seek(0)
    with Image.open(buffer) as reopened:
        reopened.load()
        return reopened.copy()


def build_transparent_sheet(frames: list[Image.Image], path: Path) -> None:
    sheet = Image.new("RGBA", (OUTPUT_SIZE * 4, OUTPUT_SIZE * 4), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = (index % 4) * OUTPUT_SIZE
        y = (index // 4) * OUTPUT_SIZE
        sheet.alpha_composite(frame.convert("RGBA"), (x, y))
    sheet.save(path, optimize=True)


def build_overview(frames: list[Image.Image], path: Path) -> None:
    scale = 4
    columns = 4
    rows = 4
    gap = 24
    margin = 24
    label_height = 24
    cell = OUTPUT_SIZE * scale
    width = margin * 2 + columns * cell + (columns - 1) * gap
    height = margin * 2 + rows * (cell + label_height) + (rows - 1) * gap
    overview = Image.new("RGBA", (width, height), OVERVIEW_BACKGROUND)
    draw = ImageDraw.Draw(overview)
    for index, frame in enumerate(frames):
        row, column = divmod(index, columns)
        x = margin + column * (cell + gap)
        y = margin + row * (cell + label_height + gap)
        draw.text((x, y), f"{index + 1:02d}", fill=(220, 224, 230, 255))
        enlarged = frame.convert("RGBA").resize(
            (cell, cell),
            resample=Image.Resampling.NEAREST,
        )
        overview.alpha_composite(enlarged, (x, y + label_height))
    overview.convert("RGB").save(path, optimize=True)


def build_edge_check(frames: list[Image.Image], path: Path) -> None:
    scale = 2
    columns = 4
    rows = 4
    panel_gap = 24
    margin = 16
    label_height = 24
    cell = OUTPUT_SIZE * scale
    panel_width = columns * cell
    panel_height = rows * cell
    width = margin * 2 + panel_width * 2 + panel_gap
    height = margin * 2 + label_height + panel_height
    result = Image.new("RGBA", (width, height), EDGE_CHECK_DARK_BACKGROUND)
    draw = ImageDraw.Draw(result)
    panels = [
        (EDGE_CHECK_LIGHT_BACKGROUND, "light gray"),
        (EDGE_CHECK_DARK_BACKGROUND, "dark"),
    ]
    for panel_index, (background, label) in enumerate(panels):
        panel_x = margin + panel_index * (panel_width + panel_gap)
        panel = Image.new("RGBA", (panel_width, panel_height), background)
        for index, frame in enumerate(frames):
            x = (index % columns) * cell
            y = (index // columns) * cell
            enlarged = frame.convert("RGBA").resize(
                (cell, cell),
                resample=Image.Resampling.NEAREST,
            )
            panel.alpha_composite(enlarged, (x, y))
        result.alpha_composite(panel, (panel_x, margin + label_height))
        label_fill = (32, 35, 40, 255) if panel_index == 0 else (230, 232, 236, 255)
        draw.text((panel_x, margin), label, fill=label_fill)
    result.convert("RGB").save(path, optimize=True)


def decode_gif(path: Path) -> tuple[list[Image.Image], list[int]]:
    image = Image.open(path)
    decoded: list[Image.Image] = []
    durations: list[int] = []
    try:
        for index in range(image.n_frames):
            image.seek(index)
            decoded.append(image.convert("RGBA").copy())
            durations.append(int(image.info.get("duration", 0)))
    finally:
        image.close()
    return decoded, durations


def rgba_difference(left: Image.Image, right: Image.Image) -> float:
    left_rgba = np.asarray(left.convert("RGBA"), dtype=np.float32)
    right_rgba = np.asarray(right.convert("RGBA"), dtype=np.float32)
    background = np.array(OVERVIEW_BACKGROUND, dtype=np.float32)
    left_alpha = left_rgba[:, :, 3:4] / 255.0
    right_alpha = right_rgba[:, :, 3:4] / 255.0
    left_composite = left_rgba[:, :, :3] * left_alpha + background[:3] * (1.0 - left_alpha)
    right_composite = right_rgba[:, :, :3] * right_alpha + background[:3] * (1.0 - right_alpha)
    return float(np.mean(np.abs(left_composite - right_composite)))


def verify_gif(path: Path, frames: list[Image.Image], duration_ms: int) -> dict[str, object]:
    decoded, durations = decode_gif(path)
    exact = []
    for expected, actual in zip(frames, decoded, strict=True):
        expected_rgba = np.asarray(expected.convert("RGBA"))
        actual_rgba = np.asarray(actual)
        alpha_exact = np.array_equal(expected_rgba[:, :, 3], actual_rgba[:, :, 3])
        visible = expected_rgba[:, :, 3] > 0
        visible_rgb_exact = np.array_equal(
            expected_rgba[visible, :3],
            actual_rgba[visible, :3],
        )
        exact.append(bool(alpha_exact and visible_rgb_exact))
    return {
        "decoded_frame_count": len(decoded),
        "durations_ms": durations,
        "duration_matches": durations == [duration_ms] * len(frames),
        "all_frames_exact_visible_rgba_match": all(exact),
        "per_frame_exact_visible_rgba_match": exact,
    }


def main() -> None:
    args = parse_args()
    output = args.output_dir.resolve()
    frame_directory = output / "frames"
    frame_directory.mkdir(parents=True, exist_ok=True)

    source_frames, video_meta = read_video(args.input.resolve())
    indices = selected_indices()
    cleaned = lock_footline(
        [
            remove_white_background(
                source_frames[index],
                remove_top_smoke=args.remove_top_smoke,
            )
            for index in indices
        ]
    )
    palette = make_shared_palette(cleaned)
    palette_frames = [
        normalize_palette_frame(quantize_frame(frame, palette)) for frame in cleaned
    ]

    gif_path = output / f"{args.asset_prefix}.gif"
    slow_gif_path = output / f"{args.asset_prefix}_slow.gif"
    save_gif(gif_path, palette_frames, FRAME_DURATION_MS)
    save_gif(slow_gif_path, palette_frames, SLOW_DURATION_MS)

    frame_paths: list[Path] = []
    for index, frame in enumerate(palette_frames, start=1):
        path = frame_directory / f"frame_{index:03d}.png"
        rgba = np.asarray(frame.convert("RGBA")).copy()
        rgba[rgba[:, :, 3] == 0, :3] = 0
        Image.fromarray(rgba, "RGBA").save(path, optimize=True)
        frame_paths.append(path)

    delivery_frames = []
    for path in frame_paths:
        with Image.open(path) as saved:
            saved.load()
            delivery_frames.append(saved.copy())

    overview_path = output / f"{args.asset_prefix}_overview.png"
    sheet_path = output / f"{args.asset_prefix}_sheet.png"
    edge_check_path = output / f"{args.asset_prefix}_edge_check.png"
    build_overview(delivery_frames, overview_path)
    build_transparent_sheet(delivery_frames, sheet_path)
    build_edge_check(delivery_frames, edge_check_path)

    rgba_frames = [frame.convert("RGBA") for frame in delivery_frames]
    bboxes = [frame.getchannel("A").getbbox() for frame in rgba_frames]
    if any(bbox is None for bbox in bboxes):
        raise RuntimeError("At least one delivery frame is empty")
    valid_bboxes = [bbox for bbox in bboxes if bbox is not None]
    step_differences = [
        rgba_difference(rgba_frames[index], rgba_frames[(index + 1) % FRAME_COUNT])
        for index in range(FRAME_COUNT)
    ]
    gif_verification = verify_gif(gif_path, delivery_frames, FRAME_DURATION_MS)
    slow_gif_verification = verify_gif(slow_gif_path, delivery_frames, SLOW_DURATION_MS)
    if not gif_verification["all_frames_exact_visible_rgba_match"]:
        raise RuntimeError(f"Final GIF verification failed: {gif_verification}")
    if not slow_gif_verification["all_frames_exact_visible_rgba_match"]:
        raise RuntimeError(f"Slow GIF verification failed: {slow_gif_verification}")

    alpha_values = [np.unique(np.asarray(frame)[:, :, 3]).tolist() for frame in rgba_frames]
    edge_alpha = []
    boundary_near_white = []
    foreground_component_counts = []
    for frame in rgba_frames:
        rgba = np.asarray(frame)
        alpha = rgba[:, :, 3]
        edge_alpha.append(
            int(
                np.count_nonzero(alpha[0, :])
                + np.count_nonzero(alpha[-1, :])
                + np.count_nonzero(alpha[:, 0])
                + np.count_nonzero(alpha[:, -1])
            )
        )
        mask = np.where(alpha > 0, 255, 0).astype(np.uint8)
        eroded = cv2.erode(mask, np.ones((3, 3), dtype=np.uint8), iterations=1)
        boundary = (mask > 0) & (eroded == 0)
        distance_to_white = np.sqrt(
            np.sum((255.0 - rgba[:, :, :3].astype(np.float32)) ** 2, axis=2)
        )
        boundary_near_white.append(
            {
                "distance_lt_90": int(
                    np.count_nonzero(boundary & (distance_to_white < 90.0))
                ),
                "distance_lt_120": int(
                    np.count_nonzero(boundary & (distance_to_white < 120.0))
                ),
            }
        )
        component_count, _, _, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
        foreground_component_counts.append(component_count - 1)

    if any(value != 0 for value in edge_alpha):
        raise RuntimeError(f"Canvas edge contact detected: {edge_alpha}")
    if any(value != 1 for value in foreground_component_counts):
        raise RuntimeError(
            "Detached foreground components detected: "
            f"{foreground_component_counts}"
        )

    report = {
        "sprite_id": args.sprite_id,
        "sprite_name": args.sprite_name,
        "animation_id": args.animation_id,
        "animation_name": args.animation_name,
        "source": {
            "file_name": args.input.name,
            "sha256": sha256(args.input),
            **video_meta,
        },
        "loop_selection": {
            "start_frame_zero_based": LOOP_START_FRAME,
            "period_frames": LOOP_PERIOD_FRAMES,
            "closure_reference_frame_zero_based": LOOP_START_FRAME + LOOP_PERIOD_FRAMES,
            "selected_source_frames_zero_based": indices,
            "selected_source_frames_one_based": [index + 1 for index in indices],
        },
        "output_frame_count": FRAME_COUNT,
        "frame_size": [OUTPUT_SIZE, OUTPUT_SIZE],
        "frame_duration_ms": FRAME_DURATION_MS,
        "loop_duration_ms": FRAME_DURATION_MS * FRAME_COUNT,
        "slow_preview_duration_ms": SLOW_DURATION_MS,
        "background_cleanup": {
            "method": (
                "border_connected_matte_then_smoke_disconnect_white_edge_strip_and_locked_footline"
                if args.remove_top_smoke
                else "largest_connected_nonwhite_silhouette_with_filled_interior_and_locked_footline"
            ),
            "distance_threshold": BACKGROUND_DISTANCE_THRESHOLD,
            "white_edge_distance_threshold": (
                WHITE_EDGE_DISTANCE_THRESHOLD if args.remove_top_smoke else None
            ),
            "white_background_flood_threshold": (
                WHITE_BACKGROUND_FLOOD_THRESHOLD if args.remove_top_smoke else None
            ),
            "white_edge_max_passes": (
                WHITE_EDGE_MAX_PASSES if args.remove_top_smoke else None
            ),
            "source_mask_erosion_pixels": (
                SOURCE_MASK_EROSION_PIXELS if args.remove_top_smoke else None
            ),
            "top_smoke_removed": args.remove_top_smoke,
            "top_smoke_search_rect_source_xyxy": (
                list(TOP_SMOKE_SEARCH_RECT) if args.remove_top_smoke else None
            ),
            "top_smoke_color_rule": (
                {
                    "red_range": list(SMOKE_RED_RANGE),
                    "red_green_delta_range": list(SMOKE_RED_GREEN_DELTA_RANGE),
                    "red_blue_delta_range": list(SMOKE_RED_BLUE_DELTA_RANGE),
                    "green_blue_max_delta": SMOKE_GREEN_BLUE_MAX_DELTA,
                    "fixed_geometry_erase": False,
                }
                if args.remove_top_smoke
                else None
            ),
            "alpha_values_per_frame": alpha_values,
            "opaque_edge_pixel_counts": edge_alpha,
            "all_canvas_edges_transparent": all(value == 0 for value in edge_alpha),
            "boundary_near_white_pixel_counts": boundary_near_white,
            "foreground_component_counts": foreground_component_counts,
        },
        "alpha_bboxes": valid_bboxes,
        "anchor_summary": {
            "bottom_min": min(bbox[3] for bbox in valid_bboxes),
            "bottom_max": max(bbox[3] for bbox in valid_bboxes),
            "center_x_min": min((bbox[0] + bbox[2]) / 2 for bbox in valid_bboxes),
            "center_x_max": max((bbox[0] + bbox[2]) / 2 for bbox in valid_bboxes),
        },
        "motion_continuity": {
            "composited_mean_absolute_step_differences": step_differences,
            "mean": float(np.mean(step_differences)),
            "median": float(np.median(step_differences)),
            "max": float(np.max(step_differences)),
            "wrap_step": step_differences[-1],
            "wrap_to_median_ratio": float(
                step_differences[-1] / max(float(np.median(step_differences)), 1e-6)
            ),
        },
        "gif_verification": gif_verification,
        "slow_gif_verification": slow_gif_verification,
        "outputs": {
            "overview": overview_path.name,
            "sheet": sheet_path.name,
            "edge_check": edge_check_path.name,
            "gif": gif_path.name,
            "slow_gif": slow_gif_path.name,
            "frames": [(Path("frames") / path.name).as_posix() for path in frame_paths],
        },
    }
    report_path = output / "qa_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
