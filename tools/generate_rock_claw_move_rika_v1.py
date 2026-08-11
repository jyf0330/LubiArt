from __future__ import annotations

import importlib.util
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/generate_moss_stone_wyrmling_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("rock_claw_rika_base", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Rika helper: {BASE_SCRIPT}")
rika = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rika)

IMAGE_ROOT = ROOT / "output/sprite_animation_candidates/rock_claw/move_v1"
SOURCE_DIR = IMAGE_ROOT / "source"
RAW_DIR = IMAGE_ROOT / "raw"
MANIFEST_DIR = ROOT / "output/sprite_animation_candidates/_manifests/rock_claw/move_v1"
SOURCE_PATH = ROOT / "art/images/shared/pets/sheets/slices/pet_style_007_rock_claw.png"
CLEAN_SOURCE_PATH = SOURCE_DIR / "rock_claw_source_v1.png"
TRANSPARENT_INPUT_PATH = SOURCE_DIR / "rock_claw_transparent_128_v1.png"
RIKA_INPUT_PATH = SOURCE_DIR / "rock_claw_rika_start_128_v1.png"
PROMPT_PATH = SOURCE_DIR / "prompt-used.txt"
INPUT_PREVIEW_PATH = ROOT / "output/rock_claw_rika_input_4x_v1.png"

PROMPT = (
    "Front-facing slightly top-down three-quarter-view Rock Claw creature performs one "
    "slow seamless in-place forward walking cycle. This is a DEPTH walk toward and away "
    "from the camera, never a sideways walk. Lock the left foot and right foot to their "
    "original horizontal lanes: neither foot may swing outward, inward, left, or right. "
    "First, one short leg steps FORWARD IN DEPTH toward the viewer, shown mainly by that "
    "foot moving slightly lower on the image, becoming only subtly more prominent, and "
    "taking weight, while the opposite short leg retracts BACKWARD IN DEPTH under the body, "
    "shown slightly higher and a little more occluded. Then pass through the neutral pose "
    "and exchange the two legs for the second half of the cycle. The feet alternate front "
    "and back, not left and right. Keep the pelvis, torso center, face, and overall root "
    "fixed in place with only a tiny vertical heavy-stone compression during weight transfer. "
    "Both feet return to one stable ground-contact line at the loop seam. Preserve the exact "
    "identity from the input image: huge broad layered gray stone head and torso, black angular "
    "brow markings, narrow magenta-and-white eyes, small straight mouth with two white lower "
    "fangs, massive symmetric rock arms, blue-gray crystal spikes on both forearms, two very "
    "short thick dark stone legs, stepped black pixel outline, palette, proportions, camera "
    "angle, silhouette, shading clusters, and crisp hard-edged pixel-art material. Keep both "
    "arms and crystal spikes attached and almost still; allow only minimal delayed shoulder "
    "settling. No sideways stride, no lateral leg spread, no crab walk, no skating, no sliding, "
    "no body left-right sway, no turning, no camera movement, no zoom, no running, no hopping, "
    "no extra or missing legs, no duplicated feet, no limb deformation, no detached stones, "
    "no dust, no shadow, no glow, no effects, no motion blur, and no background motion. Keep "
    "the complete silhouette safely inside the frame in every phase."
)

PARAMS = {
    "prompt": PROMPT,
    "motion_type": "walk",
    "pixel_size": "128",
    "strength_low": 0.44,
    "strength_high": 0.44,
    "seed": 26081007,
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


def prepare_input() -> None:
    with Image.open(SOURCE_PATH) as source_image:
        source = source_image.convert("RGBA")
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("Rock Claw source image has no visible pixels")
    subject = source.crop(bbox)

    max_width = 112
    max_height = 104
    scale = min(max_width / subject.width, max_height / subject.height)
    resized_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(resized_size, Image.Resampling.NEAREST)

    transparent = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    paste_x = (128 - subject.width) // 2
    paste_y = 116 - subject.height
    transparent.alpha_composite(subject, (paste_x, paste_y))

    solid = Image.new("RGB", (128, 128), rika.BACKGROUND_RGB)
    solid.paste(transparent.convert("RGB"), mask=transparent.getchannel("A"))

    rika.save_image_once(source, CLEAN_SOURCE_PATH)
    rika.save_image_once(transparent, TRANSPARENT_INPUT_PATH)
    rika.save_image_once(solid, RIKA_INPUT_PATH)
    rika.save_image_once(
        solid.resize((512, 512), Image.Resampling.NEAREST), INPUT_PREVIEW_PATH
    )
    rika.write_text_once(PROMPT, PROMPT_PATH)

    print(f"PREPARED_INPUT={RIKA_INPUT_PATH}")
    print(f"SOURCE_ALPHA_BBOX={bbox}")
    print(f"SUBJECT_SIZE={resized_size}")
    print(f"SUBJECT_PASTE=({paste_x}, {paste_y})")


def configure_base() -> None:
    rika.IMAGE_ROOT = IMAGE_ROOT
    rika.SOURCE_DIR = SOURCE_DIR
    rika.RAW_DIR = RAW_DIR
    rika.MANIFEST_DIR = MANIFEST_DIR
    rika.SOURCE_PATH = SOURCE_PATH
    rika.CLEAN_SOURCE_PATH = CLEAN_SOURCE_PATH
    rika.TRANSPARENT_INPUT_PATH = TRANSPARENT_INPUT_PATH
    rika.RIKA_INPUT_PATH = RIKA_INPUT_PATH
    rika.PROMPT_PATH = PROMPT_PATH
    rika.INPUT_PREVIEW_PATH = INPUT_PREVIEW_PATH
    rika.PROMPT = PROMPT
    rika.PARAMS = PARAMS
    rika.prepare_input = prepare_input


def main() -> None:
    configure_base()
    rika.main()


if __name__ == "__main__":
    main()
