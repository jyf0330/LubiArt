from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
V1_SCRIPT = ROOT / "tools/generate_tide_crow_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("tide_crow_move_v1", V1_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Tide Crow Rika helper: {V1_SCRIPT}")
v1 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v1)

IMAGE_ROOT = ROOT / "art/images/shared/pets/animations/tide_crow/move_v2"
SOURCE_DIR = IMAGE_ROOT / "source"
RAW_DIR = IMAGE_ROOT / "raw"
MANIFEST_DIR = ROOT / "art/manifests/shared/pets/animations/tide_crow/move_v2"
SOURCE_PATH = SOURCE_DIR / "tide_crow_source_v1.png"
TRANSPARENT_INPUT_PATH = SOURCE_DIR / "tide_crow_transparent_128_v2.png"
RIKA_INPUT_PATH = SOURCE_DIR / "tide_crow_rika_start_128_v2.png"
INPUT_PREVIEW_PATH = ROOT / "output/tide_crow_rika_input_4x_v2.png"
PROMPT_PATH = SOURCE_DIR / "prompt-used.txt"

EXPECTED_COST = 5
BACKGROUND_RGB = (0, 64, 64)

PROMPT = (
    "left-facing three-quarter side-view blue-black crow creature wearing oversized "
    "cyan goggles performs one seamless in-place flying movement cycle. Keep the bird "
    "airborne throughout. Animate a clear readable wingbeat in this order: wings rise "
    "and gather, wings spread to the widest silhouette, a strong downward power stroke, "
    "lowest compressed wing position, then a smooth recovery back to the supplied first "
    "pose. Keep the entire body and every wing tip inside the central 70 percent of each "
    "frame with at least 12 pixels of dark teal background visible on all four sides in "
    "every pose. The body may bob vertically by only a few pixels in response to the "
    "wingbeat; the head and torso stay centered with no horizontal root translation. Keep "
    "the tail and feet attached with small delayed follow-through, and keep the beak closed. "
    "Preserve the exact crow identity, left-facing pose, compact rounded body, layered dark "
    "navy wing and tail feathers, pale blue head and chest feathers, charcoal beak and feet, "
    "large reflective cyan goggles, palette, proportions, crisp hard black pixel outlines, "
    "stepped pixel clusters and original anatomical scale. No walking, running, hopping, "
    "landing, forward travel, turning, camera movement, zoom, cropped wing tips, cropped "
    "tail, extra wings, extra legs, detached feathers, wind trails, dust, ground shadow, "
    "projectile, glow, blur, antialiasing, or background motion."
)

PARAMS = {
    "prompt": PROMPT,
    "motion_type": "idle",
    "pixel_size": "128",
    "strength_low": 0.50,
    "strength_high": 0.50,
    "seed": 26080522,
    "fix_seed": True,
    "length": 33,
    "use_mid_image": False,
    "use_end_image": True,
    "scale_factor": 6,
    "use_padding": True,
    "padding_position": "mc",
    "use_quantization": False,
    "quantization_colors": 32,
    "bg_color": "#004040",
    "attack_type": "melee",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare or submit one confirmed Tide Crow move v2 generation."
    )
    parser.add_argument("--check-balance", action="store_true")
    parser.add_argument("--confirm-spend-5-credits", action="store_true")
    parser.add_argument("--resume-existing-job", action="store_true")
    return parser.parse_args()


def configure_v1() -> None:
    v1.IMAGE_ROOT = IMAGE_ROOT
    v1.SOURCE_DIR = SOURCE_DIR
    v1.RAW_DIR = RAW_DIR
    v1.MANIFEST_DIR = MANIFEST_DIR
    v1.SOURCE_PATH = SOURCE_PATH
    v1.TRANSPARENT_INPUT_PATH = TRANSPARENT_INPUT_PATH
    v1.RIKA_INPUT_PATH = RIKA_INPUT_PATH
    v1.INPUT_PREVIEW_PATH = INPUT_PREVIEW_PATH
    v1.PROMPT_PATH = PROMPT_PATH
    v1.PROMPT = PROMPT
    v1.PARAMS = PARAMS
    v1.EXPECTED_COST = EXPECTED_COST
    v1.rika.IMAGE_ROOT = IMAGE_ROOT
    v1.rika.SOURCE_DIR = SOURCE_DIR
    v1.rika.RAW_DIR = RAW_DIR
    v1.rika.MANIFEST_DIR = MANIFEST_DIR
    v1.rika.EXPECTED_COST = EXPECTED_COST


def prepare_input() -> None:
    if not SOURCE_PATH.exists():
        raise FileNotFoundError(f"Project-local source is missing: {SOURCE_PATH}")
    with Image.open(SOURCE_PATH) as source_image:
        subject = v1.rika.isolate_subject(source_image)

    max_subject_size = 84
    scale = min(max_subject_size / subject.width, max_subject_size / subject.height)
    resized_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(resized_size, Image.Resampling.NEAREST)

    transparent = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    paste_position = (
        (128 - subject.width) // 2,
        (128 - subject.height) // 2,
    )
    transparent.alpha_composite(subject, paste_position)
    v1.rika.save_image_once(transparent, TRANSPARENT_INPUT_PATH)

    solid = Image.new("RGB", (128, 128), BACKGROUND_RGB)
    solid.paste(transparent.convert("RGB"), mask=transparent.getchannel("A"))
    v1.rika.save_image_once(solid, RIKA_INPUT_PATH)
    v1.rika.save_image_once(
        solid.resize((512, 512), Image.Resampling.NEAREST), INPUT_PREVIEW_PATH
    )
    v1.rika.write_text_once(PROMPT, PROMPT_PATH)
    print(f"PREPARED_INPUT={RIKA_INPUT_PATH}")
    print(f"SUBJECT_SIZE={resized_size}")
    print(f"SUBJECT_PASTE={paste_position}")
    print("USE_PADDING=TRUE")


def main() -> None:
    args = parse_args()
    configure_v1()
    prepare_input()
    if args.confirm_spend_5_credits and args.resume_existing_job:
        raise ValueError("Choose submission or resume, not both")
    if args.check_balance:
        v1.check_balance()
    elif args.resume_existing_job:
        v1.resume_existing_job()
    elif args.confirm_spend_5_credits:
        v1.submit_once()
    else:
        print("PREPARE_ONLY=YES")


if __name__ == "__main__":
    main()
