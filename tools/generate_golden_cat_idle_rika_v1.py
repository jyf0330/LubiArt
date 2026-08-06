from __future__ import annotations

import argparse
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/generate_moss_stone_wyrmling_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("golden_cat_rika_base", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Rika helper: {BASE_SCRIPT}")
rika = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rika)

OUTPUT_ROOT = ROOT / "output/sprite_animations/golden_cat_idle_rika_v1"
SOURCE_DIR = OUTPUT_ROOT / "source"
RAW_DIR = OUTPUT_ROOT / "raw"
MANIFEST_DIR = OUTPUT_ROOT / "manifests"

MASTER_PATH = (
    ROOT
    / "output/sprite_animations/golden_cat_idle_breath_v2/idle-1.png"
)
TRANSPARENT_INPUT_PATH = SOURCE_DIR / "golden_cat_transparent_128_v1.png"
RIKA_INPUT_PATH = SOURCE_DIR / "golden_cat_rika_start_128_v1.png"
INPUT_PREVIEW_PATH = OUTPUT_ROOT / "golden_cat_rika_input_4x_v1.png"
PROMPT_PATH = SOURCE_DIR / "prompt-used.txt"

EXPECTED_COST = 5
BACKGROUND_RGB = (0, 64, 64)

PROMPT = (
    "front-facing slightly top-down three-quarter-view golden cat-like creature "
    "performs one slow seamless grounded idle breathing cycle. Use the supplied image "
    "as the exact first and final pose. Keep the feet, lower-body contact point, pelvis "
    "and body center fixed with no horizontal root translation. Show a gentle inhale "
    "and exhale through only a two-to-three-pixel vertical rise and settle of the chest, "
    "head and shoulders at 128-pixel scale. Both attached arms and clawed hands make a "
    "small slow secondary motion: lift and rotate inward slightly during inhale, hold "
    "briefly, then lower and relax outward during exhale. The movement must originate "
    "from the shoulders and elbows; never detach, slide or duplicate a hand. Blink both "
    "large eyes together once near the inhale peak, with a readable half-close, fully "
    "closed hold and reopening before exhale completes. Keep the cheerful open mouth "
    "and tongue stable. Preserve the exact golden pointed-eared head, huge glossy brown "
    "eyes, cream face, brown-and-gold outfit, dark stepped pixel outlines, claw shapes, "
    "palette, proportions, material highlights, camera angle and anatomical scale. Keep "
    "the entire silhouette inside the central safe area with at least twelve pixels of "
    "dark teal background visible on every side in every frame. No whole-body swaying, "
    "walking, hopping, attack, camera movement, zoom, cropping, extra or missing limbs, "
    "detached effects, shadow, glow, blur, antialiasing, background motion or redesign."
)

PARAMS = {
    "prompt": PROMPT,
    "motion_type": "idle",
    "pixel_size": "128",
    "strength_low": 0.38,
    "strength_high": 0.38,
    "seed": 26080531,
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
        description="Prepare or submit one confirmed Golden Cat Rika idle generation."
    )
    parser.add_argument("--check-balance", action="store_true")
    parser.add_argument("--confirm-spend-5-credits", action="store_true")
    parser.add_argument("--resume-existing-job", action="store_true")
    return parser.parse_args()


def configure_helper() -> None:
    rika.IMAGE_ROOT = OUTPUT_ROOT
    rika.SOURCE_DIR = SOURCE_DIR
    rika.RAW_DIR = RAW_DIR
    rika.MANIFEST_DIR = MANIFEST_DIR
    rika.EXPECTED_COST = EXPECTED_COST


