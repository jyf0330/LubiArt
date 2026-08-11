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
AFTER_128_PATH = SOURCE_DIR / "moss_stone_wyrmling_airborne_mid_after_user_v1.png"
FIRST_FRAME_PATH = (
    ROOT
    / "output/sprite_animation_candidates/moss_stone_wyrmling/move_v1/frames/frame_001.png"
)
OUTPUT_PATH = SOURCE_DIR / "moss_stone_wyrmling_start_head_exact_block_128_v3.png"
PREVIEW_PATH = ROOT / "output/moss_stone_wyrmling_start_head_exact_block_4x_v3.png"
COMPARISON_PATH = ROOT / "output/moss_stone_wyrmling_headtop_exact_block_comparison_4x_v3.png"
BLOCK_COMPARISON_PATH = ROOT / "output/moss_stone_wyrmling_headtop_exact_block_24x_v3.png"
REPORT_PATH = (
    ROOT
    / "output/sprite_animation_candidates/_manifests/moss_stone_wyrmling/move_v2"
    / "headtop_exact_block_transfer_qa_v3.json"
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
    before_128 = fit_to_canvas(
        remove_chroma(Image.open(BEFORE_RAW_PATH).convert("RGB"))
    )
    after_128 = Image.open(AFTER_128_PATH).convert("RGBA")
    first_frame = Image.open(FIRST_FRAME_PATH).convert("RGBA")
    before_array = normalized_rgba_array(before_128)
    after_array = normalized_rgba_array(after_128)
    first_array = np.array(first_frame)

    source_diff_mask = np.any(before_array != after_array, axis=2)
    source_diff_bbox = bbox_from_mask(source_diff_mask)
    if source_diff_bbox is None:
        raise ValueError("The supplied before and after images have no visible differences")
    if int(np.sum(before_array[:, :, 3] != after_array[:, :, 3])) != 0:
        raise ValueError("The supplied edit changes alpha; refusing RGB block transfer")

    left, top, right, bottom = source_diff_bbox
    output_array = first_array.copy()
    output_array[top:bottom, left:right] = after_array[top:bottom, left:right]
    output = Image.fromarray(output_array, "RGBA")
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT_PATH, optimize=False)

    block_matches = bool(
        np.array_equal(
            output_array[top:bottom, left:right],
            after_array[top:bottom, left:right],
        )
    )
    outside_mask = np.ones((128, 128), dtype=bool)
    outside_mask[top:bottom, left:right] = False
    outside_unchanged = bool(
        np.array_equal(output_array[outside_mask], first_array[outside_mask])
    )
    actual_change_mask = np.any(output_array != first_array, axis=2)
    actual_change_bbox = bbox_from_mask(actual_change_mask)

    preview = composite_dark(output).resize((512, 512), Image.Resampling.NEAREST)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW_PATH, optimize=False)
    first_preview = composite_dark(first_frame).resize(
        (512, 512), Image.Resampling.NEAREST
    )
    comparison = Image.new("RGB", (1024, 552), (18, 18, 18))
    comparison.paste(first_preview, (0, 40))
    comparison.paste(preview, (512, 40))
    draw = ImageDraw.Draw(comparison)
    draw.text((12, 12), "FIRST FRAME BEFORE", fill=(255, 255, 255))
    draw.text((524, 12), "FULL EXACT SOURCE BLOCK", fill=(255, 255, 255))
    comparison.save(COMPARISON_PATH, optimize=False)

    after_block = after_128.crop(source_diff_bbox)
    output_block = output.crop(source_diff_bbox)
    block_scale = 24
    block_size = (
        after_block.width * block_scale,
        after_block.height * block_scale,
    )
    block_comparison = Image.new(
        "RGB", (block_size[0] * 2, block_size[1] + 40), (18, 18, 18)
    )
    block_comparison.paste(
        composite_dark(after_block).resize(block_size, Image.Resampling.NEAREST),
        (0, 40),
    )
    block_comparison.paste(
        composite_dark(output_block).resize(block_size, Image.Resampling.NEAREST),
        (block_size[0], 40),
    )
    block_draw = ImageDraw.Draw(block_comparison)
    block_draw.text((8, 12), "USER BLOCK", fill=(255, 255, 255))
    block_draw.text(
        (block_size[0] + 8, 12), "FIRST-FRAME BLOCK", fill=(255, 255, 255)
    )
    block_comparison.save(BLOCK_COMPARISON_PATH, optimize=False)

    technical_pass = (
        source_diff_bbox == (31, 35, 47, 41)
        and int(source_diff_mask.sum()) == 51
        and block_matches
        and outside_unchanged
        and first_frame.getchannel("A").tobytes()
        == output.getchannel("A").tobytes()
    )
    report = {
        "version": 3,
        "operation": "exact_full_source_diff_bounding_block_transfer",
        "before_raw": BEFORE_RAW_PATH.relative_to(ROOT).as_posix(),
        "before_raw_sha256": hashlib.sha256(BEFORE_RAW_PATH.read_bytes()).hexdigest(),
        "after_user_edit": AFTER_128_PATH.relative_to(ROOT).as_posix(),
        "after_user_edit_sha256": hashlib.sha256(AFTER_128_PATH.read_bytes()).hexdigest(),
        "first_frame_source": FIRST_FRAME_PATH.relative_to(ROOT).as_posix(),
        "first_frame_source_sha256": hashlib.sha256(FIRST_FRAME_PATH.read_bytes()).hexdigest(),
        "source_diff_pixel_count": int(source_diff_mask.sum()),
        "exact_source_block": list(source_diff_bbox),
        "exact_source_block_pixel_count": (right - left) * (bottom - top),
        "output": OUTPUT_PATH.relative_to(ROOT).as_posix(),
        "output_sha256": hashlib.sha256(OUTPUT_PATH.read_bytes()).hexdigest(),
        "actual_changed_pixel_count": int(actual_change_mask.sum()),
        "actual_changed_bbox": list(actual_change_bbox) if actual_change_bbox else None,
        "output_block_byte_identical_to_user_block": block_matches,
        "all_pixels_outside_block_byte_identical_to_first_frame": outside_unchanged,
        "first_frame_alpha_unchanged": (
            first_frame.getchannel("A").tobytes()
            == output.getchannel("A").tobytes()
        ),
        "preview": PREVIEW_PATH.relative_to(ROOT).as_posix(),
        "comparison": COMPARISON_PATH.relative_to(ROOT).as_posix(),
        "block_comparison": BLOCK_COMPARISON_PATH.relative_to(ROOT).as_posix(),
        "technical_qa_status": "PASS" if technical_pass else "BLOCKED",
        "visual_qa_status": "PENDING_USER_REVIEW",
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not technical_pass:
        raise RuntimeError(f"Exact block transfer failed; see {REPORT_PATH}")
    print(f"SOURCE_DIFF_BBOX={source_diff_bbox}")
    print(f"SOURCE_BLOCK_PIXEL_COUNT={(right-left)*(bottom-top)}")
    print(f"ACTUAL_CHANGED_PIXEL_COUNT={int(actual_change_mask.sum())}")
    print("OUTPUT_BLOCK_BYTE_IDENTICAL_TO_USER_BLOCK=YES")
    print("OUTSIDE_BLOCK_BYTE_IDENTICAL_TO_FIRST_FRAME=YES")
    print(f"OUTPUT={OUTPUT_PATH}")


if __name__ == "__main__":
    main()
