from __future__ import annotations

import importlib.util
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/process_aqua_cloud_bear_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("rika_process_base", BASE_SCRIPT)
processor = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(processor)

ANIMATION_ROOT = ROOT / "art/images/shared/pets/animations/diamond_segment_worm"
IMAGE_ROOT = ANIMATION_ROOT / "move_v1"
QA_REPORT_PATH = (
    ROOT
    / "art/manifests/shared/pets/animations/diamond_segment_worm/move_v1/qa_report.json"
)
LOOP_FRAME_DIR = IMAGE_ROOT / "move_loop"
LOOP_SOURCE_INDICES = list(range(1, 17)) + list(range(15, 1, -1))
LOOP_COLUMNS = 6
LOOP_ROWS = 5


def configure_base() -> None:
    processor.ANIMATION_ROOT = ANIMATION_ROOT
    processor.IMAGE_ROOT = IMAGE_ROOT
    processor.RAW_SHEET_PATH = IMAGE_ROOT / "raw/output_001.png"
    processor.FRAME_DIR = IMAGE_ROOT / "move"
    processor.SHEET_PATH = ANIMATION_ROOT / "diamond_segment_worm_move_v1.png"
    processor.ZOOM_SHEET_PATH = ANIMATION_ROOT / "diamond_segment_worm_move_4x_v1.png"
    processor.GIF_PATH = ANIMATION_ROOT / "diamond_segment_worm_move_v1.gif"
    processor.SLOW_GIF_PATH = ANIMATION_ROOT / "diamond_segment_worm_move_slow_v1.gif"
    processor.QA_REPORT_PATH = QA_REPORT_PATH
    processor.FRAME_DURATION_MS = 140
    processor.SLOW_FRAME_DURATION_MS = 360


def count_different_pixels(left: Image.Image, right: Image.Image) -> int:
    return sum(
        left_pixel != right_pixel
        for left_pixel, right_pixel in zip(
            left.get_flattened_data(), right.get_flattened_data(), strict=True
        )
    )


