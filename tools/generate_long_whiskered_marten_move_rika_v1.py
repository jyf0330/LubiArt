from __future__ import annotations

import argparse
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools/generate_moss_stone_wyrmling_move_rika_v1.py"
spec = importlib.util.spec_from_file_location("long_whiskered_marten_rika_base", BASE_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load Rika helper: {BASE_SCRIPT}")
rika = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rika)

IMAGE_ROOT = ROOT / "art/images/shared/pets/animations/long_whiskered_marten/move_v1"
SOURCE_DIR = IMAGE_ROOT / "source"
RAW_DIR = IMAGE_ROOT / "raw"
MANIFEST_DIR = ROOT / "art/manifests/shared/pets/animations/long_whiskered_marten/move_v1"

SOURCE_PATH = SOURCE_DIR / "long_whiskered_marten_source_v1.png"
RECOVERED_SOURCE_PATH = SOURCE_DIR / "long_whiskered_marten_recovered_v1.png"
TRANSPARENT_INPUT_PATH = SOURCE_DIR / "long_whiskered_marten_transparent_128_v2.png"
RIKA_INPUT_PATH = SOURCE_DIR / "long_whiskered_marten_rika_start_128_v2.png"
INPUT_PREVIEW_PATH = ROOT / "output/long_whiskered_marten_rika_input_4x_v2.png"
PROMPT_PATH = SOURCE_DIR / "prompt-used.txt"

EXPECTED_COST = 5
BACKGROUND_RGB = (0, 64, 64)

PROMPT = (
    "right-facing three-quarter side-view long-haired cream-and-brown marten creature "
    "performs one slow seamless in-place quadruped walking cycle that reads as moving "
    "across exactly one grid cell. Use clear alternating four-legged footfalls: near front "
    "paw and far rear paw step, then far front paw and near rear paw step. Keep every paw "
    "connected to its leg and returning to one stable feet baseline. Add only a small natural "
    "shoulder-and-hip weight shift, subtle head settling, and gentle delayed follow-through "
    "through the enormous fluffy cream tail and the two very long backward-swept dark slate "
    "whisker plumes. Keep the body root fixed with no horizontal translation and no extra "
    "frame-to-frame drift. Preserve the exact identity, elongated low quadruped silhouette, "
    "very large layered cream tail, warm taupe-brown body, pale cream face and chest, bright "
    "blue visible eye, dark charcoal nose, dark hind leg, small pale paws, black stepped pixel "
    "outline, palette, proportions, face, fur blocks, original camera angle and pixel-art "
    "material. Keep the full tail, whisker plumes, ears, paws and nose inside the frame with "
    "generous empty background. No running, hopping, jumping, galloping, sliding, landing, "
    "turning, camera movement, zoom, long-legged redesign, body inflation, extra legs, missing "
    "legs, extra tails, detached fur, wind trails, dust, ground shadow, projectile, glow, blur, "
    "antialiasing or background motion."
)

PARAMS = {
    "prompt": PROMPT,
    "motion_type": "walk",
    "pixel_size": "128",
    "strength_low": 0.45,
    "strength_high": 0.45,
    "seed": 26080531,
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
        description="Prepare or submit one confirmed Long-Whiskered Marten move generation."
    )
    parser.add_argument("--check-balance", action="store_true")
    parser.add_argument("--confirm-spend-5-credits", action="store_true")
    parser.add_argument("--resume-existing-job", action="store_true")
    return parser.parse_args()


def recover_subject(source_image: Image.Image) -> Image.Image:
    """Recover pale fur that was exported as transparent against a white preview."""
    source = source_image.convert("RGBA").resize((512, 512), Image.Resampling.NEAREST)
    rgba = np.array(source)
    luma = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_RGB2GRAY)
    dark_outline = ((luma <= 80) & (rgba[:, :, 3] > 0)).astype(np.uint8) * 255
    closed_outline = cv2.morphologyEx(
        dark_outline,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)),
    )

    open_space = cv2.bitwise_not(closed_outline)
    flood = open_space.copy()
    flood_mask = np.zeros((514, 514), np.uint8)
    cv2.floodFill(flood, flood_mask, (0, 0), 128)
    enclosed = np.where(flood == 255, 255, 0).astype(np.uint8)
    silhouette = cv2.bitwise_or(closed_outline, enclosed)

    component_count, labels, stats, _ = cv2.connectedComponentsWithStats(silhouette, 8)
    if component_count <= 1:
        raise RuntimeError("Could not recover the marten silhouette from the source image")
    largest_label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    silhouette = np.where(labels == largest_label, 255, 0).astype(np.uint8)

    rgba[:, :, 3] = silhouette
    ys, xs = np.where(silhouette > 0)
    crop_box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    return Image.fromarray(rgba, "RGBA").crop(crop_box)


def prepare_input() -> None:
    if not SOURCE_PATH.exists():
        raise FileNotFoundError(f"Project-local source is missing: {SOURCE_PATH}")
    with Image.open(SOURCE_PATH) as source_image:
        subject = recover_subject(source_image)
    rika.save_image_once(subject, RECOVERED_SOURCE_PATH)

    max_subject_size = 108
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
    rika.save_image_once(transparent, TRANSPARENT_INPUT_PATH)

    solid = Image.new("RGB", (128, 128), BACKGROUND_RGB)
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
                RIKA_INPUT_PATH.relative_to(ROOT).as_posix(),
                RIKA_INPUT_PATH.relative_to(ROOT).as_posix(),
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
