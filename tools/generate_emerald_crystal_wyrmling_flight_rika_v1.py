from __future__ import annotations

import argparse
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/generate_moss_stone_wyrmling_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("emerald_wyrmling_rika_base", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Rika helper: {BASE_SCRIPT}")
rika = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rika)

VERSION_ROOT = (
    ROOT
    / "art/images/shared/pets/animations/emerald_crystal_wyrmling/flight_move_v1"
)
SOURCE_DIR = VERSION_ROOT / "source"
RAW_DIR = VERSION_ROOT / "raw"
MANIFEST_DIR = (
    ROOT
    / "art/manifests/shared/pets/animations/emerald_crystal_wyrmling/flight_move_v1"
)
SOURCE_PATH = SOURCE_DIR / "emerald_crystal_wyrmling_source_v1.png"
TRANSPARENT_INPUT_PATH = SOURCE_DIR / "emerald_crystal_wyrmling_transparent_128_v1.png"
RIKA_INPUT_PATH = SOURCE_DIR / "emerald_crystal_wyrmling_rika_128_v1.png"
INPUT_PREVIEW_PATH = ROOT / "output/emerald_crystal_wyrmling_rika_input_4x_v1.png"
PROMPT_PATH = SOURCE_DIR / "prompt-used.txt"

EXPECTED_COST = 5
FRAME_SIZE = (128, 128)
MAX_SUBJECT_SIZE = 96
BACKGROUND_RGB = (0, 64, 64)

PROMPT = (
    "right-facing three-quarter side-view cute emerald crystal baby dragon performs "
    "one seamless in-place flying movement cycle. Both large bat-like crystal wings "
    "execute one readable full flap: begin raised and open, sweep downward with a "
    "strong downstroke, reach the lowest folded-down position, rebound upward, and "
    "return exactly to the starting pose. Keep the dragon continuously airborne for "
    "the entire cycle; all four small legs hang or tuck naturally beneath the belly "
    "and never touch a ground line. Add only subtle vertical hover buoyancy and a "
    "small delayed tail follow-through while the torso and head remain centered with "
    "no horizontal travel. Preserve the exact original identity: lavender-purple "
    "head and body, emerald-green body accents, luminous lime-green wing membranes, "
    "purple wing borders, large violet eye, curled purple tail with green tip, exact "
    "silhouette, proportions, facial expression, palette, hard black pixel outline, "
    "and crisp blocky pixel clusters. Keep the complete silhouette inside the frame "
    "with generous empty teal background around every wing tip and the tail. No "
    "walking, running, jumping, landing, forward travel, turning, camera movement, "
    "zoom, cropped wings, cropped tail, extra limbs, extra wings, redesign, detached "
    "effects, dust, shadow, projectiles, blur, antialiasing, or background motion."
)

PARAMS = {
    "prompt": PROMPT,
    "motion_type": "idle",
    "pixel_size": "128",
    "strength_low": 0.52,
    "strength_high": 0.52,
    "seed": 26080517,
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare, submit, or resume one authorized emerald wyrmling flight job."
    )
    parser.add_argument("--check-balance", action="store_true")
    parser.add_argument("--confirm-spend-5-credits", action="store_true")
    parser.add_argument("--resume-existing-job", action="store_true")
    return parser.parse_args()


def prepare_input() -> None:
    if not SOURCE_PATH.exists():
        raise FileNotFoundError(f"Project-local source is missing: {SOURCE_PATH}")
    with Image.open(SOURCE_PATH) as source_image:
        subject = rika.isolate_subject(source_image)

    scale = min(MAX_SUBJECT_SIZE / subject.width, MAX_SUBJECT_SIZE / subject.height)
    resized_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(resized_size, Image.Resampling.NEAREST)
    transparent = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    paste_position = (
        (FRAME_SIZE[0] - subject.width) // 2,
        (FRAME_SIZE[1] - subject.height) // 2,
    )
    transparent.alpha_composite(subject, paste_position)
    rika.save_image_once(transparent, TRANSPARENT_INPUT_PATH)

    solid = Image.new("RGB", FRAME_SIZE, BACKGROUND_RGB)
    solid.paste(transparent.convert("RGB"), mask=transparent.getchannel("A"))
    rika.save_image_once(solid, RIKA_INPUT_PATH)
    rika.save_image_once(
        solid.resize((512, 512), Image.Resampling.NEAREST), INPUT_PREVIEW_PATH
    )
    rika.write_text_once(PROMPT, PROMPT_PATH)
    print(f"PREPARED_INPUT={RIKA_INPUT_PATH}")
    print(f"SUBJECT_SIZE={resized_size}")
    print(f"SUBJECT_PASTE={paste_position}")


def configure_base_helper() -> None:
    rika.IMAGE_ROOT = VERSION_ROOT
    rika.SOURCE_DIR = SOURCE_DIR
    rika.RAW_DIR = RAW_DIR
    rika.MANIFEST_DIR = MANIFEST_DIR
    rika.SOURCE_PATH = SOURCE_PATH
    rika.TRANSPARENT_INPUT_PATH = TRANSPARENT_INPUT_PATH
    rika.RIKA_INPUT_PATH = RIKA_INPUT_PATH
    rika.PROMPT_PATH = PROMPT_PATH
    rika.INPUT_PREVIEW_PATH = INPUT_PREVIEW_PATH
    rika.EXPECTED_COST = EXPECTED_COST
    rika.PROMPT = PROMPT
    rika.PARAMS = PARAMS


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
    payload = {
        "image_base64": [
            rika.encode_png(RIKA_INPUT_PATH),
            rika.encode_png(RIKA_INPUT_PATH),
        ],
        "params": PARAMS,
    }
    print(f"KEY_SOURCE={key_source}")
    print("AUTHENTICATION=SUCCESS")
    print(f"CREDITS_BEFORE={credits_before}")
    print("SUBMITTING_ONE_AUTHORIZED_GENERATION=YES")
    created = rika.request_json("POST", "generate", payload, timeout=180)
    generation_id = created.get("gen_id")
    if not generation_id:
        raise RuntimeError(f"Rika response did not include gen_id: {created}")

    rika.write_json_once(
        submission_path,
        {
            "service": "Rika AI",
            "endpoint": f"{rika.BASE_URL}/generate",
            "gen_id": generation_id,
            "submitted_at": datetime.now(timezone.utc).isoformat(),
            "expected_cost_credits": EXPECTED_COST,
            "credits_before": credits_before,
            "input_images": [
                RIKA_INPUT_PATH.relative_to(ROOT).as_posix(),
                RIKA_INPUT_PATH.relative_to(ROOT).as_posix(),
            ],
            "source_image": SOURCE_PATH.relative_to(ROOT).as_posix(),
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
    print(f"RESUMING_GEN_ID={generation_id}")
    print("SUBMITTING_NEW_GENERATION=NO")
    rika.poll_and_download(generation_id, int(submission["credits_before"]))


def main() -> None:
    args = parse_args()
    configure_base_helper()
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
