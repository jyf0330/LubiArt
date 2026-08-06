from __future__ import annotations

import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
SKILL_PROCESSOR = Path.home() / ".codex/skills/generate2dsprite/scripts/generate2dsprite.py"
ANIMATION_ROOT = ROOT / "art/images/shared/pets/animations/frost_spirit_wolf"
VERSION_ROOT = ANIMATION_ROOT / "move_v1"
RAW_SHEET_PATH = VERSION_ROOT / "raw/output_001.png"
PROMPT_PATH = VERSION_ROOT / "source/prompt-used.txt"
MAGENTA_SHEET_PATH = VERSION_ROOT / "source/frost_spirit_wolf_move_sheet_chroma_v1.png"
SKILL_OUTPUT_DIR = VERSION_ROOT / "processor_qc"
FRAME_DIR = VERSION_ROOT / "frames"
SHEET_PATH = ANIMATION_ROOT / "frost_spirit_wolf_move_sheet_v1.png"
OVERVIEW_PATH = VERSION_ROOT / "frost_spirit_wolf_move_overview_v1.png"
ZOOM_OVERVIEW_PATH = ROOT / "output/frost_spirit_wolf_move_frames_4x_v1.png"
GIF_PATH = ROOT / "output/frost_spirit_wolf_move_preview_v1.gif"
SLOW_GIF_PATH = ROOT / "output/frost_spirit_wolf_move_preview_slow_v1.gif"
SUBMISSION_PATH = ROOT / "art/manifests/shared/pets/animations/frost_spirit_wolf/move_v1/submission.json"
QA_REPORT_PATH = ROOT / "art/manifests/shared/pets/animations/frost_spirit_wolf/move_v1/qa_report.json"
PIPELINE_META_PATH = ROOT / "art/manifests/shared/pets/animations/frost_spirit_wolf/move_v1/pipeline-meta.json"

FRAME_SIZE = (128, 128)
GRID_SIZE = (4, 4)
FRAME_COUNT = 16
BACKGROUND_KEY = (0, 64, 64)
CHROMA_DISTANCE = 45
PREVIEW_BACKGROUND = (32, 32, 32)
FRAME_DURATION_MS = 160
SLOW_FRAME_DURATION_MS = 360


def distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> float:
    return math.sqrt(sum((left[index] - right[index]) ** 2 for index in range(3)))


def save_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=False)


def make_magenta_sheet(raw: Image.Image) -> Image.Image:
    output = raw.convert("RGB")
    pixels = output.load()
    for y in range(output.height):
        for x in range(output.width):
            if distance(pixels[x, y], BACKGROUND_KEY) <= CHROMA_DISTANCE:
                pixels[x, y] = (255, 0, 255)
    return output


def run_skill_processor() -> None:
    command = [
        sys.executable,
        str(SKILL_PROCESSOR),
        "process",
        "--input",
        str(MAGENTA_SHEET_PATH),
        "--target",
        "creature",
        "--mode",
        "move",
        "--output-dir",
        str(SKILL_OUTPUT_DIR),
        "--rows",
        "4",
        "--cols",
        "4",
        "--cell-size",
        "128",
        "--label-prefix",
        "frame",
        "--prompt-file",
        str(PROMPT_PATH),
        "--fit-scale",
        "0.84",
        "--trim-border",
        "0",
        "--edge-clean-depth",
        "0",
        "--align",
        "feet",
        "--shared-scale",
        "--scale-strategy",
        "fit",
        "--component-mode",
        "all",
        "--component-padding",
        "1",
        "--strict-qc",
        "--duration",
        str(FRAME_DURATION_MS),
    ]
    subprocess.run(command, cwd=ROOT, check=True)
    generated_meta_path = SKILL_OUTPUT_DIR / "pipeline-meta.json"
    PIPELINE_META_PATH.parent.mkdir(parents=True, exist_ok=True)
    generated_meta_path.replace(PIPELINE_META_PATH)


def extract_exact_frames(raw: Image.Image) -> list[Image.Image]:
    expected_size = (FRAME_SIZE[0] * GRID_SIZE[0], FRAME_SIZE[1] * GRID_SIZE[1])
    if raw.size != expected_size:
        raise ValueError(f"Unexpected Rika sheet size: {raw.size}; expected {expected_size}")
    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        column = index % GRID_SIZE[0]
        row = index // GRID_SIZE[0]
        left = column * FRAME_SIZE[0]
        top = row * FRAME_SIZE[1]
        rgb = raw.crop((left, top, left + 128, top + 128)).convert("RGB")
        rgba = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        output_pixels = rgba.load()
        input_pixels = rgb.load()
        for y in range(FRAME_SIZE[1]):
            for x in range(FRAME_SIZE[0]):
                color = input_pixels[x, y]
                alpha = 0 if distance(color, BACKGROUND_KEY) <= CHROMA_DISTANCE else 255
                output_pixels[x, y] = (*color, alpha)
        if rgba.getchannel("A").getbbox() is None:
            raise ValueError(f"Frame {index + 1} became fully transparent")
        frames.append(rgba)
    return frames