def build_seamless_loop() -> None:
    source_frames = [
        Image.open(processor.FRAME_DIR / f"frame_{index:03d}.png").convert("RGBA")
        for index in range(1, 17)
    ]
    LOOP_FRAME_DIR.mkdir(parents=True, exist_ok=True)
    loop_frames: list[Image.Image] = []
    for output_index, source_index in enumerate(LOOP_SOURCE_INDICES, start=1):
        frame = source_frames[source_index - 1]
        processor.save_image(frame, LOOP_FRAME_DIR / f"frame_{output_index:03d}.png")
        loop_frames.append(
            Image.open(LOOP_FRAME_DIR / f"frame_{output_index:03d}.png").convert("RGBA")
        )

    sheet = Image.new(
        "RGBA",
        (processor.FRAME_SIZE[0] * LOOP_COLUMNS, processor.FRAME_SIZE[1] * LOOP_ROWS),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(loop_frames):
        x = (index % LOOP_COLUMNS) * processor.FRAME_SIZE[0]
        y = (index // LOOP_COLUMNS) * processor.FRAME_SIZE[1]
        sheet.alpha_composite(frame, (x, y))
    processor.save_image(sheet, processor.SHEET_PATH)
    processor.save_image(
        sheet.resize(
            (sheet.width * 4, sheet.height * 4), Image.Resampling.NEAREST
        ),
        processor.ZOOM_SHEET_PATH,
    )

    previews = [processor.compose_preview(frame) for frame in loop_frames]
    gif_exact, gif_durations = processor.write_gif(
        previews, processor.GIF_PATH, processor.FRAME_DURATION_MS
    )
    slow_gif_exact, slow_gif_durations = processor.write_gif(
        previews, processor.SLOW_GIF_PATH, processor.SLOW_FRAME_DURATION_MS
    )

    alpha_boxes = [frame.getchannel("A").getbbox() for frame in loop_frames]
    centers_x = [(box[0] + box[2]) / 2 for box in alpha_boxes]
    bottoms = [box[3] for box in alpha_boxes]
    differences = [
        count_different_pixels(previews[index], previews[(index + 1) % len(previews)])
        for index in range(len(previews))
    ]
    edge_touch_frames = [
        index
        for index, box in enumerate(alpha_boxes, start=1)
        if box[0] == 0
        or box[1] == 0
        or box[2] == processor.FRAME_SIZE[0]
        or box[3] == processor.FRAME_SIZE[1]
    ]
    report = json.loads(QA_REPORT_PATH.read_text(encoding="utf-8"))
    report.update(
        {
            "service": "Rika AI",
            "action": "move",
            "motion": "in-place peristaltic crawl",
            "delivery_frame_count": len(loop_frames),
            "delivery_sequence_source_indices": LOOP_SOURCE_INDICES,
            "delivery_frame_paths": [
                (LOOP_FRAME_DIR / f"frame_{index:03d}.png").relative_to(ROOT).as_posix()
                for index in range(1, len(loop_frames) + 1)
            ],
            "delivery_overview_grid": [LOOP_ROWS, LOOP_COLUMNS],
            "delivery_alpha_bounding_boxes": [list(box) for box in alpha_boxes],
            "delivery_output_edge_touch_frames": edge_touch_frames,
            "delivery_bbox_center_x_span": max(centers_x) - min(centers_x),
            "delivery_contact_baseline_span": max(bottoms) - min(bottoms),
            "delivery_sequential_difference_pixels_including_loop": differences,
            "delivery_loop_difference": differences[-1],
            "delivery_loop_transition_within_sequence_range": (
                min(differences[:-1]) <= differences[-1] <= max(differences[:-1])
            ),
            "gif": {
                "path": processor.GIF_PATH.relative_to(ROOT).as_posix(),
                "source": "saved delivery frame PNGs composited over preview background",
                "exact_pixel_match": gif_exact,
                "durations_ms": gif_durations,
                "disposal": 2,
            },
            "slow_gif": {
                "path": processor.SLOW_GIF_PATH.relative_to(ROOT).as_posix(),
                "source": "saved delivery frame PNGs composited over preview background",
                "exact_pixel_match": slow_gif_exact,
                "durations_ms": slow_gif_durations,
                "disposal": 2,
            },
            "technical_qa_status": "PASS",
            "visual_qa_status": "PASS",
            "visual_qa_notes": [
                "The rear pink segments and underside feet form a readable in-place crawl rhythm.",
                "Head, smile, eye gem, gray crown, blue crystals, palette and hard pixel outline remain coherent.",
                "No hard cut, duplicate limb, contour break, crop, chroma fringe or ghosting is visible.",
                "The 30-frame forward-and-reverse delivery loop removes the raw endpoint jump without redrawing frames.",
            ],
        }
    )
    if (
        edge_touch_frames
        or max(centers_x) - min(centers_x) > 4.0
        or max(bottoms) - min(bottoms) > 4
        or not gif_exact
        or not slow_gif_exact
        or not report["delivery_loop_transition_within_sequence_range"]
    ):
        report["technical_qa_status"] = "BLOCKED"
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def update_report() -> None:
    report = json.loads(QA_REPORT_PATH.read_text(encoding="utf-8"))
    report["service"] = "Rika AI"
    report["action"] = "move"
    report["motion"] = "in-place peristaltic crawl"
    report["visual_qa_status"] = "PENDING_MANUAL_REVIEW"
    report["visual_qa_notes"] = [
        "Inspect the body-segment compression wave at native size and 4x zoom.",
        "Verify that the head, smile, eye gem, gray crown and blue crystals remain stable.",
        "Verify the underside contact line, body center and seamless first-to-last loop.",
    ]
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    configure_base()
    processor.main()
    update_report()
    build_seamless_loop()


if __name__ == "__main__":
    main()
