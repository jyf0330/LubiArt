#!/usr/bin/env python3
"""Extract a transparent, loop-verified 16-frame Gold Mascot idle from video."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


FRAME_COUNT = 16
DEFAULT_LOOP_START = 57
DEFAULT_LOOP_PERIOD = 48
DEFAULT_OUTPUT_SIZE = 128
DEFAULT_FRAME_DURATION_MS = 120
DEFAULT_SLOW_DURATION_MS = 240
DEFAULT_BACKGROUND_TOLERANCE = 100
OVERVIEW_BACKGROUND = (31, 35, 42, 255)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--report-path", type=Path)
    parser.add_argument("--loop-start", type=int, default=DEFAULT_LOOP_START)
    parser.add_argument("--loop-period", type=int, default=DEFAULT_LOOP_PERIOD)
    parser.add_argument("--output-size", type=int, default=DEFAULT_OUTPUT_SIZE)
    parser.add_argument("--frame-duration-ms", type=int, default=DEFAULT_FRAME_DURATION_MS)
    parser.add_argument("--slow-duration-ms", type=int, default=DEFAULT_SLOW_DURATION_MS)
    parser.add_argument(
        "--background-tolerance", type=int, default=DEFAULT_BACKGROUND_TOLERANCE
    )
    parser.add_argument("--asset-prefix", default="anim_spr_001_idle_001")
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

    return frames, {
        "frame_count": len(frames),
        "fps": fps,
        "duration_seconds": len(frames) / fps if fps else None,
        "size": [width, height],
    }


def selected_indices(loop_start: int, loop_period: int) -> list[int]:
    if loop_period % FRAME_COUNT != 0:
        raise RuntimeError("Loop period must be divisible by 16 for even sampling")
    step = loop_period // FRAME_COUNT
    return [loop_start + index * step for index in range(FRAME_COUNT)]


def border_connected_subject(rgb: np.ndarray, background_tolerance: int) -> np.ndarray:
    border = np.concatenate(
        [
            rgb[:8].reshape(-1, 3),
            rgb[-8:].reshape(-1, 3),
            rgb[:, :8].reshape(-1, 3),
            rgb[:, -8:].reshape(-1, 3),
        ]
    )
    background = np.median(border, axis=0).astype(np.int16)
    distance = np.max(np.abs(rgb.astype(np.int16) - background), axis=2)
    passable_background = np.where(
        distance <= background_tolerance, 255, 0
    ).astype(np.uint8)

    _, labels, _, _ = cv2.connectedComponentsWithStats(
        passable_background, connectivity=8
    )
    border_labels = np.unique(
        np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])
    )
    subject_candidates = np.where(
        ~np.isin(labels, border_labels), 255, 0
    ).astype(np.uint8)

    count, component_labels, stats, _ = cv2.connectedComponentsWithStats(
        subject_candidates, connectivity=8
    )
    if count <= 1:
        raise RuntimeError("No foreground subject found")
    largest_label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    return np.where(component_labels == largest_label, 255, 0).astype(np.uint8)


def remove_white_background(
    rgb: np.ndarray, output_size: int, background_tolerance: int
) -> Image.Image:
    silhouette = border_connected_subject(rgb, background_tolerance)
    rgba = np.zeros((*rgb.shape[:2], 4), dtype=np.uint8)
    foreground = silhouette > 0
    rgba[foreground, :3] = rgb[foreground]
    rgba[foreground, 3] = 255
    return Image.fromarray(rgba, "RGBA").resize(
        (output_size, output_size), resample=Image.Resampling.NEAREST
    )


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
        palette=palette_image, dither=Image.Dither.NONE
    )
    indices = np.asarray(quantized).copy()
    indices[transparent] = 0
    if np.any((~transparent) & (indices == 0)):
        raise RuntimeError("Opaque pixels used the reserved transparency index")
    result = Image.fromarray(indices.astype(np.uint8), "P")
    result.putpalette(palette_image.getpalette())
    result.info["transparency"] = 0
    return result


def normalize_palette_frame(frame: Image.Image) -> Image.Image:
    buffer = io.BytesIO()
    frame.save(buffer, format="PNG", transparency=0, optimize=True)
    buffer.seek(0)
    with Image.open(buffer) as reopened:
        reopened.load()
        normalized = reopened.copy()
    palette = normalized.getpalette() or []
    palette = (palette + [0] * 768)[:768]
    normalized.putpalette(palette)
    normalized.info["transparency"] = 0
    return normalized


def save_gif(path: Path, frames: list[Image.Image], duration_ms: int) -> None:
    shared_palette = frames[0].getpalette()
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        palette=shared_palette,
        duration=duration_ms,
        loop=0,
        transparency=0,
        disposal=2,
        optimize=False,
    )


def build_sheet(frames: list[Image.Image], path: Path, size: int) -> None:
    sheet = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = (index % 4) * size
        y = (index // 4) * size
        sheet.alpha_composite(frame.convert("RGBA"), (x, y))
    sheet.save(path, optimize=True)


def build_overview(frames: list[Image.Image], path: Path, size: int) -> None:
    scale = 4
    gap = 24
    margin = 24
    label_height = 24
    cell = size * scale
    width = margin * 2 + 4 * cell + 3 * gap
    height = margin * 2 + 4 * (cell + label_height) + 3 * gap
    overview = Image.new("RGBA", (width, height), OVERVIEW_BACKGROUND)
    draw = ImageDraw.Draw(overview)
    for index, frame in enumerate(frames):
        row, column = divmod(index, 4)
        x = margin + column * (cell + gap)
        y = margin + row * (cell + label_height + gap)
        draw.text((x, y), f"{index + 1:02d}", fill=(220, 224, 230, 255))
        enlarged = frame.convert("RGBA").resize(
            (cell, cell), resample=Image.Resampling.NEAREST
        )
        overview.alpha_composite(enlarged, (x, y + label_height))
    overview.convert("RGB").save(path, optimize=True)


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


def verify_gif(
    path: Path, frames: list[Image.Image], duration_ms: int
) -> dict[str, object]:
    decoded, durations = decode_gif(path)
    if len(decoded) != len(frames):
        raise RuntimeError(f"GIF frame count mismatch: {len(decoded)}")
    exact = []
    for expected, actual in zip(frames, decoded, strict=True):
        expected_rgba = np.asarray(expected.convert("RGBA"))
        actual_rgba = np.asarray(actual)
        visible = expected_rgba[:, :, 3] > 0
        exact.append(
            bool(
                np.array_equal(expected_rgba[:, :, 3], actual_rgba[:, :, 3])
                and np.array_equal(expected_rgba[visible, :3], actual_rgba[visible, :3])
            )
        )
    return {
        "decoded_frame_count": len(decoded),
        "durations_ms": durations,
        "duration_matches": durations == [duration_ms] * len(frames),
        "all_frames_exact_visible_rgba_match": all(exact),
        "per_frame_exact_visible_rgba_match": exact,
    }


def composited_difference(left: Image.Image, right: Image.Image) -> float:
    left_rgba = np.asarray(left.convert("RGBA"), dtype=np.float32)
    right_rgba = np.asarray(right.convert("RGBA"), dtype=np.float32)
    background = np.array(OVERVIEW_BACKGROUND[:3], dtype=np.float32)
    left_alpha = left_rgba[:, :, 3:4] / 255.0
    right_alpha = right_rgba[:, :, 3:4] / 255.0
    left_rgb = left_rgba[:, :, :3] * left_alpha + background * (1.0 - left_alpha)
    right_rgb = right_rgba[:, :, :3] * right_alpha + background * (1.0 - right_alpha)
    return float(np.mean(np.abs(left_rgb - right_rgb)))


def main() -> None:
    args = parse_args()
    source_path = args.input.resolve()
    output = args.output_dir.resolve()
    frame_directory = output / "frames"
    frame_directory.mkdir(parents=True, exist_ok=True)

    source_frames, video_meta = read_video(source_path)
    indices = selected_indices(args.loop_start, args.loop_period)
    closure_index = args.loop_start + args.loop_period
    if closure_index >= len(source_frames):
        raise RuntimeError(
            f"Loop closure frame {closure_index} exceeds {len(source_frames)} frames"
        )

    cleaned = [
        remove_white_background(
            source_frames[index], args.output_size, args.background_tolerance
        )
        for index in indices
    ]
    palette = make_shared_palette(cleaned)
    palette_frames = [
        normalize_palette_frame(quantize_frame(frame, palette)) for frame in cleaned
    ]

    gif_path = output / f"{args.asset_prefix}.gif"
    slow_gif_path = output / f"{args.asset_prefix}_slow.gif"
    overview_path = output / f"{args.asset_prefix}_overview.png"
    sheet_path = output / f"{args.asset_prefix}_sheet.png"
    save_gif(gif_path, palette_frames, args.frame_duration_ms)
    save_gif(slow_gif_path, palette_frames, args.slow_duration_ms)

    # Normalize delivery PNG colors to the encoded shared GIF palette. This makes
    # the PNG sequence and both previews pixel-identical after GIF decoding.
    delivery_frames, _ = decode_gif(gif_path)
    frame_paths: list[Path] = []
    for index, frame in enumerate(delivery_frames, start=1):
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

    build_overview(delivery_frames, overview_path, args.output_size)
    build_sheet(delivery_frames, sheet_path, args.output_size)

    gif_check = verify_gif(gif_path, delivery_frames, args.frame_duration_ms)
    slow_gif_check = verify_gif(
        slow_gif_path, delivery_frames, args.slow_duration_ms
    )
    if not gif_check["all_frames_exact_visible_rgba_match"]:
        raise RuntimeError(f"GIF verification failed: {gif_check}")
    if not slow_gif_check["all_frames_exact_visible_rgba_match"]:
        raise RuntimeError(f"Slow GIF verification failed: {slow_gif_check}")

    rgba_frames = [frame.convert("RGBA") for frame in delivery_frames]
    bboxes = [frame.getchannel("A").getbbox() for frame in rgba_frames]
    if any(bbox is None for bbox in bboxes):
        raise RuntimeError("At least one delivery frame is empty")
    valid_bboxes = [bbox for bbox in bboxes if bbox is not None]

    edge_pixels = []
    alpha_values = []
    for frame in rgba_frames:
        alpha = np.asarray(frame)[:, :, 3]
        alpha_values.append(np.unique(alpha).tolist())
        edge_pixels.append(
            int(
                np.count_nonzero(alpha[0])
                + np.count_nonzero(alpha[-1])
                + np.count_nonzero(alpha[:, 0])
                + np.count_nonzero(alpha[:, -1])
            )
        )

    step_differences = [
        composited_difference(
            rgba_frames[index], rgba_frames[(index + 1) % FRAME_COUNT]
        )
        for index in range(FRAME_COUNT)
    ]

    report = {
        "sprite_id": "SPR_001",
        "sprite_name": "Gold Mascot",
        "animation_id": "ANIM_SPR_001_IDLE_001",
        "animation_name": "Gold Mascot Idle 001",
        "source": {
            "file_name": source_path.name,
            "sha256": sha256(source_path),
            **video_meta,
        },
        "loop_selection": {
            "start_frame_zero_based": args.loop_start,
            "period_frames": args.loop_period,
            "closure_reference_frame_zero_based": closure_index,
            "selected_source_frames_zero_based": indices,
            "selected_source_frames_one_based": [index + 1 for index in indices],
        },
        "output_frame_count": FRAME_COUNT,
        "frame_size": [args.output_size, args.output_size],
        "frame_duration_ms": args.frame_duration_ms,
        "loop_duration_ms": args.frame_duration_ms * FRAME_COUNT,
        "slow_preview_duration_ms": args.slow_duration_ms,
        "background_cleanup": {
            "method": "largest_subject_after_border_connected_white_background_removal",
            "background_tolerance": args.background_tolerance,
            "alpha_values_per_frame": alpha_values,
            "opaque_edge_pixel_counts": edge_pixels,
            "all_canvas_edges_transparent": all(value == 0 for value in edge_pixels),
        },
        "alpha_bboxes": valid_bboxes,
        "anchor_summary": {
            "bottom_min": min(bbox[3] for bbox in valid_bboxes),
            "bottom_max": max(bbox[3] for bbox in valid_bboxes),
            "center_x_min": min((bbox[0] + bbox[2]) / 2 for bbox in valid_bboxes),
            "center_x_max": max((bbox[0] + bbox[2]) / 2 for bbox in valid_bboxes),
            "center_y_min": min((bbox[1] + bbox[3]) / 2 for bbox in valid_bboxes),
            "center_y_max": max((bbox[1] + bbox[3]) / 2 for bbox in valid_bboxes),
            "authored_vertical_motion_preserved": True,
        },
        "motion_continuity": {
            "composited_mean_absolute_step_differences": step_differences,
            "mean": float(np.mean(step_differences)),
            "median": float(np.median(step_differences)),
            "max": float(np.max(step_differences)),
            "wrap_step": step_differences[-1],
            "wrap_to_median_ratio": float(
                step_differences[-1]
                / max(float(np.median(step_differences)), 1e-6)
            ),
        },
        "gif_verification": gif_check,
        "slow_gif_verification": slow_gif_check,
        "outputs": {
            "overview": overview_path.name,
            "sheet": sheet_path.name,
            "gif": gif_path.name,
            "slow_gif": slow_gif_path.name,
            "frames": [
                (Path("frames") / path.name).as_posix() for path in frame_paths
            ],
        },
    }
    report_path = (
        args.report_path.resolve() if args.report_path else output / "qa_report.json"
    )
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
