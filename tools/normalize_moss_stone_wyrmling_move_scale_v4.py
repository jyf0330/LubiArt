from __future__ import annotations

import importlib.util
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_QA = ROOT / "output/sprite_animation_candidates/_manifests/moss_stone_wyrmling/move_v3/qa_report.json"
VERSION_ROOT = ROOT / "output/sprite_animation_candidates/moss_stone_wyrmling/move_v4"
FRAME_DIR = VERSION_ROOT / "frames"
SHEET_PATH = VERSION_ROOT / "moss_stone_wyrmling_move_sheet_v4.png"
OVERVIEW_PATH = VERSION_ROOT / "moss_stone_wyrmling_move_overview_v4.png"
ZOOM_OVERVIEW_PATH = ROOT / "output/moss_stone_wyrmling_move_frames_4x_v4.png"
GIF_PATH = ROOT / "output/moss_stone_wyrmling_move_preview_v4.gif"
SLOW_GIF_PATH = ROOT / "output/moss_stone_wyrmling_move_preview_slow_v4.gif"
QA_PATH = ROOT / "output/sprite_animation_candidates/_manifests/moss_stone_wyrmling/move_v4/qa_report.json"

BASE_PROCESSOR = ROOT / "tools/process_moss_stone_wyrmling_move_rika_v3.py"
spec = importlib.util.spec_from_file_location("move_v3_processor", BASE_PROCESSOR)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load v3 processor: {BASE_PROCESSOR}")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

REFERENCE_EYE_AREA = 140.0
MAX_CORRECTION_SCALE = 1.12
SAFE_MARGIN = 1


def find_eye(frame: Image.Image) -> tuple[int, float, float, tuple[int, int, int, int]]:
    rgba = np.array(frame.convert("RGBA"))
    hsv = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_RGB2HSV)
    mask = (
        (rgba[:, :, 3] > 0)
        & (hsv[:, :, 0] >= 2)
        & (hsv[:, :, 0] <= 24)
        & (hsv[:, :, 1] >= 120)
        & (hsv[:, :, 2] >= 80)
    ).astype(np.uint8) * 255
    count, _, stats, centers = cv2.connectedComponentsWithStats(mask, 8)
    candidates: list[tuple[int, int]] = []
    for label in range(1, count):
        x, y, width, height, area = map(int, stats[label])
        if area >= 4 and x < 90 and y < 100:
            candidates.append((area, label))
    if not candidates:
        raise ValueError("Could not locate the amber eye component")
    area, label = max(candidates)
    x, y, width, height, _ = map(int, stats[label])
    return area, float(centers[label][0]), float(centers[label][1]), (x, y, width, height)


def desired_scales(frames: list[Image.Image]) -> list[float]:
    raw: list[float] = []
    for frame in frames:
        eye_area, _, _, _ = find_eye(frame)
        scale = math.sqrt(REFERENCE_EYE_AREA / eye_area)
        raw.append(max(1.0, min(MAX_CORRECTION_SCALE, scale)))
    smoothed: list[float] = []
    for index, value in enumerate(raw):
        previous = raw[index - 1] if index > 0 else value
        following = raw[index + 1] if index + 1 < len(raw) else value
        smoothed.append((previous + 2.0 * value + following) / 4.0)
    smoothed[0] = 1.0
    smoothed[-1] = 1.0
    return smoothed


