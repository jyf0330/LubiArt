from __future__ import annotations

import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/process_red_gem_short_leg_dog_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("rock_claw_process_base", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Rika processor: {BASE_SCRIPT}")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

ANIMATION_ROOT = ROOT / "output/sprite_animation_candidates/rock_claw"
VERSION_ROOT = ANIMATION_ROOT / "move_v1"
QA_REPORT_PATH = (
    ROOT / "output/sprite_animation_candidates/_manifests/rock_claw/move_v1/qa_report.json"
)


def configure_base() -> None:
    base.ANIMATION_ROOT = ANIMATION_ROOT
    base.VERSION_ROOT = VERSION_ROOT
    base.RAW_SHEET_PATH = VERSION_ROOT / "raw/output_001.png"
    base.PROMPT_PATH = VERSION_ROOT / "source/prompt-used.txt"
    base.MAGENTA_SHEET_PATH = VERSION_ROOT / "source/rock_claw_move_sheet_chroma_v1.png"
    base.SKILL_OUTPUT_DIR = VERSION_ROOT / "processor_qc"
    base.FRAME_DIR = VERSION_ROOT / "frames"
    base.SHEET_PATH = ANIMATION_ROOT / "rock_claw_move_sheet_v1.png"
    base.OVERVIEW_PATH = VERSION_ROOT / "rock_claw_move_overview_v1.png"
    base.ZOOM_OVERVIEW_PATH = ROOT / "output/rock_claw_move_frames_4x_v1.png"
    base.GIF_PATH = ROOT / "output/rock_claw_move_preview_v1.gif"
    base.SLOW_GIF_PATH = ROOT / "output/rock_claw_move_preview_slow_v1.gif"
    base.SUBMISSION_PATH = (
        ROOT / "output/sprite_animation_candidates/_manifests/rock_claw/move_v1/submission.json"
    )
    base.QA_REPORT_PATH = QA_REPORT_PATH


def update_report() -> None:
    report = json.loads(QA_REPORT_PATH.read_text(encoding="utf-8"))
    job_path = QA_REPORT_PATH.with_name("job.json")
    submission_path = QA_REPORT_PATH.with_name("submission.json")
    job = json.loads(job_path.read_text(encoding="utf-8"))
    submission = json.loads(submission_path.read_text(encoding="utf-8"))
    report["asset_id"] = "SPR_007"
    report["asset_name"] = "Rock Claw"
    report["action"] = "move"
    report["rika_generation_call_count"] = 1
    report["credits_before"] = submission["credits_before"]
    report["credits_after"] = job["credits_after"]
    report["actual_credit_change"] = job["actual_credit_change"]
    report["required_motion_contract"] = {
        "travel_axis": "depth_forward_backward",
        "horizontal_foot_lanes_locked": True,
        "sideways_stride_forbidden": True,
        "forward_cue": "foot appears slightly lower and more prominent",
        "backward_cue": "opposite foot appears slightly higher and more occluded",
    }
    report["visual_qa_status"] = "PENDING_MANUAL_REVIEW"
    report["visual_qa_notes"] = [
        "Review foot motion at original size and 4x nearest-neighbor scale before acceptance.",
        "Reject if either foot primarily travels left/right instead of alternating toward/away from the viewer.",
    ]
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    configure_base()
    base.main()
    update_report()
    print(f"QA_REPORT={QA_REPORT_PATH}")


if __name__ == "__main__":
    main()
