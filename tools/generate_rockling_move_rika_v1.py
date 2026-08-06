from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/generate_moss_stone_wyrmling_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("rockling_rika_base", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Rika helper: {BASE_SCRIPT}")
rika = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rika)

IMAGE_ROOT = ROOT / "art/images/shared/pets/animations/rockling/move_v1"
SOURCE_DIR = IMAGE_ROOT / "source"
RAW_DIR = IMAGE_ROOT / "raw"
MANIFEST_DIR = ROOT / "art/manifests/shared/pets/animations/rockling/move_v1"
SOURCE_PATH = SOURCE_DIR / "rockling_source_v1.png"
TRANSPARENT_INPUT_PATH = SOURCE_DIR / "rockling_transparent_128_v1.png"
RIKA_INPUT_PATH = SOURCE_DIR / "rockling_rika_start_128_v1.png"
PROMPT_PATH = SOURCE_DIR / "prompt-used.txt"
INPUT_PREVIEW_PATH = ROOT / "output/rockling_rika_input_4x_v1.png"

PROMPT = (
    "front-facing slightly three-quarter-view cute round orange baby rock creature "
    "performs one slow seamless in-place walking cycle that reads as moving across "
    "exactly one grid cell. Use clear alternating four-legged footfalls: the near-left "
    "and far-right short rock legs step, then the near-right and far-left legs step. "
    "Each foot lifts only slightly, plants with believable heavy stone weight, and "
    "returns to one stable ground baseline. Add a very small natural weight transfer "
    "inside the body, but keep the huge round boulder torso centered and do not let it "
    "roll, slide, hop, squash, inflate, or drift. Keep all four legs continuously "
    "connected to the body and clearly readable. Preserve the exact identity: enormous "
    "round orange stone body, warm amber and burnt-orange pixel clusters, two large dark "
    "plum glossy rectangular eyes with white highlights, tiny straight dark mouth, pink "
    "cheeks, gray-brown embedded rock patches, small olive moss marks, four very short "
    "orange rock legs with dark feet, thick black stepped pixel outline, palette, "
    "proportions, face, material, original camera angle, and crisp hard-edged pixel-art "
    "style. Keep the full silhouette and every foot inside the frame with generous empty "
    "background. No running, galloping, jumping, landing, turning, camera movement, zoom, "
    "extra legs, missing legs, detached rocks, dust, ground shadow, projectile, glow, "
    "motion blur, antialiasing, or background motion."
)

PARAMS = {
    "prompt": PROMPT,
    "motion_type": "walk",
    "pixel_size": "128",
    "strength_low": 0.46,
    "strength_high": 0.46,
    "seed": 26080521,
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