def scale_about_eye(
    frame: Image.Image,
    requested_scale: float,
) -> tuple[Image.Image, dict[str, object]]:
    frame = frame.convert("RGBA")
    alpha_box = frame.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("Cannot scale an empty frame")
    eye_area, eye_x, eye_y, eye_box = find_eye(frame)
    box_width = alpha_box[2] - alpha_box[0]
    box_height = alpha_box[3] - alpha_box[1]
    dimension_limit = min(
        (frame.width - 2 * SAFE_MARGIN - 1) / box_width,
        (frame.height - 2 * SAFE_MARGIN - 1) / box_height,
    )
    applied_scale = min(requested_scale, dimension_limit)
    applied_scale = max(1.0, applied_scale)

    if abs(applied_scale - 1.0) < 1e-9:
        return frame.copy(), {
            "requested_scale": requested_scale,
            "applied_scale": 1.0,
            "translation": [0, 0],
            "source_alpha_box": list(alpha_box),
            "output_alpha_box": list(alpha_box),
            "source_eye_area": eye_area,
            "output_eye_area": eye_area,
            "source_eye_box": list(eye_box),
            "output_eye_box": list(eye_box),
        }

    scaled_size = (
        max(1, round(frame.width * applied_scale)),
        max(1, round(frame.height * applied_scale)),
    )
    resized = frame.resize(scaled_size, Image.Resampling.NEAREST)
    offset_x = round(eye_x - eye_x * applied_scale)
    offset_y = round(eye_y - eye_y * applied_scale)

    predicted = (
        round(eye_x + applied_scale * (alpha_box[0] - eye_x)),
        round(eye_y + applied_scale * (alpha_box[1] - eye_y)),
        round(eye_x + applied_scale * (alpha_box[2] - eye_x)),
        round(eye_y + applied_scale * (alpha_box[3] - eye_y)),
    )
    shift_x = 0
    shift_y = 0
    if predicted[0] < SAFE_MARGIN:
        shift_x = SAFE_MARGIN - predicted[0]
    elif predicted[2] > frame.width - SAFE_MARGIN:
        shift_x = frame.width - SAFE_MARGIN - predicted[2]
    if predicted[1] < SAFE_MARGIN:
        shift_y = SAFE_MARGIN - predicted[1]
    elif predicted[3] > frame.height - SAFE_MARGIN:
        shift_y = frame.height - SAFE_MARGIN - predicted[3]

    output = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    output.alpha_composite(resized, (offset_x + shift_x, offset_y + shift_y))
    output_box = output.getchannel("A").getbbox()
    if output_box is None:
        raise ValueError("Scale correction produced an empty frame")
    if (
        output_box[0] < SAFE_MARGIN
        or output_box[1] < SAFE_MARGIN
        or output_box[2] > frame.width - SAFE_MARGIN
        or output_box[3] > frame.height - SAFE_MARGIN
    ):
        raise ValueError(f"Scale correction violated safe margin: {output_box}")
    output_eye_area, _, _, output_eye_box = find_eye(output)
    return output, {
        "requested_scale": requested_scale,
        "applied_scale": applied_scale,
        "translation": [offset_x + shift_x, offset_y + shift_y],
        "source_alpha_box": list(alpha_box),
        "output_alpha_box": list(output_box),
        "source_eye_area": eye_area,
        "output_eye_area": output_eye_area,
        "source_eye_box": list(eye_box),
        "output_eye_box": list(output_eye_box),
    }


def coefficient_of_variation(values: list[float]) -> float:
    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / len(values)
    return math.sqrt(variance) / mean


