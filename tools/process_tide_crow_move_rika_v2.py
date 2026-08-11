from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
V1_SCRIPT = ROOT / "tools/process_tide_crow_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("tide_crow_process_v1", V1_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Tide Crow processor: {V1_SCRIPT}")
processor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(processor)

ANIMATION_ROOT = ROOT / "output/sprite_animation_candidates/tide_crow"
VERSION_ROOT = ANIMATION_ROOT / "move_v2"

processor.ANIMATION_ROOT = ANIMATION_ROOT
processor.VERSION_ROOT = VERSION_ROOT
processor.RAW_SHEET_PATH = VERSION_ROOT / "raw/output_001.png"
processor.PROMPT_PATH = VERSION_ROOT / "source/prompt-used.txt"
processor.CHROMA_SHEET_PATH = VERSION_ROOT / "source/tide_crow_move_sheet_chroma_v2.png"
processor.SKILL_OUTPUT_DIR = VERSION_ROOT / "processor_qc"
processor.FRAME_DIR = VERSION_ROOT / "frames"
processor.SHEET_PATH = ANIMATION_ROOT / "tide_crow_move_sheet_v2.png"
processor.OVERVIEW_PATH = VERSION_ROOT / "tide_crow_move_overview_v2.png"
processor.ZOOM_OVERVIEW_PATH = ROOT / "output/tide_crow_move_frames_4x_v2.png"
processor.GIF_PATH = ROOT / "output/tide_crow_move_preview_v2.gif"
processor.SLOW_GIF_PATH = ROOT / "output/tide_crow_move_preview_slow_v2.gif"
processor.QA_REPORT_PATH = (
    ROOT / "output/sprite_animation_candidates/_manifests/tide_crow/move_v2/qa_report.json"
)
processor.SUBMISSION_PATH = (
    ROOT / "output/sprite_animation_candidates/_manifests/tide_crow/move_v2/submission.json"
)
processor.JOB_PATH = ROOT / "output/sprite_animation_candidates/_manifests/tide_crow/move_v2/job.json"


if __name__ == "__main__":
    processor.main()
