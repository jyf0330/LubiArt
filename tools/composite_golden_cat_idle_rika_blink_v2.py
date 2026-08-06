from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
RIKA_V1 = ROOT / "output/sprite_animations/golden_cat_idle_rika_v1"
BLINK_V1 = ROOT / "output/sprite_animations/golden_cat_idle_breath_v2"
OUTPUT_ROOT = ROOT / "output/sprite_animations/golden_cat_idle_rika_blink_v2"
FRAME_DIR = OUTPUT_ROOT / "frames"
REFERENCE_DIR = OUTPUT_ROOT / "references"
QA_DIR = OUTPUT_ROOT / "qc"

RAW_RIKA_SHEET = RIKA_V1 / "raw/output_001.png"
SHEET_PATH = OUTPUT_ROOT / "sheet-transparent.png"
OVERVIEW_PATH = OUTPUT_ROOT / "frames-overview.png"
OVERVIEW_4X_PATH = OUTPUT_ROOT / "frames-overview-4x.png"
GIF_PATH = OUTPUT_ROOT / "animation.gif"
SLOW_GIF_PATH = OUTPUT_ROOT / "slow-preview.gif"
REPORT_PATH = OUTPUT_ROOT / "QC_REPORT.json"

FRAME_SIZE = (128, 128)
BACKGROUND_KEY = (0, 63, 64)
CHROMA_DISTANCE = 45
PREVIEW_BACKGROUND = (32, 32, 32)
FRAME_DURATION_MS = 120
SLOW_DURATION_MS = 500


def save_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=False)


def color_distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> float:
    return math.sqrt(sum((left[index] - right[index]) ** 2 for index in range(3)))


def isolate_largest_component(frame: Image.Image) -> Image.Image:
    rgba = np.asarray(frame.convert("RGBA")).copy()
    mask = (rgba[:, :, 3] > 0).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    if count <= 1:
        raise ValueError("Frame has no foreground component")
    largest_label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    rgba[:, :, 3] = np.where(labels == largest_label, 255, 0).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def align_frame(frame: Image.Image) -> Image.Image:
    box = frame.getchannel("A").getbbox()
    if box is None:
        raise ValueError("Cannot align an empty frame")
    center_x = (box[0] + box[2]) / 2
    shift_x = round(64 - center_x)
    shift_y = 118 - box[3]
    aligned = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    aligned.alpha_composite(frame, (shift_x, shift_y))
    return aligned


def extract_original_rika_frame_16() -> Image.Image:
    raw = Image.open(RAW_RIKA_SHEET).convert("RGB")
    cell = raw.crop((384, 384, 512, 512))
    rgba = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    input_pixels = cell.load()
    output_pixels = rgba.load()
    for y in range(128):
        for x in range(128):
            color = input_pixels[x, y]
            alpha = 0 if color_distance(color, BACKGROUND_KEY) <= CHROMA_DISTANCE else 255
            output_pixels[x, y] = (*color, alpha)
    return align_frame(isolate_largest_component(rgba))