def main() -> None:
    source_qa = json.loads(SOURCE_QA.read_text(encoding="utf-8"))
    source_paths = [ROOT / relative for relative in source_qa["frame_paths"]]
    source_frames = [Image.open(path).convert("RGBA") for path in source_paths]
    requested = desired_scales(source_frames)
    transformed: list[Image.Image] = []
    transforms: list[dict[str, object]] = []
    for frame, scale in zip(source_frames, requested, strict=True):
        output, metadata = scale_about_eye(frame, scale)
        transformed.append(output)
        transforms.append(metadata)

    if transformed[0].tobytes() != source_frames[0].tobytes():
        raise ValueError("The accepted first frame changed unexpectedly")
    if transformed[-1].tobytes() != source_frames[-1].tobytes():
        raise ValueError("The accepted last frame changed unexpectedly")
    if transformed[0].tobytes() != transformed[-1].tobytes():
        raise ValueError("The corrected first and last frames are not identical")

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    frame_paths: list[Path] = []
    for index, frame in enumerate(transformed, start=1):
        path = FRAME_DIR / f"frame_{index:03d}.png"
        base.save_image(frame, path)
        frame_paths.append(path)

    sheet = base.compose_sheet(transformed)
    base.save_image(sheet, SHEET_PATH)
    base.save_image(sheet, OVERVIEW_PATH)
    preview_sheet = Image.new("RGBA", sheet.size, (*base.PREVIEW_BACKGROUND, 255))
    preview_sheet.alpha_composite(sheet)
    base.save_image(
        preview_sheet.resize(
            (preview_sheet.width * 4, preview_sheet.height * 4),
            Image.Resampling.NEAREST,
        ),
        ZOOM_OVERVIEW_PATH,
    )

    previews = [base.compose_preview(frame) for frame in transformed]
    gif_report = base.write_verified_gif(previews, GIF_PATH, base.FRAME_DURATION_MS)
    slow_gif_report = base.write_verified_gif(previews, SLOW_GIF_PATH, base.SLOW_FRAME_DURATION_MS)
    edge_touch_frames = [
        index + 1
        for index, frame in enumerate(transformed)
        if (box := frame.getchannel("A").getbbox()) is not None
        and (box[0] == 0 or box[1] == 0 or box[2] == frame.width or box[3] == frame.height)
    ]
    source_eye_scales = [math.sqrt(float(item["source_eye_area"])) for item in transforms]
    output_eye_scales = [math.sqrt(float(item["output_eye_area"])) for item in transforms]
    report = {
        "version": 4,
        "source_version": 3,
        "source_qa": SOURCE_QA.relative_to(ROOT).as_posix(),
        "operation": "deterministic per-frame uniform nearest-neighbor scale and translation only",
        "pose_pixel_editing": False,
        "generated_or_inpainted_pixels": False,
        "frame_count": len(transformed),
        "frame_size": list(base.FRAME_SIZE),
        "frame_paths": [path.relative_to(ROOT).as_posix() for path in frame_paths],
        "reference_eye_area": REFERENCE_EYE_AREA,
        "maximum_correction_scale": MAX_CORRECTION_SCALE,
        "safe_margin": SAFE_MARGIN,
        "transforms": transforms,
        "source_eye_scale_cv": coefficient_of_variation(source_eye_scales),
        "output_eye_scale_cv": coefficient_of_variation(output_eye_scales),
        "edge_touch_frames": edge_touch_frames,
        "first_frame_unchanged": transformed[0].tobytes() == source_frames[0].tobytes(),
        "last_frame_unchanged": transformed[-1].tobytes() == source_frames[-1].tobytes(),
        "first_last_identical": transformed[0].tobytes() == transformed[-1].tobytes(),
        "gif": gif_report,
        "slow_gif": slow_gif_report,
        "overview": OVERVIEW_PATH.relative_to(ROOT).as_posix(),
        "zoom_overview": ZOOM_OVERVIEW_PATH.relative_to(ROOT).as_posix(),
        "technical_qa_status": "PASS" if not edge_touch_frames else "BLOCKED",
        "visual_qa_status": "PENDING_MANUAL_REVIEW",
    }
    QA_PATH.parent.mkdir(parents=True, exist_ok=True)
    QA_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if edge_touch_frames:
        raise ValueError(f"Corrected frames touched an output edge: {edge_touch_frames}")
    print(f"FRAME_COUNT={len(transformed)}")
    print("APPLIED_SCALES=" + ",".join(f"{item['applied_scale']:.4f}" for item in transforms))
    print(f"SOURCE_EYE_SCALE_CV={report['source_eye_scale_cv']:.6f}")
    print(f"OUTPUT_EYE_SCALE_CV={report['output_eye_scale_cv']:.6f}")
    print(f"EDGE_TOUCH_FRAMES={edge_touch_frames}")
    print(f"GIF_EXACT_PIXEL_MATCH={gif_report['exact_pixel_match']}")
    print(f"SLOW_GIF_EXACT_PIXEL_MATCH={slow_gif_report['exact_pixel_match']}")
    print(f"OVERVIEW={OVERVIEW_PATH}")
    print(f"GIF={GIF_PATH}")


if __name__ == "__main__":
    main()
