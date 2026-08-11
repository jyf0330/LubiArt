from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/process_moss_stone_wyrmling_flight_rika_v1.py"
spec = importlib.util.spec_from_file_location("emerald_wyrmling_processor_base", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Rika processor helper: {BASE_SCRIPT}")
processor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(processor)

VERSION_ROOT = (
    ROOT
    / "output/sprite_animation_candidates/emerald_crystal_wyrmling/flight_move_v1"
)
MANIFEST_ROOT = (
    ROOT
    / "output/sprite_animation_candidates/_manifests/emerald_crystal_wyrmling/flight_move_v1"
)
RAW_SHEET = VERSION_ROOT / "raw/output_001.png"
START_SOURCE = VERSION_ROOT / "source/emerald_crystal_wyrmling_transparent_128_v1.png"
FRAME_DIR = VERSION_ROOT / "frames"
SHEET_PATH = VERSION_ROOT / "emerald_crystal_wyrmling_flight_sheet_v1.png"
OVERVIEW_PATH = VERSION_ROOT / "emerald_crystal_wyrmling_flight_overview_v1.png"
ZOOM_OVERVIEW_PATH = (
    VERSION_ROOT / "emerald_crystal_wyrmling_flight_overview_4x_v1.png"
)
GIF_PATH = VERSION_ROOT / "emerald_crystal_wyrmling_flight_preview_v1.gif"
SLOW_GIF_PATH = VERSION_ROOT / "emerald_crystal_wyrmling_flight_slow_check_v1.gif"
QA_REPORT_PATH = MANIFEST_ROOT / "qa_report.json"

FRAME_SIZE = (128, 128)
RAW_GRID = (4, 4)
DELIVERY_GRID = (4, 2)
SELECTED_RAW_FRAMES = (1, 2, 4, 5, 7, 8)
FRAME_DURATION_MS = 120
SLOW_FRAME_DURATION_MS = 420


def configure_processor() -> None:
    processor.ROOT = ROOT
    processor.VERSION_ROOT = VERSION_ROOT
    processor.MANIFEST_ROOT = MANIFEST_ROOT
    processor.RAW_SHEET = RAW_SHEET
    processor.FRAME_DIR = FRAME_DIR
    processor.SHEET_PATH = SHEET_PATH
    processor.OVERVIEW_PATH = OVERVIEW_PATH
    processor.ZOOM_OVERVIEW_PATH = ZOOM_OVERVIEW_PATH
    processor.GIF_PATH = GIF_PATH
    processor.SLOW_GIF_PATH = SLOW_GIF_PATH
    processor.QA_REPORT_PATH = QA_REPORT_PATH
    processor.FRAME_SIZE = FRAME_SIZE
    processor.RAW_GRID = RAW_GRID
    processor.FRAME_DURATION_MS = FRAME_DURATION_MS
    processor.SLOW_FRAME_DURATION_MS = SLOW_FRAME_DURATION_MS


def main() -> None:
    configure_processor()
    raw = Image.open(RAW_SHEET).convert("RGB")
    raw_frames = processor.extract_raw_frames(raw)
    frames = [raw_frames[index - 1] for index in SELECTED_RAW_FRAMES]
    with Image.open(START_SOURCE) as source:
        start = processor.harden_alpha(source.convert("RGBA"))
    if start.size != FRAME_SIZE:
        raise ValueError(f"Unexpected prepared source size: {start.size}")
    frames[0] = start
    frames.append(start.copy())
    frames = processor.quantize_with_shared_palette(frames)

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    frame_paths: list[Path] = []
    for index, frame in enumerate(frames, start=1):
        path = FRAME_DIR / f"frame_{index:03d}.png"
        if path.exists():
            raise FileExistsError(f"Refusing to overwrite delivery frame: {path}")
        frame.save(path, optimize=False)
        frame_paths.append(path)

    processor.RAW_GRID = DELIVERY_GRID
    sheet = processor.compose_sheet(frames)
    sheet.save(SHEET_PATH, optimize=False)
    sheet.save(OVERVIEW_PATH, optimize=False)
    preview_sheet = Image.new(
        "RGBA", sheet.size, (*processor.PREVIEW_BACKGROUND, 255)
    )
    preview_sheet.alpha_composite(sheet)
    preview_sheet.resize(
        (preview_sheet.width * 4, preview_sheet.height * 4),
        Image.Resampling.NEAREST,
    ).save(ZOOM_OVERVIEW_PATH, optimize=False)

    previews = [processor.compose_preview(frame) for frame in frames]
    gif_report = processor.write_verified_gif(
        previews, GIF_PATH, FRAME_DURATION_MS
    )
    slow_gif_report = processor.write_verified_gif(
        previews, SLOW_GIF_PATH, SLOW_FRAME_DURATION_MS
    )

    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("At least one delivery frame is empty")
    valid_boxes = [box for box in boxes if box is not None]
    edge_touch_frames = [
        index + 1
        for index, box in enumerate(valid_boxes)
        if box[0] == 0
        or box[1] == 0
        or box[2] == FRAME_SIZE[0]
        or box[3] == FRAME_SIZE[1]
    ]
    alpha_binary = [
        set(frame.getchannel("A").get_flattened_data()) <= {0, 255}
        for frame in frames
    ]
    spill_counts = [processor.residual_teal_pixels(frame) for frame in frames]
    sequential_differences = [
        processor.different_pixel_count(
            previews[index], previews[(index + 1) % len(previews)]
        )
        for index in range(len(previews))
    ]
    first_last_identical = frames[0].tobytes() == frames[-1].tobytes()
    technical_pass = (
        not edge_touch_frames
        and all(alpha_binary)
        and all(count == 0 for count in spill_counts)
        and first_last_identical
        and bool(gif_report["passed"])
        and bool(slow_gif_report["passed"])
    )

    submission = json.loads(
        (MANIFEST_ROOT / "submission.json").read_text(encoding="utf-8")
    )
    job = json.loads((MANIFEST_ROOT / "job.json").read_text(encoding="utf-8"))
    report = {
        "version": 1,
        "service": "Rika AI",
        "generation_id": submission["gen_id"],
        "generation_call_count": 1,
        "expected_credit_cost": submission["expected_cost_credits"],
        "actual_credit_change": job["actual_credit_change"],
        "source_sheet": processor.relative(RAW_SHEET),
        "source_sheet_sha256": hashlib.sha256(RAW_SHEET.read_bytes()).hexdigest(),
        "frame_count": len(frames),
        "frame_size": list(FRAME_SIZE),
        "raw_grid": list(RAW_GRID),
        "delivery_grid": list(DELIVERY_GRID),
        "selected_raw_frames": list(SELECTED_RAW_FRAMES),
        "excluded_edge_touch_raw_frames": [3, 6, 11, 14],
        "frame_paths": [processor.relative(path) for path in frame_paths],
        "keyframe_contract": {
            "start_source": processor.relative(START_SOURCE),
            "end_source": processor.relative(START_SOURCE),
            "start_delivery_frame": 1,
            "end_delivery_frame": len(frames),
            "first_last_pixel_identical": first_last_identical,
        },
        "alpha_bounding_boxes": [list(box) for box in valid_boxes],
        "alpha_binary": alpha_binary,
        "edge_touch_frames": edge_touch_frames,
        "residual_teal_pixels": spill_counts,
        "first_last_identical": first_last_identical,
        "sequential_difference_pixels_including_loop": sequential_differences,
        "gif": gif_report,
        "slow_gif": slow_gif_report,
        "sheet": processor.relative(SHEET_PATH),
        "overview": processor.relative(OVERVIEW_PATH),
        "zoom_overview": processor.relative(ZOOM_OVERVIEW_PATH),
        "technical_qa_status": "PASS" if technical_pass else "BLOCKED",
        "visual_qa_status": "PENDING_MANUAL_REVIEW",
    }
    MANIFEST_ROOT.mkdir(parents=True, exist_ok=True)
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not technical_pass:
        raise ValueError(f"Technical QA failed; see {QA_REPORT_PATH}")
    print(f"FRAME_COUNT={len(frames)}")
    print(f"EDGE_TOUCH_FRAMES={edge_touch_frames}")
    print(f"FIRST_LAST_IDENTICAL={first_last_identical}")
    print(f"GIF_EXACT_PIXEL_MATCH={gif_report['passed']}")
    print(f"SLOW_GIF_EXACT_PIXEL_MATCH={slow_gif_report['passed']}")
    print(f"OVERVIEW={OVERVIEW_PATH}")
    print(f"GIF={GIF_PATH}")


if __name__ == "__main__":
    main()
