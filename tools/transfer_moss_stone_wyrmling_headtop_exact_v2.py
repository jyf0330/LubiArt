from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from process_moss_stone_wyrmling_airborne_mid_v1 import fit_to_canvas, remove_chroma


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "output/sprite_animation_candidates/moss_stone_wyrmling/move_v2/source"
BEFORE_RAW_PATH = SOURCE_DIR / "moss_stone_wyrmling_airborne_mid_before_raw_user_v1.png"
BEFORE_128_PATH = SOURCE_DIR / "moss_stone_wyrmling_airborne_mid_before_128_v1.png"
AFTER_128_PATH = SOURCE_DIR / "moss_stone_wyrmling_airborne_mid_after_user_v1.png"
FIRST_FRAME_PATH = (
    ROOT
    / "output/sprite_animation_candidates/moss_stone_wyrmling/move_v1/frames/frame_001.png"
)
OUTPUT_PATH = SOURCE_DIR / "moss_stone_wyrmling_start_head_exact_128_v2.png"
PREVIEW_PATH = ROOT / "output/moss_stone_wyrmling_start_head_exact_4x_v2.png"
COMPARISON_PATH = ROOT / "output/moss_stone_wyrmling_headtop_exact_comparison_4x_v2.png"
REPORT_PATH = (
    ROOT
    / "output/sprite_animation_candidates/_manifests/moss_stone_wyrmling/move_v2"
    / "headtop_exact_transfer_qa_v2.json"
)

PREVIEW_BACKGROUND = (28, 30, 36)


def normalized_rgba_array(image: Image.Image) -> np.ndarray:
    rgba = np.array(image.convert("RGBA"))
    rgba[rgba[:, :, 3] == 0, :3] = 0
    return rgba


def bbox_from_mask(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(mask)
    if not len(xs):
        return None
    return int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)


def composite_dark(image: Image.Image) -> Image.Image:
    background = Image.new("RGB", image.size, PREVIEW_BACKGROUND)
    background.paste(image.convert("RGB"), mask=image.getchannel("A"))
    return background


