from __future__ import annotations

import argparse
import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
IMAGE_ROOT = ROOT / "output/sprite_animation_candidates/moss_stone_wyrmling/move_v1"
SOURCE_DIR = IMAGE_ROOT / "source"
RAW_DIR = IMAGE_ROOT / "raw"
MANIFEST_DIR = ROOT / "output/sprite_animation_candidates/_manifests/moss_stone_wyrmling/move_v1"
SOURCE_PATH = SOURCE_DIR / "moss_stone_wyrmling_source_v1.png"
TRANSPARENT_INPUT_PATH = SOURCE_DIR / "moss_stone_wyrmling_transparent_128_v1.png"
RIKA_INPUT_PATH = SOURCE_DIR / "moss_stone_wyrmling_rika_start_128_v1.png"
PROMPT_PATH = SOURCE_DIR / "prompt-used.txt"
INPUT_PREVIEW_PATH = ROOT / "output/moss_stone_wyrmling_rika_input_4x_v1.png"

BASE_URL = "https://api.rika-ai.com/v1/api"
BACKGROUND_RGB = (0, 64, 64)
EXPECTED_COST = 5
POLL_SECONDS = 20
MAX_POLL_SECONDS = 60 * 30

PROMPT = (
    "right-facing three-quarter side-view cute moss-covered baby stone dragon "
    "performs one seamless in-place flying movement cycle, both wings perform a "
    "clear full power flap from raised to downstroke to lowest position to rebound "
    "and back to raised, all four legs are visibly off the ground for the entire "
    "cycle and stay naturally tucked with small relaxed dangling motion beneath the "
    "belly, toes never touch a ground line, subtle vertical hover buoyancy only, "
    "stable torso center and head position, small delayed tail follow-through, no "
    "walking, no running, no jump arc, no landing, no horizontal root translation, "
    "no turning and no camera movement, preserve the exact cream stone body, olive "
    "and lime moss patches, large amber-orange eyes, gray-purple twin horns, two "
    "dark purple bat wings with gray-purple borders, curled tail, four-leg anatomy, "
    "palette, proportions, face, black hard pixel outline and crisp pixel-art "
    "material, no extra legs, no extra wings, no detached effects and no background "
    "motion"
)

PARAMS = {
    "prompt": PROMPT,
    "motion_type": "idle",
    "pixel_size": "128",
    "strength_low": 0.52,
    "strength_high": 0.52,
    "seed": 26080431,
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
        description="Prepare and optionally submit one Moss Stone Wyrmling Rika move job."
    )
    parser.add_argument(
        "--confirm-spend-5-credits",
        action="store_true",
        help="Submit exactly one explicitly authorized 5-credit Rika generation.",
    )
    parser.add_argument(
        "--resume-existing-job",
        action="store_true",
        help="Poll and download the already-recorded job without submitting again.",
    )
    return parser.parse_args()


def get_latest_api_key() -> tuple[str, str]:
    if os.name == "nt":
        import winreg

        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as handle:
                value, _ = winreg.QueryValueEx(handle, "RIKA_API_KEY")
                key = str(value).strip()
                if key:
                    return key, r"HKCU\Environment"
        except OSError:
            pass
    key = os.environ.get("RIKA_API_KEY", "").strip()
    if not key:
        raise RuntimeError("RIKA_API_KEY is not configured")
    return key, "process environment"


def request_json(
    method: str,
    relative_path: str,
    payload: dict | None = None,
    timeout: int = 120,
) -> dict:
    api_key, _ = get_latest_api_key()
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"X-API-Key": api_key}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(
        f"{BASE_URL}/{relative_path.lstrip('/')}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Rika HTTP {error.code}: {body[:500]}") from error


def read_credits() -> int:
    response = request_json("GET", "credits")
    if "credits" not in response:
        raise RuntimeError(f"Unexpected credits response: {response}")
    return int(response["credits"])


