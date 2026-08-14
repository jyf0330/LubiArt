from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_PROCESSOR = ROOT / "tools/sprite_animation_processor_helper.py"
spec = importlib.util.spec_from_file_location("golden_cat_idle_processor", BASE_PROCESSOR)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Rika sprite processor: {BASE_PROCESSOR}")
processor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(processor)

OUTPUT_ROOT = ROOT / "output/sprite_animations/golden_cat_idle_rika_v1"

processor.ANIMATION_ROOT = OUTPUT_ROOT
processor.VERSION_ROOT = OUTPUT_ROOT
processor.RAW_SHEET_PATH = OUTPUT_ROOT / "raw/output_001.png"
processor.PROMPT_PATH = OUTPUT_ROOT / "source/prompt-used.txt"
processor.CHROMA_SHEET_PATH = OUTPUT_ROOT / "source/golden_cat_idle_chroma_v1.png"
processor.SKILL_OUTPUT_DIR = OUTPUT_ROOT / "processor_qc"
processor.FRAME_DIR = OUTPUT_ROOT / "frames"
processor.SHEET_PATH = OUTPUT_ROOT / "sheet-transparent.png"
processor.OVERVIEW_PATH = OUTPUT_ROOT / "frames-overview.png"
processor.ZOOM_OVERVIEW_PATH = OUTPUT_ROOT / "frames-overview-4x.png"
processor.GIF_PATH = OUTPUT_ROOT / "animation.gif"
processor.SLOW_GIF_PATH = OUTPUT_ROOT / "slow-preview.gif"
processor.QA_REPORT_PATH = OUTPUT_ROOT / "manifests/qa_report.json"
processor.SUBMISSION_PATH = OUTPUT_ROOT / "manifests/submission.json"
processor.JOB_PATH = OUTPUT_ROOT / "manifests/job.json"

processor.FRAME_DURATION_MS = 120
processor.SLOW_FRAME_DURATION_MS = 500


def run_skill_processor() -> None:
    command = [
        sys.executable,
        str(processor.SKILL_PROCESSOR),
        "process",
        "--input",
        str(processor.CHROMA_SHEET_PATH),
        "--target",
        "creature",
        "--mode",
        "idle",
        "--output-dir",
        str(processor.SKILL_OUTPUT_DIR),
        "--rows",
        "4",
        "--cols",
        "4",
        "--cell-size",
        "128",
        "--label-prefix",
        "frame",
        "--prompt-file",
        str(processor.PROMPT_PATH),
        "--fit-scale",
        "0.84",
        "--trim-border",
        "0",
        "--edge-clean-depth",
        "2",
        "--align",
        "feet",
        "--shared-scale",
        "--scale-strategy",
        "preserve",
        "--component-mode",
        "largest",
        "--component-padding",
        "1",
        "--strict-qc",
        "--max-body-scale-cv",
        "0.08",
        "--max-anchor-y-std",
        "0.05",
        "--duration",
        str(processor.FRAME_DURATION_MS),
    ]
    subprocess.run(command, cwd=ROOT, check=True)


extract_raw_frames = processor.extract_frames


def load_final_frames(raw_image):
    frames = extract_raw_frames(raw_image)
    aligned_frames = []
    for frame in frames:
        box = frame.getchannel("A").getbbox()
        if box is None:
            raise ValueError("Rika idle frame became empty during extraction")
        center_x = (box[0] + box[2]) / 2
        shift_x = round(64 - center_x)
        shift_y = 118 - box[3]
        aligned = Image.new("RGBA", frame.size, (0, 0, 0, 0))
        aligned.alpha_composite(frame, (shift_x, shift_y))
        aligned_frames.append(aligned)
    aligned_frames[-1] = aligned_frames[0].copy()
    return aligned_frames


processor.run_skill_processor = run_skill_processor
processor.extract_frames = load_final_frames


if __name__ == "__main__":
    processor.main()