def main() -> None:
    before_raw = Image.open(BEFORE_RAW_PATH).convert("RGB")
    before_128 = fit_to_canvas(remove_chroma(before_raw))
    before_128.save(BEFORE_128_PATH, optimize=False)
    after_128 = Image.open(AFTER_128_PATH).convert("RGBA")
    first_frame = Image.open(FIRST_FRAME_PATH).convert("RGBA")
    if before_128.size != (128, 128) or after_128.size != (128, 128):
        raise ValueError("Normalized before and edited after images must both be 128x128")
    if first_frame.size != (128, 128):
        raise ValueError("First frame must be 128x128")

    before_array = normalized_rgba_array(before_128)
    after_array = normalized_rgba_array(after_128)
    exact_diff_mask = np.any(before_array != after_array, axis=2)
    exact_diff_bbox = bbox_from_mask(exact_diff_mask)
    exact_diff_count = int(exact_diff_mask.sum())
    alpha_diff_count = int(
        np.sum(before_array[:, :, 3] != after_array[:, :, 3])
    )
    if exact_diff_count == 0:
        raise ValueError("The supplied before and after images have no visible pixel differences")
    if alpha_diff_count != 0:
        raise ValueError("The supplied edit changes alpha; refusing an RGB-only transfer")

    first_array = np.array(first_frame)
    output_array = first_array.copy()
    output_array[exact_diff_mask] = after_array[exact_diff_mask]
    output = Image.fromarray(output_array, "RGBA")
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT_PATH, optimize=False)

    actual_output_diff = np.any(first_array != output_array, axis=2)
    actual_output_diff_bbox = bbox_from_mask(actual_output_diff)
    outside_exact_mask = actual_output_diff & ~exact_diff_mask
    exact_pixels_match = bool(
        np.all(output_array[exact_diff_mask] == after_array[exact_diff_mask])
    )
    outside_pixels_unchanged = bool(
        np.all(output_array[~exact_diff_mask] == first_array[~exact_diff_mask])
    )

    preview = composite_dark(output).resize((512, 512), Image.Resampling.NEAREST)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW_PATH, optimize=False)
    before_first_preview = composite_dark(first_frame).resize(
        (512, 512), Image.Resampling.NEAREST
    )
    comparison = Image.new("RGB", (1024, 552), (18, 18, 18))
    comparison.paste(before_first_preview, (0, 40))
    comparison.paste(preview, (512, 40))
    draw = ImageDraw.Draw(comparison)
    draw.text((12, 12), "FIRST FRAME BEFORE", fill=(255, 255, 255))
    draw.text((524, 12), "EXACT 51-PIXEL TRANSFER", fill=(255, 255, 255))
    comparison.save(COMPARISON_PATH, optimize=False)

    technical_pass = (
        exact_diff_count == 51
        and exact_diff_bbox == (31, 35, 47, 41)
        and alpha_diff_count == 0
        and int(outside_exact_mask.sum()) == 0
        and exact_pixels_match
        and outside_pixels_unchanged
        and first_frame.getchannel("A").tobytes()
        == output.getchannel("A").tobytes()
    )
    report = {
        "version": 2,
        "operation": "exact_before_after_pixel_diff_transfer",
        "before_raw": BEFORE_RAW_PATH.relative_to(ROOT).as_posix(),
        "before_raw_sha256": hashlib.sha256(BEFORE_RAW_PATH.read_bytes()).hexdigest(),
        "before_normalized_128": BEFORE_128_PATH.relative_to(ROOT).as_posix(),
        "after_user_edit_128": AFTER_128_PATH.relative_to(ROOT).as_posix(),
        "after_user_edit_sha256": hashlib.sha256(AFTER_128_PATH.read_bytes()).hexdigest(),
        "first_frame_source": FIRST_FRAME_PATH.relative_to(ROOT).as_posix(),
        "first_frame_source_sha256": hashlib.sha256(FIRST_FRAME_PATH.read_bytes()).hexdigest(),
        "output": OUTPUT_PATH.relative_to(ROOT).as_posix(),
        "output_sha256": hashlib.sha256(OUTPUT_PATH.read_bytes()).hexdigest(),
        "source_diff_pixel_count": exact_diff_count,
        "source_diff_bbox": list(exact_diff_bbox) if exact_diff_bbox else None,
        "source_alpha_diff_count": alpha_diff_count,
        "actual_first_frame_changed_pixel_count": int(actual_output_diff.sum()),
        "actual_first_frame_changed_bbox": (
            list(actual_output_diff_bbox) if actual_output_diff_bbox else None
        ),
        "changed_outside_exact_source_diff_count": int(outside_exact_mask.sum()),
        "all_exact_source_diff_pixels_match_user_after": exact_pixels_match,
        "all_pixels_outside_exact_source_diff_unchanged": outside_pixels_unchanged,
        "first_frame_alpha_unchanged": (
            first_frame.getchannel("A").tobytes()
            == output.getchannel("A").tobytes()
        ),
        "preview": PREVIEW_PATH.relative_to(ROOT).as_posix(),
        "comparison": COMPARISON_PATH.relative_to(ROOT).as_posix(),
        "technical_qa_status": "PASS" if technical_pass else "BLOCKED",
        "visual_qa_status": "PENDING_MANUAL_REVIEW",
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not technical_pass:
        raise RuntimeError(f"Exact head-top transfer QA failed; see {REPORT_PATH}")
    print(f"SOURCE_DIFF_PIXEL_COUNT={exact_diff_count}")
    print(f"SOURCE_DIFF_BBOX={exact_diff_bbox}")
    print(f"ACTUAL_FIRST_FRAME_CHANGED_PIXEL_COUNT={int(actual_output_diff.sum())}")
    print(f"ACTUAL_FIRST_FRAME_CHANGED_BBOX={actual_output_diff_bbox}")
    print("OUTSIDE_EXACT_DIFF_CHANGED=0")
    print("EXACT_SOURCE_PIXELS_MATCH=YES")
    print(f"OUTPUT={OUTPUT_PATH}")


if __name__ == "__main__":
    main()
