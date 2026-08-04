from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = (
    ROOT
    / "art/images/shared/pets/animations/moss_stone_wyrmling/move_v2/source"
    / "moss_stone_wyrmling_airborne_mid_user_edit_v1.png"
)
FIRST_FRAME_PATH = (
    ROOT
    / "art/images/shared/pets/animations/moss_stone_wyrmling/move_v1/frames/frame_001.png"
)
OUTPUT_PATH = (
    ROOT
    / "art/images/shared/pets/animations/moss_stone_wyrmling/move_v2/source"
    / "moss_stone_wyrmling_start_headmatched_128_v1.png"
)
PREVIEW_PATH = ROOT / "output/moss_stone_wyrmling_start_headmatched_4x_v1.png"
COMPARISON_PATH = ROOT / "output/moss_stone_wyrmling_headtop_comparison_4x_v1.png"
REPORT_PATH = (
    ROOT
    / "art/manifests/shared/pets/animations/moss_stone_wyrmling/move_v2"
    / "headtop_transfer_qa_v1.json"
)

ROI = (24, 27, 50, 44)
SOURCE_Y_OFFSET = 2
PREVIEW_BACKGROUND = (28, 30, 36)


def green_mask(rgba: np.ndarray) -> np.ndarray:
    red = rgba[:, :, 0].astype(np.float32)
    green = rgba[:, :, 1].astype(np.float32)
    blue = rgba[:, :, 2].astype(np.float32)
    alpha = rgba[:, :, 3]
    return (
        (alpha > 0)
        & (green >= 55)
        & (green >= red * 1.15)
        & (green >= blue * 1.20)
    )


def composite_dark(image: Image.Image) -> Image.Image:
    background = Image.new("RGB", image.size, PREVIEW_BACKGROUND)
    background.paste(image.convert("RGB"), mask=image.getchannel("A"))
    return background


def transfer_headtop(source: Image.Image, target: Image.Image) -> tuple[Image.Image, np.ndarray]:
    source_rgba = np.array(source.convert("RGBA"))
    target_rgba = np.array(target.convert("RGBA"))
    result = target_rgba.copy()
    source_green = green_mask(source_rgba)
    target_green = green_mask(target_rgba)
    transfer = np.zeros(target_green.shape, dtype=bool)

    left, top, right, bottom = ROI
    for y in range(top, bottom):
        source_y = y + SOURCE_Y_OFFSET
        for x in range(left, right):
            target_pixel = target_rgba[y, x]
            source_pixel = source_rgba[source_y, x]
            target_is_head_surface = (
                target_pixel[3] > 0
                and max(target_pixel[:3]) >= 55
                and not (
                    target_pixel[2] > target_pixel[1] * 1.20
                    and target_pixel[2] > target_pixel[0] * 1.12
                )
            )
            should_transfer = target_green[y, x] or (
                source_green[source_y, x] and target_is_head_surface
            )
            if not should_transfer or source_pixel[3] == 0:
                continue
            result[y, x, :3] = source_pixel[:3]
            result[y, x, 3] = target_pixel[3]
            transfer[y, x] = True
    return Image.fromarray(result, "RGBA"), transfer


def main() -> None:
    source = Image.open(SOURCE_PATH).convert("RGBA")
    first_frame = Image.open(FIRST_FRAME_PATH).convert("RGBA")
    if source.size != (128, 128) or first_frame.size != (128, 128):
        raise ValueError("Both source and first frame must be 128x128")

    output, transfer_mask = transfer_headtop(source, first_frame)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT_PATH, optimize=False)

    output_preview = composite_dark(output).resize((512, 512), Image.Resampling.NEAREST)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    output_preview.save(PREVIEW_PATH, optimize=False)

    before_preview = composite_dark(first_frame).resize(
        (512, 512), Image.Resampling.NEAREST
    )
    comparison = Image.new("RGB", (1024, 552), (18, 18, 18))
    comparison.paste(before_preview, (0, 40))
    comparison.paste(output_preview, (512, 40))
    draw = ImageDraw.Draw(comparison)
    draw.text((12, 12), "BEFORE", fill=(255, 255, 255))
    draw.text((524, 12), "HEAD-TOP MATCHED", fill=(255, 255, 255))
    comparison.save(COMPARISON_PATH, optimize=False)

    changed_coordinates = [
        (x, y)
        for y in range(128)
        for x in range(128)
        if first_frame.getpixel((x, y)) != output.getpixel((x, y))
    ]
    difference_bbox = None
    if changed_coordinates:
        changed_x = [point[0] for point in changed_coordinates]
        changed_y = [point[1] for point in changed_coordinates]
        difference_bbox = (
            min(changed_x),
            min(changed_y),
            max(changed_x) + 1,
            max(changed_y) + 1,
        )
    changed_outside_roi = [
        (x, y)
        for x, y in changed_coordinates
        if not (ROI[0] <= x < ROI[2] and ROI[1] <= y < ROI[3])
    ]
    alpha_unchanged = (
        first_frame.getchannel("A").tobytes() == output.getchannel("A").tobytes()
    )
    technical_pass = (
        bool(changed_coordinates)
        and not changed_outside_roi
        and alpha_unchanged
        and int(transfer_mask.sum()) == len(changed_coordinates)
    )
    report = {
        "version": 1,
        "operation": "deterministic_headtop_pixel_transfer",
        "source_user_edit": SOURCE_PATH.relative_to(ROOT).as_posix(),
        "source_user_edit_sha256": hashlib.sha256(SOURCE_PATH.read_bytes()).hexdigest(),
        "first_frame_source": FIRST_FRAME_PATH.relative_to(ROOT).as_posix(),
        "first_frame_source_sha256": hashlib.sha256(FIRST_FRAME_PATH.read_bytes()).hexdigest(),
        "output": OUTPUT_PATH.relative_to(ROOT).as_posix(),
        "output_sha256": hashlib.sha256(OUTPUT_PATH.read_bytes()).hexdigest(),
        "preview": PREVIEW_PATH.relative_to(ROOT).as_posix(),
        "comparison": COMPARISON_PATH.relative_to(ROOT).as_posix(),
        "roi": list(ROI),
        "source_y_offset": SOURCE_Y_OFFSET,
        "changed_pixel_count": len(changed_coordinates),
        "changed_pixel_bbox": list(difference_bbox) if difference_bbox else None,
        "changed_outside_roi_count": len(changed_outside_roi),
        "alpha_unchanged": alpha_unchanged,
        "technical_qa_status": "PASS" if technical_pass else "BLOCKED",
        "visual_qa_status": "PENDING_MANUAL_REVIEW",
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not technical_pass:
        raise RuntimeError(f"Head-top transfer QA failed; see {REPORT_PATH}")
    print(f"OUTPUT={OUTPUT_PATH}")
    print(f"CHANGED_PIXEL_COUNT={len(changed_coordinates)}")
    print(f"CHANGED_PIXEL_BBOX={difference_bbox}")
    print("ALPHA_UNCHANGED=YES")
    print("TECHNICAL_QA=PASS")


if __name__ == "__main__":
    main()
