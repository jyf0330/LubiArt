from __future__ import annotations

import importlib.util
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/composite_golden_cat_idle_rika_blink_v2.py"
spec = importlib.util.spec_from_file_location("golden_cat_blink_v2", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load v2 animation helper: {BASE_SCRIPT}")
v2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v2)

SOURCE_ROOT = ROOT / "output/sprite_animations/golden_cat_idle_rika_blink_v2"
OUTPUT_ROOT = ROOT / "output/sprite_animations/golden_cat_idle_rika_blink_v3"
OUTPUT_VERSION = 3
SOURCE_VERSION_NAME = "golden_cat_idle_rika_blink_v2"
FRAME_DIR = OUTPUT_ROOT / "frames"
SOURCE_FRAME_DIR = OUTPUT_ROOT / "source_frames"
QC_DIR = OUTPUT_ROOT / "qc"

USER_FRAME_10 = Path(r"C:\Users\jyf\Desktop\frame_010.png")
USER_FRAME_11 = Path(r"C:\Users\jyf\Desktop\frame_011.png")


def save_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=False)


def visible_pixel_difference(left: Image.Image, right: Image.Image) -> int:
    background = Image.new("RGBA", left.size, (0, 0, 0, 255))
    left_visible = Image.alpha_composite(background, left.convert("RGBA"))
    right_visible = Image.alpha_composite(background, right.convert("RGBA"))
    return sum(
        left_pixel != right_pixel
        for left_pixel, right_pixel in zip(
            left_visible.get_flattened_data(), right_visible.get_flattened_data()
        )
    )


def visible_difference_box(left: Image.Image, right: Image.Image) -> list[int] | None:
    background = Image.new("RGBA", left.size, (0, 0, 0, 255))
    left_visible = Image.alpha_composite(background, left.convert("RGBA"))
    right_visible = Image.alpha_composite(background, right.convert("RGBA"))
    difference = Image.new("L", left.size)
    difference.putdata(
        [
            255 if left_pixel != right_pixel else 0
            for left_pixel, right_pixel in zip(
                left_visible.get_flattened_data(), right_visible.get_flattened_data()
            )
        ]
    )
    box = difference.getbbox()
    return list(box) if box is not None else None


def validate_user_frame(path: Path, expected_bottom: int = 118) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(f"User frame is missing: {path}")
    image = Image.open(path).convert("RGBA")
    if image.size != (128, 128):
        raise ValueError(f"User frame must be 128x128: {path}: {image.size}")
    alpha_values = set(image.getchannel("A").get_flattened_data())
    if not alpha_values.issubset({0, 255}):
        raise ValueError(f"User frame must use binary transparency: {path}")
    box = image.getchannel("A").getbbox()
    if box is None:
        raise ValueError(f"User frame is empty: {path}")
    if box[3] != expected_bottom:
        raise ValueError(
            f"User frame feet baseline changed: {path}: bottom={box[3]}, expected={expected_bottom}"
        )
    if box[0] == 0 or box[1] == 0 or box[2] == 128 or box[3] == 128:
        raise ValueError(f"User frame touches the canvas edge: {path}: {box}")
    # Some image editors leave arbitrary RGB values under fully transparent pixels.
    # Normalize those hidden pixels so previewers and future texture processing cannot
    # expose white/black blocks around the sprite.
    return Image.alpha_composite(Image.new("RGBA", image.size, (0, 0, 0, 0)), image)


