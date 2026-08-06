from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/replace_golden_cat_blink_frames_v3.py"
spec = importlib.util.spec_from_file_location("golden_cat_blink_v3", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load v3 replacement helper: {BASE_SCRIPT}")
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)

pipeline.SOURCE_ROOT = ROOT / "output/sprite_animations/golden_cat_idle_rika_blink_v3"
pipeline.OUTPUT_ROOT = ROOT / "output/sprite_animations/golden_cat_idle_rika_blink_v4"
pipeline.OUTPUT_VERSION = 4
pipeline.SOURCE_VERSION_NAME = "golden_cat_idle_rika_blink_v3"
pipeline.FRAME_DIR = pipeline.OUTPUT_ROOT / "frames"
pipeline.SOURCE_FRAME_DIR = pipeline.OUTPUT_ROOT / "source_frames"
pipeline.QC_DIR = pipeline.OUTPUT_ROOT / "qc"
pipeline.USER_FRAME_10 = Path(r"C:\Users\jyf\Desktop\10.png")
pipeline.USER_FRAME_11 = Path(r"C:\Users\jyf\Desktop\11.png")


if __name__ == "__main__":
    pipeline.main()