def prepare_input() -> None:
    if not MASTER_PATH.exists():
        raise FileNotFoundError(f"Accepted master frame is missing: {MASTER_PATH}")
    with Image.open(MASTER_PATH) as source_image:
        rgba = source_image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Accepted master frame is fully transparent")
    subject = rgba.crop(bbox)
    max_subject_size = 100
    scale = min(max_subject_size / subject.width, max_subject_size / subject.height)
    resized_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(resized_size, Image.Resampling.NEAREST)

    transparent = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    paste_position = ((128 - subject.width) // 2, 118 - subject.height)
    transparent.alpha_composite(subject, paste_position)
    rika.save_image_once(transparent, TRANSPARENT_INPUT_PATH)

    solid = Image.new("RGB", (128, 128), BACKGROUND_RGB)
    solid.paste(transparent.convert("RGB"), mask=transparent.getchannel("A"))
    rika.save_image_once(solid, RIKA_INPUT_PATH)
    rika.save_image_once(
        solid.resize((512, 512), Image.Resampling.NEAREST), INPUT_PREVIEW_PATH
    )
    rika.write_text_once(PROMPT, PROMPT_PATH)
    print(f"MASTER_ALPHA_BBOX={bbox}")
    print(f"SUBJECT_SIZE={resized_size}")
    print(f"SUBJECT_PASTE={paste_position}")
    print(f"PREPARED_INPUT={RIKA_INPUT_PATH}")


def check_balance() -> None:
    _, key_source = rika.get_latest_api_key()
    credits = rika.read_credits()
    print(f"KEY_SOURCE={key_source}")
    print("AUTHENTICATION=SUCCESS")
    print(f"CREDITS={credits}")


def submit_once() -> None:
    submission_path = MANIFEST_DIR / "submission.json"
    job_path = MANIFEST_DIR / "job.json"
    if submission_path.exists() or job_path.exists():
        raise FileExistsError(
            "A Rika submission record already exists; refusing another paid call"
        )

    _, key_source = rika.get_latest_api_key()
    credits_before = rika.read_credits()
    if credits_before < EXPECTED_COST:
        raise RuntimeError(
            f"Insufficient credits: {credits_before}; {EXPECTED_COST} required"
        )

    encoded = rika.encode_png(RIKA_INPUT_PATH)
    payload = {"image_base64": [encoded, encoded], "params": PARAMS}
    print(f"KEY_SOURCE={key_source}")
    print("AUTHENTICATION=SUCCESS")
    print(f"CREDITS_BEFORE={credits_before}")
    print("SUBMITTING_ONE_AUTHORIZED_GENERATION=YES")
    created = rika.request_json("POST", "generate", payload, timeout=180)
    generation_id = str(created.get("gen_id", ""))
    if not generation_id:
        raise RuntimeError(f"Rika response did not include gen_id: {created}")

    MANIFEST_DIR.mkdir(parents=True, exist_ok=True)
    rika.write_json_once(
        submission_path,
        {
            "service": "Rika AI",
            "endpoint": f"{rika.BASE_URL}/generate",
            "gen_id": generation_id,
            "submitted_at": datetime.now(timezone.utc).isoformat(),
            "expected_cost_credits": EXPECTED_COST,
            "credits_before": credits_before,
            "key_source": key_source,
            "input_images": [
                RIKA_INPUT_PATH.relative_to(ROOT).as_posix(),
                RIKA_INPUT_PATH.relative_to(ROOT).as_posix(),
            ],
            "accepted_master": MASTER_PATH.relative_to(ROOT).as_posix(),
            "params": PARAMS,
        },
    )
    print(f"GEN_ID={generation_id}")
    rika.poll_and_download(generation_id, credits_before)


def resume_existing_job() -> None:
    submission_path = MANIFEST_DIR / "submission.json"
    if not submission_path.exists():
        raise FileNotFoundError("No recorded Rika submission is available to resume")
    submission = json.loads(submission_path.read_text(encoding="utf-8"))
    generation_id = str(submission.get("gen_id", ""))
    if not generation_id:
        raise RuntimeError("Recorded submission has no gen_id")
    _, key_source = rika.get_latest_api_key()
    credits_now = rika.read_credits()
    print(f"KEY_SOURCE={key_source}")
    print("AUTHENTICATION=SUCCESS")
    print(f"CREDITS_NOW={credits_now}")
    print("SUBMITTING_NEW_GENERATION=NO")
    rika.poll_and_download(generation_id, int(submission["credits_before"]))


def main() -> None:
    args = parse_args()
    configure_helper()
    prepare_input()
    if args.confirm_spend_5_credits and args.resume_existing_job:
        raise ValueError("Choose submission or resume, not both")
    if args.check_balance:
        check_balance()
    elif args.resume_existing_job:
        resume_existing_job()
    elif args.confirm_spend_5_credits:
        submit_once()
    else:
        print("PREPARE_ONLY=YES")


if __name__ == "__main__":
    main()