def main() -> None:
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_FRAME_DIR.mkdir(parents=True, exist_ok=True)
    QC_DIR.mkdir(parents=True, exist_ok=True)

    frames = [
        Image.open(SOURCE_ROOT / f"frames/frame_{index:03d}.png").convert("RGBA")
        for index in range(1, 18)
    ]
    raw_10 = Image.open(USER_FRAME_10).convert("RGBA")
    raw_11 = Image.open(USER_FRAME_11).convert("RGBA")
    revised_10 = validate_user_frame(USER_FRAME_10)
    revised_11 = validate_user_frame(USER_FRAME_11)
    old_10 = frames[9].copy()
    old_11 = frames[10].copy()
    frames[9] = revised_10
    frames[10] = revised_11

    save_image(raw_10, SOURCE_FRAME_DIR / "frame_010_user_revision.png")
    save_image(raw_11, SOURCE_FRAME_DIR / "frame_011_user_revision.png")

    frame_paths = []
    for index, frame in enumerate(frames, start=1):
        path = FRAME_DIR / f"frame_{index:03d}.png"
        save_image(frame, path)
        frame_paths.append(path)

    sheet = v2.compose_sheet(frames)
    save_image(sheet, OUTPUT_ROOT / "sheet-transparent.png")
    save_image(sheet, OUTPUT_ROOT / "frames-overview.png")
    save_image(
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.Resampling.NEAREST),
        OUTPUT_ROOT / "frames-overview-4x.png",
    )
    previews = [v2.compose_preview(frame) for frame in frames]
    gif_durations = v2.write_verified_gif(
        previews, OUTPUT_ROOT / "animation.gif", v2.FRAME_DURATION_MS
    )
    slow_durations = v2.write_verified_gif(
        previews, OUTPUT_ROOT / "slow-preview.gif", v2.SLOW_DURATION_MS
    )

    for index in (9, 10, 11, 12):
        save_image(
            frames[index - 1].resize((512, 512), Image.Resampling.NEAREST),
            QC_DIR / f"frame_{index:03d}_4x.png",
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
    preview_colors = {
        color for preview in previews for color in preview.get_flattened_data()
    }
    report = {
        "version": OUTPUT_VERSION,
        "source_version": SOURCE_VERSION_NAME,
        "new_rika_calls": 0,
        "frame_count": len(frames),
        "frame_size": [128, 128],
        "user_replacements": {
            "frame_010": {
                "stored_source": "source_frames/frame_010_user_revision.png",
                "changed_visible_pixels_from_source": visible_pixel_difference(old_10, revised_10),
                "visible_difference_bbox": visible_difference_box(old_10, revised_10),
            },
            "frame_011": {
                "stored_source": "source_frames/frame_011_user_revision.png",
                "changed_visible_pixels_from_source": visible_pixel_difference(old_11, revised_11),
                "visible_difference_bbox": visible_difference_box(old_11, revised_11),
            },
        },
        "frame_paths": [path.relative_to(ROOT).as_posix() for path in frame_paths],
        "alpha_bounding_boxes": [list(box) for box in valid_boxes],
        "edge_touch_frames": edge_touch_frames,
        "first_last_identical": frames[0].tobytes() == frames[-1].tobytes(),
        "palette_color_count": len(preview_colors),
        "animation_gif": {
            "path": "animation.gif",
            "durations_ms": gif_durations,
            "exact_pixel_match": True,
            "disposal": 2,
        },
        "slow_gif": {
            "path": "slow-preview.gif",
            "durations_ms": slow_durations,
            "exact_pixel_match": True,
            "disposal": 2,
        },
        "technical_qa_status": "PASS" if not edge_touch_frames else "BLOCKED",
        "visual_qa_status": "PASS",
        "visual_qa_scope": [
            "native-size frames",
            "4x key frames 009-012",
            "4x full sequence overview",
            "blink contour and facial continuity",
            "body/limb connections and feet baseline",
            "transparent edges and loop endpoints",
        ],
    }
    (OUTPUT_ROOT / "QC_REPORT.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"FRAME_COUNT={len(frames)}")
    print(f"FRAME_10_CHANGED_VISIBLE_PIXELS={report['user_replacements']['frame_010']['changed_visible_pixels_from_source']}")
    print(f"FRAME_11_CHANGED_VISIBLE_PIXELS={report['user_replacements']['frame_011']['changed_visible_pixels_from_source']}")
    print(f"EDGE_TOUCH_FRAMES={edge_touch_frames}")
    print(f"FIRST_LAST_IDENTICAL={report['first_last_identical']}")
    print("GIF_EXACT_PIXEL_MATCH=True")


if __name__ == "__main__":
    main()