def make_aligned_blink_reference(path: Path) -> Image.Image:
    source = Image.open(path).convert("RGBA")
    box = source.getchannel("A").getbbox()
    if box is None:
        raise ValueError(f"Blink reference is empty: {path}")
    subject = source.crop(box)
    scale = min(100 / subject.width, 100 / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((128 - subject.width) // 2, 118 - subject.height))
    return canvas


def ellipse_mask(
    center_x: float, center_y: float, radius_x: float, radius_y: float
) -> np.ndarray:
    yy, xx = np.ogrid[:128, :128]
    return (
        ((xx - center_x) / radius_x) ** 2
        + ((yy - center_y) / radius_y) ** 2
        <= 1.0
    )


def mapped_patch(
    target: Image.Image, source: Image.Image, mask: np.ndarray
) -> Image.Image:
    target_rgba = np.asarray(target.convert("RGBA")).copy()
    source_rgba = np.asarray(source.convert("RGBA"))
    target_colors = np.unique(
        target_rgba[target_rgba[:, :, 3] > 0][:, :3], axis=0
    ).astype(np.int32)
    selected = mask & (source_rgba[:, :, 3] > 0)
    source_colors = source_rgba[selected][:, :3].astype(np.int32)
    unique_source, inverse = np.unique(source_colors, axis=0, return_inverse=True)
    mapped_unique = []
    for color in unique_source:
        distances = np.sum((target_colors - color) ** 2, axis=1)
        mapped_unique.append(target_colors[int(np.argmin(distances))])
    mapped_unique_array = np.asarray(mapped_unique, dtype=np.uint8)
    target_rgba[selected, :3] = mapped_unique_array[inverse]
    target_rgba[selected, 3] = 255
    return Image.fromarray(target_rgba, "RGBA")


def apply_blink(target: Image.Image, blink_reference: Image.Image) -> Image.Image:
    left_eye = ellipse_mask(40.5, 66.5, 15.0, 14.0)
    right_eye = ellipse_mask(70.0, 58.5, 16.0, 14.0)
    return mapped_patch(target, blink_reference, left_eye | right_eye)


def apply_closed_mouth(target: Image.Image, mouth_source: Image.Image) -> Image.Image:
    mouth = ellipse_mask(57.0, 84.0, 17.0, 10.5)
    return mapped_patch(target, mouth_source, mouth)


def compose_sheet(frames: list[Image.Image]) -> Image.Image:
    columns = 5
    rows = 4
    sheet = Image.new("RGBA", (columns * 128, rows * 128), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, ((index % columns) * 128, (index // columns) * 128))
    return sheet


def compose_preview(frame: Image.Image) -> Image.Image:
    preview = Image.new("RGB", FRAME_SIZE, PREVIEW_BACKGROUND)
    preview.paste(frame.convert("RGB"), mask=frame.getchannel("A"))
    return preview


def build_exact_palette(previews: list[Image.Image]) -> list[Image.Image]:
    colors = sorted({color for frame in previews for color in frame.get_flattened_data()})
    if len(colors) > 256:
        raise ValueError(f"Exact GIF requires no more than 256 colors; found {len(colors)}")
    color_to_index = {color: index for index, color in enumerate(colors)}
    palette = [channel for color in colors for channel in color]
    palette.extend([0] * (768 - len(palette)))
    indexed_frames = []
    for preview in previews:
        indexed = Image.new("P", preview.size)
        indexed.putpalette(palette)
        indexed.putdata([color_to_index[color] for color in preview.get_flattened_data()])
        indexed_frames.append(indexed)
    return indexed_frames


def write_verified_gif(
    previews: list[Image.Image], path: Path, duration_ms: int
) -> list[int]:
    indexed = build_exact_palette(previews)
    path.parent.mkdir(parents=True, exist_ok=True)
    indexed[0].save(
        path,
        save_all=True,
        append_images=indexed[1:],
        duration=[duration_ms] * len(indexed),
        loop=0,
        disposal=2,
        optimize=False,
    )
    decoded = Image.open(path)
    decoded_frames = [frame.convert("RGB") for frame in ImageSequence.Iterator(decoded)]
    decoded_durations = []
    for index in range(getattr(decoded, "n_frames", 1)):
        decoded.seek(index)
        decoded_durations.append(int(decoded.info.get("duration", 0)))
    if len(decoded_frames) != len(previews):
        raise ValueError(f"GIF frame count mismatch: {path}")
    if any(
        decoded_frame.tobytes() != preview.tobytes()
        for decoded_frame, preview in zip(decoded_frames, previews, strict=True)
    ):
        raise ValueError(f"GIF pixels do not exactly match preview PNGs: {path}")
    if decoded_durations != [duration_ms] * len(previews):
        raise ValueError(f"GIF durations do not match: {path}: {decoded_durations}")
    return decoded_durations


def pixel_difference(left: Image.Image, right: Image.Image) -> int:
    left_array = np.asarray(left.convert("RGBA"))
    right_array = np.asarray(right.convert("RGBA"))
    return int(np.any(left_array != right_array, axis=2).sum())


def difference_box(left: Image.Image, right: Image.Image) -> list[int] | None:
    left_array = np.asarray(left.convert("RGBA"))
    right_array = np.asarray(right.convert("RGBA"))
    mask = np.any(left_array != right_array, axis=2).astype(np.uint8) * 255
    box = Image.fromarray(mask, "L").getbbox()
    return list(box) if box is not None else None


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)
    QA_DIR.mkdir(parents=True, exist_ok=True)

    base_frames = [
        Image.open(RIKA_V1 / f"frames/frame_{index:03d}.png").convert("RGBA")
        for index in range(1, 16)
    ]
    original_frame_16 = extract_original_rika_frame_16()
    frames = base_frames + [original_frame_16, base_frames[0].copy()]

    blink_4 = make_aligned_blink_reference(BLINK_V1 / "idle-4.png")
    blink_5 = make_aligned_blink_reference(BLINK_V1 / "idle-5.png")
    save_image(blink_4, REFERENCE_DIR / "blink-reference-4-aligned.png")
    save_image(blink_5, REFERENCE_DIR / "blink-reference-5-aligned.png")

    before_10 = frames[9].copy()
    before_11 = frames[10].copy()
    closed_mouth_source = frames[11]
    frames[9] = apply_closed_mouth(frames[9], closed_mouth_source)
    frames[10] = apply_closed_mouth(frames[10], closed_mouth_source)
    frames[9] = apply_blink(frames[9], blink_4)
    frames[10] = apply_blink(frames[10], blink_5)

    frame_paths = []
    for index, frame in enumerate(frames, start=1):
        path = FRAME_DIR / f"frame_{index:03d}.png"
        save_image(frame, path)
        frame_paths.append(path)

    sheet = compose_sheet(frames)
    save_image(sheet, SHEET_PATH)
    save_image(sheet, OVERVIEW_PATH)
    save_image(
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.Resampling.NEAREST),
        OVERVIEW_4X_PATH,
    )

    previews = [compose_preview(frame) for frame in frames]
    gif_durations = write_verified_gif(previews, GIF_PATH, FRAME_DURATION_MS)
    slow_durations = write_verified_gif(previews, SLOW_GIF_PATH, SLOW_DURATION_MS)

    for index in (9, 10, 11, 12):
        save_image(
            frames[index - 1].resize((512, 512), Image.Resampling.NEAREST),
            QA_DIR / f"frame_{index:03d}_4x.png",
        )

    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("At least one final frame is empty")
    valid_boxes = [box for box in boxes if box is not None]
    edge_touch_frames = [
        index + 1
        for index, box in enumerate(valid_boxes)
        if box[0] == 0 or box[1] == 0 or box[2] == 128 or box[3] == 128
    ]
    sequential_differences = [
        pixel_difference(frames[index], frames[(index + 1) % len(frames)])
        for index in range(len(frames))
    ]
    palette_color_count = len(
        {color for frame in previews for color in frame.get_flattened_data()}
    )
    report = {
        "version": 2,
        "source_service": "Rika AI",
        "new_rika_calls": 0,
        "source_generation_id": "86ee49ce-ea8e-46e7-95b1-2bf31f511a41",
        "source_credit_change": 5,
        "frame_count": len(frames),
        "frame_size": list(FRAME_SIZE),
        "frame_paths": [path.relative_to(ROOT).as_posix() for path in frame_paths],
        "blink_sources": [
            (BLINK_V1 / "idle-4.png").relative_to(ROOT).as_posix(),
            (BLINK_V1 / "idle-5.png").relative_to(ROOT).as_posix(),
        ],
        "blink_target_frames": [10, 11],
        "mouth_replacement": {
            "target_frames": [10, 11],
            "source_frame": 12,
            "removed_source_pose": "frame_011_round_mouth",
        },
        "edited_frame_10_pixel_count": pixel_difference(before_10, frames[9]),
        "edited_frame_10_bbox": difference_box(before_10, frames[9]),
        "edited_frame_11_pixel_count": pixel_difference(before_11, frames[10]),
        "edited_frame_11_bbox": difference_box(before_11, frames[10]),
        "alpha_bounding_boxes": [list(box) for box in valid_boxes],
        "edge_touch_frames": edge_touch_frames,
        "first_last_identical": frames[0].tobytes() == frames[-1].tobytes(),
        "sequential_difference_pixels_including_loop": sequential_differences,
        "palette_color_count": palette_color_count,
        "animation_gif": {
            "path": GIF_PATH.relative_to(ROOT).as_posix(),
            "durations_ms": gif_durations,
            "exact_pixel_match": True,
            "disposal": 2,
        },
        "slow_gif": {
            "path": SLOW_GIF_PATH.relative_to(ROOT).as_posix(),
            "durations_ms": slow_durations,
            "exact_pixel_match": True,
            "disposal": 2,
        },
        "source_sheet_sha256": hashlib.sha256(RAW_RIKA_SHEET.read_bytes()).hexdigest(),
        "technical_qa_status": "PASS" if not edge_touch_frames else "BLOCKED",
        "visual_qa_status": "PENDING_MANUAL_REVIEW",
    }
    REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"FRAME_COUNT={len(frames)}")
    print(f"EDGE_TOUCH_FRAMES={edge_touch_frames}")
    print(f"FIRST_LAST_IDENTICAL={report['first_last_identical']}")
    print(f"PALETTE_COLOR_COUNT={palette_color_count}")
    print("GIF_EXACT_PIXEL_MATCH=True")
    print(f"FRAME_10_EDIT_BBOX={report['edited_frame_10_bbox']}")
    print(f"FRAME_11_EDIT_BBOX={report['edited_frame_11_bbox']}")


if __name__ == "__main__":
    main()
