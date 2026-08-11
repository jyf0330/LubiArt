from __future__ import annotations

import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
VERSION_ROOT = ROOT / "output/sprite_animation_candidates/moss_stone_wyrmling/move_v2"
SOURCE_DIR = VERSION_ROOT / "source"
MANIFEST_DIR = ROOT / "output/sprite_animation_candidates/_manifests/moss_stone_wyrmling/move_v2"
RAW_PATH = SOURCE_DIR / "moss_stone_wyrmling_airborne_mid_chroma_raw_v1.png"
TRANSPARENT_HD_PATH = SOURCE_DIR / "moss_stone_wyrmling_airborne_mid_transparent_hd_v1.png"
MIDFRAME_PATH = SOURCE_DIR / "moss_stone_wyrmling_airborne_mid_128_v1.png"
PREVIEW_PATH = ROOT / "output/moss_stone_wyrmling_airborne_mid_clean_4x_v1.png"
REPORT_PATH = MANIFEST_DIR / "airborne_mid_qa_v1.json"

CANVAS_SIZE = (128, 128)
MAX_SUBJECT_SIZE = 108
PREVIEW_BACKGROUND = (28, 30, 36)


def remove_chroma(raw: Image.Image) -> Image.Image:
    rgb = np.array(raw.convert("RGB"))
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    bright_chroma = (
        (red >= 130)
        & (blue >= 130)
        & (green <= 120)
        & (red >= green + 45)
        & (blue >= green + 45)
        & (np.abs(red - blue) <= 80)
    )
    dark_chroma_fringe = (
        (red >= 70)
        & (blue >= 70)
        & (green <= 20)
        & (red >= green + 55)
        & (blue >= green + 55)
        & (np.abs(red - blue) <= 80)
    )
    chroma = bright_chroma | dark_chroma_fringe
    candidate = (~chroma).astype(np.uint8) * 255
    count, labels, stats, _ = cv2.connectedComponentsWithStats(candidate, 8)
    if count <= 1:
        raise RuntimeError("No foreground component remained after chroma removal")
    largest_label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    alpha = np.where(labels == largest_label, 255, 0).astype(np.uint8)
    rgba = np.dstack((rgb, alpha))
    return Image.fromarray(rgba, "RGBA")


def fit_to_canvas(subject: Image.Image) -> Image.Image:
    bbox = subject.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Transparent subject has no visible pixels")
    cropped = subject.crop(bbox)
    scale = min(MAX_SUBJECT_SIZE / cropped.width, MAX_SUBJECT_SIZE / cropped.height)
    size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    resized = cropped.resize(size, Image.Resampling.NEAREST)
    alpha = resized.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    resized.putalpha(alpha)
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((CANVAS_SIZE[0] - size[0]) // 2, (CANVAS_SIZE[1] - size[1]) // 2),
    )
    return canvas


def magenta_spill_count(image: Image.Image) -> int:
    return sum(
        1
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha
        and red >= 70
        and blue >= 70
        and green <= 20
        and red >= green + 55
        and blue >= green + 55
    )


def main() -> None:
    if not RAW_PATH.exists():
        raise FileNotFoundError(RAW_PATH)
    raw = Image.open(RAW_PATH).convert("RGB")
    transparent_hd = remove_chroma(raw)
    TRANSPARENT_HD_PATH.parent.mkdir(parents=True, exist_ok=True)
    transparent_hd.save(TRANSPARENT_HD_PATH, optimize=False)

    midframe = fit_to_canvas(transparent_hd)
    midframe.save(MIDFRAME_PATH, optimize=False)
    preview = Image.new("RGB", CANVAS_SIZE, PREVIEW_BACKGROUND)
    preview.paste(midframe.convert("RGB"), mask=midframe.getchannel("A"))
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    preview.resize((512, 512), Image.Resampling.NEAREST).save(
        PREVIEW_PATH, optimize=False
    )

    alpha = midframe.getchannel("A")
    bbox = alpha.getbbox()
    alpha_values = set(alpha.get_flattened_data())
    transparent_corners = all(
        alpha.getpixel(point) == 0
        for point in ((0, 0), (127, 0), (0, 127), (127, 127))
    )
    spill = magenta_spill_count(midframe)
    technical_pass = (
        bbox is not None
        and bbox[0] > 0
        and bbox[1] > 0
        and bbox[2] < 128
        and bbox[3] < 128
        and alpha_values <= {0, 255}
        and transparent_corners
        and spill == 0
    )
    report = {
        "version": 1,
        "generation_service": "built_in_image_generation",
        "generation_call_count": 1,
        "quota_or_cost": "not_exposed_by_service",
        "raw_path": RAW_PATH.relative_to(ROOT).as_posix(),
        "raw_sha256": hashlib.sha256(RAW_PATH.read_bytes()).hexdigest(),
        "transparent_hd_path": TRANSPARENT_HD_PATH.relative_to(ROOT).as_posix(),
        "midframe_path": MIDFRAME_PATH.relative_to(ROOT).as_posix(),
        "preview_path": PREVIEW_PATH.relative_to(ROOT).as_posix(),
        "canvas_size": list(CANVAS_SIZE),
        "alpha_bbox": list(bbox) if bbox else None,
        "alpha_binary": alpha_values <= {0, 255},
        "transparent_corners": transparent_corners,
        "residual_magenta_pixels": spill,
        "technical_qa_status": "PASS" if technical_pass else "BLOCKED",
        "visual_qa_status": "PENDING_USER_REVIEW",
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not technical_pass:
        raise RuntimeError(f"Midframe QA failed; see {REPORT_PATH}")
    print(f"MIDFRAME={MIDFRAME_PATH}")
    print(f"PREVIEW={PREVIEW_PATH}")
    print(f"ALPHA_BBOX={bbox}")
    print(f"RESIDUAL_MAGENTA_PIXELS={spill}")
    print("TECHNICAL_QA=PASS")


if __name__ == "__main__":
    main()