def save_image_once(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        with Image.open(path) as existing_image:
            existing = existing_image.convert(image.mode)
            if existing.size != image.size or existing.tobytes() != image.tobytes():
                raise FileExistsError(f"Refusing to overwrite a different image: {path}")
        return
    image.save(path, optimize=False)


def write_text_once(value: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    normalized = value.rstrip() + "\n"
    if path.exists():
        if path.read_text(encoding="utf-8") != normalized:
            raise FileExistsError(f"Refusing to overwrite different text: {path}")
        return
    path.write_text(normalized, encoding="utf-8")


def isolate_subject(source: Image.Image) -> Image.Image:
    rgba = np.array(source.convert("RGBA"))
    rgb = rgba[:, :, :3]
    alpha = rgba[:, :, 3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    saturated_seed = ((alpha >= 128) & (hsv[:, :, 1] >= 26)).astype(np.uint8) * 255

    count, labels, stats, _ = cv2.connectedComponentsWithStats(saturated_seed, 8)
    useful_seed = np.zeros_like(saturated_seed)
    for label in range(1, count):
        if stats[label, cv2.CC_STAT_AREA] >= 12:
            useful_seed[labels == label] = 255

    neighborhood = cv2.dilate(
        useful_seed,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (25, 25)),
    )
    candidate = ((neighborhood > 0) & (alpha >= 128)).astype(np.uint8) * 255
    component_count, component_labels, component_stats, _ = cv2.connectedComponentsWithStats(
        candidate, 8
    )
    if component_count <= 1:
        raise RuntimeError("Could not isolate the sprite from the source image")
    largest_label = 1 + int(
        np.argmax(component_stats[1:, cv2.CC_STAT_AREA])
    )
    mask = np.where(component_labels == largest_label, 255, 0).astype(np.uint8)
    ys, xs = np.where(mask > 0)
    crop_box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    rgba[:, :, 3] = mask
    return Image.fromarray(rgba, "RGBA").crop(crop_box)


def prepare_input() -> None:
    if not SOURCE_PATH.exists():
        raise FileNotFoundError(f"Project-local source is missing: {SOURCE_PATH}")
    with Image.open(SOURCE_PATH) as source_image:
        subject = isolate_subject(source_image)

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
    save_image_once(transparent, TRANSPARENT_INPUT_PATH)

    solid = Image.new("RGB", (128, 128), BACKGROUND_RGB)
    solid.paste(transparent.convert("RGB"), mask=transparent.getchannel("A"))
    save_image_once(solid, RIKA_INPUT_PATH)
    save_image_once(
        solid.resize((512, 512), Image.Resampling.NEAREST),
        INPUT_PREVIEW_PATH,
    )
    write_text_once(PROMPT, PROMPT_PATH)
    print(f"PREPARED_INPUT={RIKA_INPUT_PATH}")
    print(f"SUBJECT_SIZE={resized_size}")
    print(f"SUBJECT_PASTE={paste_position}")


def encode_png(path: Path) -> str:
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def write_json_once(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise FileExistsError(f"Refusing to overwrite generation record: {path}")
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def download_outputs(job_info: dict) -> list[str]:
    output_images = job_info.get("output_images", [])
    if not output_images:
        raise RuntimeError("Succeeded job returned no output_images")
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    saved_paths: list[str] = []
    for index, output in enumerate(output_images, start=1):
        url = output.get("url", "")
        if not url:
            raise RuntimeError(f"Output {index} has no URL")
        suffix = Path(urllib.parse.urlparse(url).path).suffix.lower()
        if suffix not in {".png", ".jpg", ".jpeg", ".webp", ".gif"}:
            suffix = ".png"
        path = RAW_DIR / f"output_{index:03d}{suffix}"
        if path.exists():
            raise FileExistsError(f"Refusing to overwrite downloaded output: {path}")
        api_key, _ = get_latest_api_key()
        download_request = urllib.request.Request(
            url,
            headers={
                "X-API-Key": api_key,
                "User-Agent": "Mozilla/5.0",
                "Referer": "https://rika-ai.com/",
            },
            method="GET",
        )
        with urllib.request.urlopen(download_request, timeout=120) as response:
            path.write_bytes(response.read())
        saved_paths.append(path.relative_to(ROOT).as_posix())
        print(f"DOWNLOADED={path}")
    return saved_paths


def poll_and_download(generation_id: str, credits_before: int) -> None:
    job_path = MANIFEST_DIR / "job.json"
    if job_path.exists():
        print(f"JOB_ALREADY_DOWNLOADED={job_path}")
        return
    deadline = time.monotonic() + MAX_POLL_SECONDS
    last_status = None
    while time.monotonic() < deadline:
        job_info = request_json("GET", f"jobs/{generation_id}")
        status = str(job_info.get("status", "unknown"))
        if status != last_status:
            print(f"STATUS={status}", flush=True)
            last_status = status
        if status == "succeeded":
            result_path = MANIFEST_DIR / "job_result.json"
            if not result_path.exists():
                write_json_once(result_path, job_info)
            saved_paths = download_outputs(job_info)
            credits_after = read_credits()
            job_record = dict(job_info)
            job_record["downloaded_files"] = saved_paths
            job_record["credits_after"] = credits_after
            job_record["actual_credit_change"] = credits_before - credits_after
            write_json_once(job_path, job_record)
            print(f"CREDITS_AFTER={credits_after}")
            print(f"ACTUAL_CREDIT_CHANGE={credits_before - credits_after}")
            return
        if status == "failed":
            credits_after = read_credits()
            job_record = dict(job_info)
            job_record["credits_after"] = credits_after
            job_record["actual_credit_change"] = credits_before - credits_after
            write_json_once(job_path, job_record)
            raise RuntimeError(f"Rika generation failed: {job_info.get('error')}")
        time.sleep(POLL_SECONDS)
    raise TimeoutError(
        f"Rika job {generation_id} did not finish within {MAX_POLL_SECONDS} seconds"
    )


def submit_once() -> None:
    submission_path = MANIFEST_DIR / "submission.json"
    job_path = MANIFEST_DIR / "job.json"
    if submission_path.exists() or job_path.exists():
        raise FileExistsError("A Rika submission record already exists; refusing another paid call")

    _, key_source = get_latest_api_key()
    credits_before = read_credits()
    if credits_before < EXPECTED_COST:
        raise RuntimeError(
            f"Insufficient credits: {credits_before}; {EXPECTED_COST} required"
        )
    payload = {
        "image_base64": [encode_png(RIKA_INPUT_PATH), encode_png(RIKA_INPUT_PATH)],
        "params": PARAMS,
    }
    print(f"KEY_SOURCE={key_source}")
    print("AUTHENTICATION=SUCCESS")
    print(f"CREDITS_BEFORE={credits_before}")
    print("SUBMITTING_ONE_AUTHORIZED_GENERATION=YES")
    created = request_json("POST", "generate", payload, timeout=180)
    generation_id = created.get("gen_id")
    if not generation_id:
        raise RuntimeError(f"Rika response did not include gen_id: {created}")
    write_json_once(
        submission_path,
        {
            "service": "Rika AI",
            "endpoint": f"{BASE_URL}/generate",
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
    poll_and_download(generation_id, credits_before)


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
    poll_and_download(generation_id, int(submission["credits_before"]))


def main() -> None:
    args = parse_args()
    prepare_input()
    if args.confirm_spend_5_credits and args.resume_existing_job:
        raise ValueError("Choose submission or resume, not both")
    if args.resume_existing_job:
        resume_existing_job()
        return
    if not args.confirm_spend_5_credits:
        print("PREPARE_ONLY=YES")
        return
    submit_once()


if __name__ == "__main__":
    main()
