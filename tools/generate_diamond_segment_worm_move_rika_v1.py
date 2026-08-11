from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/generate_azure_wind_feather_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("rika_move_base", BASE_SCRIPT)
rika = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(rika)

IMAGE_ROOT = ROOT / "output/sprite_animation_candidates/diamond_segment_worm/move_v1"
SOURCE_DIR = IMAGE_ROOT / "source"
RAW_DIR = IMAGE_ROOT / "raw"
MANIFEST_DIR = ROOT / "output/sprite_animation_candidates/_manifests/diamond_segment_worm/move_v1"
SOURCE_PATH = SOURCE_DIR / "diamond_segment_worm_source_v1.png"
TRANSPARENT_INPUT_PATH = SOURCE_DIR / "diamond_segment_worm_transparent_128_v1.png"
RIKA_INPUT_PATH = SOURCE_DIR / "diamond_segment_worm_rika_start_128_v1.png"
PROMPT_PATH = SOURCE_DIR / "prompt-used.txt"
INPUT_PREVIEW_PATH = SOURCE_DIR / "diamond_segment_worm_rika_input_4x_v1.png"

PROMPT = (
    "right-facing three-quarter side-view cute pink segmented crystal worm performs "
    "one slow in-place crawling cycle that reads as moving across exactly one grid "
    "cell: the front section reaches forward slightly, grips, then a smooth "
    "peristaltic compression wave travels from the head through each body segment, "
    "the rear segments bunch up and pull forward, and the entire body returns to the "
    "exact starting pose for a seamless loop; clear sequential squash and stretch of "
    "the soft pink segments, subtle coordinated pushes from the tiny underside feet, "
    "gentle delayed bob of the gray crystal crown and embedded blue gems; keep the "
    "body center and underside contact baseline fixed, no root translation, no "
    "sliding, no hopping, no turning, no camera movement; preserve the exact long "
    "pink segmented silhouette, round smiling head, blue gem eye, gray rock-crystal "
    "crown, bright cyan gemstones, black hard pixel outline, palette, proportions, "
    "face, pixel clusters and materials; no extra body segments, no extra legs, no "
    "detached effects, no background motion"
)

PARAMS = {
    "prompt": PROMPT,
    "motion_type": "walk",
    "pixel_size": "128",
    "strength_low": 0.48,
    "strength_high": 0.48,
    "seed": 260805,
    "fix_seed": True,
    "length": 33,
    "use_mid_image": False,
    "use_end_image": True,
    "scale_factor": 6,
    "use_padding": False,
    "padding_position": "mc",
    "use_quantization": False,
    "quantization_colors": 32,
    "bg_color": "#004040",
    "attack_type": "melee",
}


def configure_base() -> None:
    rika.IMAGE_ROOT = IMAGE_ROOT
    rika.SOURCE_DIR = SOURCE_DIR
    rika.RAW_DIR = RAW_DIR
    rika.MANIFEST_DIR = MANIFEST_DIR
    rika.SOURCE_PATH = SOURCE_PATH
    rika.TRANSPARENT_INPUT_PATH = TRANSPARENT_INPUT_PATH
    rika.RIKA_INPUT_PATH = RIKA_INPUT_PATH
    rika.PROMPT_PATH = PROMPT_PATH
    rika.INPUT_PREVIEW_PATH = INPUT_PREVIEW_PATH
    rika.PROMPT = PROMPT
    rika.PARAMS = PARAMS


def main() -> None:
    configure_base()
    rika.main()


if __name__ == "__main__":
    main()
