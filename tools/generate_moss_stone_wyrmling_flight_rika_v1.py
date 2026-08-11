from __future__ import annotations

import argparse
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/generate_moss_stone_wyrmling_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("moss_wyrmling_rika_base", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Rika helper: {BASE_SCRIPT}")
rika = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rika)

IMAGE_ROOT = ROOT / "output/sprite_animation_candidates/moss_stone_wyrmling/flight_v1"
SOURCE_DIR = IMAGE_ROOT / "source"
RAW_DIR = IMAGE_ROOT / "raw"
MANIFEST_DIR = ROOT / "output/sprite_animation_candidates/_manifests/moss_stone_wyrmling/flight_v1"

START_SOURCE = SOURCE_DIR / "frame_001_first_160.png"
MID_SOURCE = SOURCE_DIR / "frame_002_airborne_mid_face_scale_matched_160.png"
START_INPUT = SOURCE_DIR / "rika_start_128_v1.png"
MID_INPUT = SOURCE_DIR / "rika_mid_128_v1.png"
END_INPUT = SOURCE_DIR / "rika_end_128_v1.png"
START_PREVIEW = ROOT / "output/moss_stone_wyrmling_flight_start_rika_4x_v1.png"
MID_PREVIEW = ROOT / "output/moss_stone_wyrmling_flight_mid_rika_4x_v1.png"
PROMPT_PATH = SOURCE_DIR / "prompt-used.txt"

EXPECTED_COST = 5
SOURCE_SIZE = (160, 160)
RIKA_SIZE = (128, 128)
BACKGROUND_RGB = (0, 64, 64)

PROMPT = (
    "right-facing three-quarter side-view cute moss-covered baby stone dragon performs "
    "one continuous in-place flight cycle. The supplied START image is the exact first "
    "keyframe, the supplied MID image is the exact middle airborne keyframe, and the "
    "supplied END image is the exact same image as START. Animate in this order: begin "
    "from START, lift the body into flight as both bat wings open, transition smoothly "
    "into the supplied MID pose, hold a clearly airborne silhouette while all four hands "
    "and feet hang naturally and visibly below the belly, perform a readable wing flap, "
    "then reverse smoothly and return exactly to END. Keep the torso and head centered "
    "horizontally with only restrained vertical flight motion. Preserve the exact cream "
    "stone body, olive and lime moss patches, large amber-orange eye, gray-purple horns, "
    "dark purple bat wings with gray-purple borders, curled tail, four-limb anatomy, "
    "proportions, face scale, palette, black hard pixel outline, crisp pixel clusters and "
    "original camera scale. Keep generous empty background around the complete silhouette. "
    "No walking, running, forward travel, turning, camera movement, zoom, cropped wing tips, "
    "cropped feet, extra limbs, extra wings, detached effects, dust, ground shadow, blur, "
    "antialiasing, or background motion."
)

PARAMS = {
    "prompt": PROMPT,
    "motion_type": "jump",
    "pixel_size": "128",
    "strength_low": 0.55,
    "strength_high": 0.55,
    "seed": 26080491,
    "fix_seed": True,
    "length": 33,
    "use_mid_image": True,
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
        description="Prepare or submit one confirmed padded Rika flight generation."
    )
    parser.add_argument("--check-balance", action="store_true")
    parser.add_argument("--confirm-spend-5-credits", action="store_true")
    parser.add_argument("--resume-existing-job", action="store_true")
    return parser.parse_args()


def prepare_frame(source_path: Path, output_path: Path, preview_path: Path) -> None:
    with Image.open(source_path) as source:
        rgba = source.convert("RGBA")
    if rgba.size != SOURCE_SIZE:
        raise ValueError(f"Expected a 160x160 keyframe: {source_path}, got {rgba.size}")
    resized = rgba.resize(RIKA_SIZE, Image.Resampling.NEAREST)
    solid = Image.new("RGB", RIKA_SIZE, BACKGROUND_RGB)
    solid.paste(resized.convert("RGB"), mask=resized.getchannel("A"))
    rika.save_image_once(solid, output_path)
    rika.save_image_once(
        solid.resize((512, 512), Image.Resampling.NEAREST), preview_path
    )


def prepare_input() -> None:
    if not START_SOURCE.exists() or not MID_SOURCE.exists():
        raise FileNotFoundError("Project-local start or middle keyframe is missing")
    prepare_frame(START_SOURCE, START_INPUT, START_PREVIEW)
    prepare_frame(MID_SOURCE, MID_INPUT, MID_PREVIEW)
    prepare_frame(START_SOURCE, END_INPUT, START_PREVIEW)
    rika.write_text_once(PROMPT, PROMPT_PATH)
    print(f"PREPARED_START={START_INPUT}")
    print(f"PREPARED_MID={MID_INPUT}")
    print(f"PREPARED_END={END_INPUT}")
    print("USE_PADDING=TRUE")
    print("PADDING_POSITION=mc")


def configure_base_helper() -> None:
    rika.IMAGE_ROOT = IMAGE_ROOT
    rika.SOURCE_DIR = SOURCE_DIR
    rika.RAW_DIR = RAW_DIR
    rika.MANIFEST_DIR = MANIFEST_DIR
    rika.EXPECTED_COST = EXPECTED_COST


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
        raise FileExistsError("A Rika submission record already exists; refusing another paid call")

    _, key_source = rika.get_latest_api_key()
    credits_before = rika.read_credits()
    if credits_before < EXPECTED_COST:
        raise RuntimeError(f"Insufficient credits: {credits_before}; {EXPECTED_COST} required")

    payload = {
        "image_base64": [
            rika.encode_png(START_INPUT),
            rika.encode_png(MID_INPUT),
            rika.encode_png(END_INPUT),
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
            "input_images": [
                START_INPUT.relative_to(ROOT).as_posix(),
                MID_INPUT.relative_to(ROOT).as_posix(),
                END_INPUT.relative_to(ROOT).as_posix(),
            ],
            "source_keyframes": [
                START_SOURCE.relative_to(ROOT).as_posix(),
                MID_SOURCE.relative_to(ROOT).as_posix(),
                START_SOURCE.relative_to(ROOT).as_posix(),
            ],
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