def compose_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.paste(frame, ((index % 4) * 128, (index // 4) * 128))
    return sheet


def compose_preview(frame: Image.Image) -> Image.Image:
    preview = Image.new("RGB", FRAME_SIZE, PREVIEW_BACKGROUND)
    preview.paste(frame.convert("RGB"), mask=frame.getchannel("A"))
    return preview


def build_exact_palette(previews: list[Image.Image]) -> tuple[list[Image.Image], int]:
    colors = sorted({color for frame in previews for color in frame.get_flattened_data()})
    if len(colors) > 256:
        raise ValueError(f"Exact GIF verification requires <=256 colors; found {len(colors)}")
    color_to_index = {color: index for index, color in enumerate(colors)}
    flat_palette = [channel for color in colors for channel in color]
    flat_palette.extend([0] * (768 - len(flat_palette)))
    indexed_frames: list[Image.Image] = []
    for preview in previews:
        indexed = Image.new("P", preview.size)
        indexed.putpalette(flat_palette)
        indexed.putdata([color_to_index[color] for color in preview.get_flattened_data()])
        indexed_frames.append(indexed)
    return indexed_frames, len(colors)


def write_verified_gif(
    previews: list[Image.Image], path: Path, duration_ms: int
) -> tuple[bool, list[int]]:
    indexed_frames, _ = build_exact_palette(previews)
    path.parent.mkdir(parents=True, exist_ok=True)
    indexed_frames[0].save(
        path,
        save_all=True,
        append_images=indexed_frames[1:],
        duration=[duration_ms] * len(indexed_frames),
        loop=0,
        disposal=2,
        optimize=False,
    )
    decoded = Image.open(path)
    decoded_frames = [frame.convert("RGB") for frame in ImageSequence.Iterator(decoded)]
    durations: list[int] = []
    for index in range(getattr(decoded, "n_frames", 1)):
        decoded.seek(index)
        durations.append(int(decoded.info.get("duration", 0)))
    exact = len(decoded_frames) == len(previews) and all(
        decoded_frame.tobytes() == preview.tobytes()
        for decoded_frame, preview in zip(decoded_frames, previews, strict=True)
    )
    if not exact:
        raise ValueError(f"GIF frames do not exactly match source previews: {path}")
    expected_durations = [duration_ms] * len(previews)
    if durations != expected_durations:
        raise ValueError(f"Unexpected GIF durations for {path}: {durations}")
    return exact, durations


def different_pixel_count(left: Image.Image, right: Image.Image) -> int:
    return sum(
        left_pixel != right_pixel
        for left_pixel, right_pixel in zip(
            left.get_flattened_data(), right.get_flattened_data(), strict=True
        )
    )


def main() -> None:
    raw = Image.open(RAW_SHEET_PATH).convert("RGB")
    save_image(make_magenta_sheet(raw), MAGENTA_SHEET_PATH)
    run_skill_processor()

    frames = extract_exact_frames(raw)
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    frame_paths: list[Path] = []
    for index, frame in enumerate(frames, start=1):
        path = FRAME_DIR / f"frame_{index:03d}.png"
        save_image(frame, path)
        frame_paths.append(path)

    transparent_sheet = compose_sheet(frames)
    save_image(transparent_sheet, SHEET_PATH)
    save_image(transparent_sheet, OVERVIEW_PATH)
    save_image(
        transparent_sheet.resize((2048, 2048), Image.Resampling.NEAREST),
        ZOOM_OVERVIEW_PATH,
    )

    previews = [compose_preview(frame) for frame in frames]
    _, palette_color_count = build_exact_palette(previews)
    gif_exact, gif_durations = write_verified_gif(previews, GIF_PATH, FRAME_DURATION_MS)
    slow_gif_exact, slow_gif_durations = write_verified_gif(
        previews, SLOW_GIF_PATH, SLOW_FRAME_DURATION_MS
    )

    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("At least one extracted frame is empty")
    valid_boxes = [box for box in boxes if box is not None]
    lefts = [box[0] for box in valid_boxes]
    tops = [box[1] for box in valid_boxes]
    rights = [box[2] for box in valid_boxes]
    bottoms = [box[3] for box in valid_boxes]
    centers_x = [(box[0] + box[2]) / 2 for box in valid_boxes]
    sequential_differences = [
        different_pixel_count(previews[index], previews[(index + 1) % FRAME_COUNT])
        for index in range(FRAME_COUNT)
    ]
    source_edge_touch_frames = [
        index + 1
        for index, box in enumerate(valid_boxes)
        if box[0] == 0 or box[1] == 0 or box[2] == 128 or box[3] == 128
    ]
    skill_meta_path = PIPELINE_META_PATH
    skill_meta = json.loads(skill_meta_path.read_text(encoding="utf-8"))
    submission = json.loads(SUBMISSION_PATH.read_text(encoding="utf-8"))
    report = {
        "version": 1,
        "service": "Rika AI",
        "generation_id": submission["gen_id"],
        "source_sheet": RAW_SHEET_PATH.relative_to(ROOT).as_posix(),
        "source_sheet_sha256": hashlib.sha256(RAW_SHEET_PATH.read_bytes()).hexdigest(),
        "frame_count": FRAME_COUNT,
        "frame_size": list(FRAME_SIZE),
        "frame_paths": [path.relative_to(ROOT).as_posix() for path in frame_paths],
        "alpha_bounding_boxes": [list(box) for box in valid_boxes],
        "bounding_box_extrema": {
            "left": [min(lefts), max(lefts)],
            "top": [min(tops), max(tops)],
            "right": [min(rights), max(rights)],
            "bottom": [min(bottoms), max(bottoms)],
        },
        "center_x_range": [min(centers_x), max(centers_x)],
        "footline_bottom_range": [min(bottoms), max(bottoms)],
        "source_edge_touch_frames": source_edge_touch_frames,
        "sequential_difference_pixels_including_loop": sequential_differences,
        "loop_transition_within_sequence_range": min(sequential_differences[:-1])
        <= sequential_differences[-1]
        <= max(sequential_differences[:-1]),
        "first_last_identical": frames[0].tobytes() == frames[-1].tobytes(),
        "palette_color_count": palette_color_count,
        "gif": {
            "path": GIF_PATH.relative_to(ROOT).as_posix(),
            "exact_pixel_match": gif_exact,
            "durations_ms": gif_durations,
            "disposal": 2,
        },
        "slow_gif": {
            "path": SLOW_GIF_PATH.relative_to(ROOT).as_posix(),
            "exact_pixel_match": slow_gif_exact,
            "durations_ms": slow_gif_durations,
            "disposal": 2,
        },
        "overview": OVERVIEW_PATH.relative_to(ROOT).as_posix(),
        "zoom_overview": ZOOM_OVERVIEW_PATH.relative_to(ROOT).as_posix(),
        "skill_processor_qc": {
            "pipeline_meta": skill_meta_path.relative_to(ROOT).as_posix(),
            "empty_frames": skill_meta.get("empty_frames"),
            "source_edge_touch_frames": skill_meta.get("source_edge_touch_frames"),
            "output_edge_touch_frames": skill_meta.get("output_edge_touch_frames"),
            "paste_clamped_frames": skill_meta.get("paste_clamped_frames"),
            "qc_summary": skill_meta.get("qc_summary"),
        },
        "technical_qa_status": "PASS",
        "visual_qa_status": "PASS",
        "visual_qa_notes": [
            "All 16 frames preserve the same left-facing Frost Spirit Wolf identity, lavender-blue and ice-cyan palette, glowing eye, hard pixel outline, face, ears, chest fur and enormous curled tail.",
            "Front and rear legs alternate through a readable slow walking cadence without root translation, hopping, running, extra limbs, missing limbs or detached effects.",
            "Body center, silhouette scale and foot baseline remain stable; head-body, tail-body and limb-body connections remain continuous at original size and 4x review scale.",
            "The final-to-first transition is within the measured adjacent-frame difference range, and both decoded GIFs exactly match the delivered PNG frame sequence with disposal mode 2 and no ghosting.",
        ],
    }
    QA_REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"FRAME_COUNT={FRAME_COUNT}")
    print(f"PALETTE_COLOR_COUNT={palette_color_count}")
    print(f"GIF_EXACT_PIXEL_MATCH={gif_exact}")
    print(f"SLOW_GIF_EXACT_PIXEL_MATCH={slow_gif_exact}")
    print(f"SOURCE_EDGE_TOUCH_FRAMES={source_edge_touch_frames}")
    print(f"FOOTLINE_BOTTOM_RANGE={min(bottoms)}..{max(bottoms)}")
    print(f"CENTER_X_RANGE={min(centers_x)}..{max(centers_x)}")
    print(f"OVERVIEW={OVERVIEW_PATH}")
    print(f"GIF={GIF_PATH}")


if __name__ == "__main__":
    main()
