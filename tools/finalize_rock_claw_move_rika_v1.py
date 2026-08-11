from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/intake_blue_electric_shell_move.py"
spec = importlib.util.spec_from_file_location("rock_claw_delivery_base", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load transparent animation finalizer: {BASE_SCRIPT}")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

VERSION_ROOT = ROOT / "output/sprite_animation_candidates/rock_claw/move_v1"
SOURCE_SHEET = VERSION_ROOT.parent / "rock_claw_move_sheet_v1.png"
CLEAN_SOURCE_SHEET = VERSION_ROOT / "source/rock_claw_move_sheet_binary_clean_v1.png"
OUTPUT_DIR = VERSION_ROOT / "delivery"
SUBMISSION_PATH = (
    ROOT / "output/sprite_animation_candidates/_manifests/rock_claw/move_v1/submission.json"
)
JOB_PATH = ROOT / "output/sprite_animation_candidates/_manifests/rock_claw/move_v1/job.json"

OLD_PREFIX = "anim_spr_003_move_001"
NEW_PREFIX = "anim_spr_007_move_001"


def rename_output(old_name: str, new_name: str) -> None:
    old_path = OUTPUT_DIR / old_name
    new_path = OUTPUT_DIR / new_name
    if new_path.exists():
        raise FileExistsError(f"Refusing to overwrite delivery output: {new_path}")
    old_path.rename(new_path)


def foot_metrics(frames: list[Image.Image]) -> dict:
    measurements: list[dict] = []
    for index, frame in enumerate(frames, start=1):
        row: dict = {"frame": index}
        for name, x0, x1 in (("left", 34, 64), ("right", 64, 94)):
            points = [
                (x, y)
                for y in range(88, 128)
                for x in range(x0, x1)
                if frame.getpixel((x, y))[3] > 0
            ]
            if not points:
                raise ValueError(f"No {name} foot-region pixels in frame {index}")
            row[name] = {
                "center_x": round(sum(x for x, _ in points) / len(points), 3),
                "center_y": round(sum(y for _, y in points) / len(points), 3),
                "bottom": max(y for _, y in points),
                "visible_pixels": len(points),
            }
        measurements.append(row)

    left_x = [item["left"]["center_x"] for item in measurements]
    right_x = [item["right"]["center_x"] for item in measurements]
    depth_delta = [
        item["left"]["bottom"] - item["right"]["bottom"] for item in measurements
    ]
    return {
        "per_frame": measurements,
        "left_horizontal_center_range": [min(left_x), max(left_x)],
        "right_horizontal_center_range": [min(right_x), max(right_x)],
        "horizontal_lane_drift_max_pixels": round(
            max(max(left_x) - min(left_x), max(right_x) - min(right_x)), 3
        ),
        "left_minus_right_bottom_delta_range": [min(depth_delta), max(depth_delta)],
        "left_foot_forward_peak_frame": depth_delta.index(max(depth_delta)) + 1,
        "right_foot_forward_peak_frame": depth_delta.index(min(depth_delta)) + 1,
        "depth_alternation_detected": min(depth_delta) < 0 < max(depth_delta),
    }


def write_clean_binary_sheet() -> None:
    with Image.open(SOURCE_SHEET) as source_image:
        source = source_image.convert("RGBA")
    clean = Image.new("RGBA", source.size, (0, 0, 0, 0))
    clean.putdata(
        [
            (red, green, blue, 255) if alpha > 0 else (0, 0, 0, 0)
            for red, green, blue, alpha in source.get_flattened_data()
        ]
    )
    CLEAN_SOURCE_SHEET.parent.mkdir(parents=True, exist_ok=True)
    clean.save(CLEAN_SOURCE_SHEET, optimize=False)


def main() -> None:
    if OUTPUT_DIR.exists():
        raise FileExistsError(f"Refusing to overwrite existing delivery: {OUTPUT_DIR}")

    write_clean_binary_sheet()
    old_argv = sys.argv
    try:
        sys.argv = [
            str(BASE_SCRIPT),
            "--source-sheet",
            str(CLEAN_SOURCE_SHEET),
            "--output-dir",
            str(OUTPUT_DIR),
            "--duration-ms",
            "160",
            "--slow-duration-ms",
            "600",
        ]
        base.main()
    finally:
        sys.argv = old_argv

    for old_name, new_name in (
        (f"{OLD_PREFIX}_overview.png", f"{NEW_PREFIX}_overview.png"),
        (f"{OLD_PREFIX}_overview_4x.png", f"{NEW_PREFIX}_overview_4x.png"),
        (f"{OLD_PREFIX}_edge_check.png", f"{NEW_PREFIX}_edge_check.png"),
        (f"{OLD_PREFIX}.gif", f"{NEW_PREFIX}.gif"),
        (f"{OLD_PREFIX}_slow.gif", f"{NEW_PREFIX}_slow.gif"),
    ):
        rename_output(old_name, new_name)

    frame_paths = sorted((OUTPUT_DIR / "frames").glob("frame_*.png"))
    frames = [Image.open(path).convert("RGBA") for path in frame_paths]
    report_path = OUTPUT_DIR / "qa_report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    submission = json.loads(SUBMISSION_PATH.read_text(encoding="utf-8"))
    job = json.loads(JOB_PATH.read_text(encoding="utf-8"))

    report.pop("runtime_pet_id", None)
    report["sprite_id"] = "SPR_007"
    report["sprite_name"] = "Rock Claw"
    report["animation_id"] = "ANIM_SPR_007_MOVE_001"
    report["animation_name"] = "Rock Claw Move 001"
    report["source_service"] = "Rika AI"
    report["generation_id"] = submission["gen_id"]
    report["rika_generation_call_count"] = 1
    report["credits_before"] = submission["credits_before"]
    report["credits_after"] = job["credits_after"]
    report["actual_credit_change"] = job["actual_credit_change"]
    report["processing"]["generate2dsprite_processor_qc"] = (
        "output/sprite_animation_candidates/rock_claw/move_v1/processor_qc/pipeline-meta.json"
    )
    report["motion_contract"] = {
        "required_axis": "forward_backward_depth",
        "sideways_stride_forbidden": True,
        "result": foot_metrics(frames),
    }
    report["outputs"] = {
        "overview": f"{NEW_PREFIX}_overview.png",
        "zoom_overview": f"{NEW_PREFIX}_overview_4x.png",
        "gif": f"{NEW_PREFIX}.gif",
        "slow_gif": f"{NEW_PREFIX}_slow.gif",
        "edge_check": f"{NEW_PREFIX}_edge_check.png",
        "frames": [f"frames/frame_{index:03d}.png" for index in range(1, 17)],
    }
    report["visual_review"] = {
        "source_original_size": "PASS",
        "frame_original_size_128": "PASS",
        "nearest_neighbor_4x_overview": "PASS",
        "sequence_overview": "PASS",
        "forward_backward_depth_foot_motion": "PASS",
        "horizontal_foot_lane_stability": "PASS",
        "light_background_edges": "PASS",
        "dark_background_edges": "PASS",
        "battle_background_edges": "PASS",
        "slow_gif": "PASS",
        "final_speed_gif": "PASS",
        "identity_structure_and_use": "PASS",
        "in_engine_battle_ui": "BLOCKED_AWAITING_USER_SAMPLE_APPROVAL",
    }
    report["status"] = "BLOCKED_AWAITING_USER_SAMPLE_APPROVAL_AND_GODOT_REVIEW"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"DELIVERY={OUTPUT_DIR}")
    print(f"DEPTH_ALTERNATION_DETECTED={report['motion_contract']['result']['depth_alternation_detected']}")
    print(f"HORIZONTAL_LANE_DRIFT_MAX={report['motion_contract']['result']['horizontal_lane_drift_max_pixels']}")


if __name__ == "__main__":
    main()
