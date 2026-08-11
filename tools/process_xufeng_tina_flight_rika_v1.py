from __future__ import annotations

import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
VERSION_ROOT = ROOT / "output/sprite_animation_candidates/xufeng_tina/flight_v1"
MANIFEST_ROOT = ROOT / "output/sprite_animation_candidates/_manifests/xufeng_tina/flight_v1"
RAW_SHEET_PATH = VERSION_ROOT / "raw/output_001.png"
START_SOURCE_PATH = VERSION_ROOT / "source/xufeng_tina_transparent_128_v1.png"
PROMPT_PATH = VERSION_ROOT / "source/prompt-used.txt"
PROCESSOR_INPUT_PATH = VERSION_ROOT / "source/xufeng_tina_flight_magenta_v1.png"
PROCESSOR_OUTPUT_DIR = VERSION_ROOT / "processor_qc"
FRAME_DIR = VERSION_ROOT / "frames"
ZOOM_FRAME_DIR = VERSION_ROOT / "frames_4x"
SHEET_PATH = VERSION_ROOT / "xufeng_tina_flight_sheet_v1.png"
OVERVIEW_PATH = VERSION_ROOT / "xufeng_tina_flight_overview_v1.png"
ZOOM_OVERVIEW_PATH = VERSION_ROOT / "xufeng_tina_flight_overview_4x_v1.png"
GIF_PATH = VERSION_ROOT / "xufeng_tina_flight_preview_v1.gif"
SLOW_GIF_PATH = VERSION_ROOT / "xufeng_tina_flight_slow_check_v1.gif"
QA_REPORT_PATH = MANIFEST_ROOT / "qa_report.json"

SKILL_PROCESSOR = (
    Path.home() / ".codex/skills/generate2dsprite/scripts/generate2dsprite.py"
)
FRAME_SIZE = (128, 128)
GRID_SIZE = (4, 4)
FRAME_COUNT = 16
BACKGROUND_KEY = (0, 63, 64)
CHROMA_DISTANCE = 45
UNIFORM_CANVAS_SCALE = 0.92
PREVIEW_BACKGROUND = (28, 30, 36)
FRAME_DURATION_MS = 120
SLOW_FRAME_DURATION_MS = 420


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def color_distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> float:
    return math.sqrt(sum((left[index] - right[index]) ** 2 for index in range(3)))


def chroma_to_rgba(rgb: Image.Image) -> Image.Image:
    rgb = rgb.convert("RGB")
    rgba = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    source_pixels = rgb.load()
    target_pixels = rgba.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            color = source_pixels[x, y]
            alpha = 0 if color_distance(color, BACKGROUND_KEY) <= CHROMA_DISTANCE else 255
            target_pixels[x, y] = (*color, alpha)
    return rgba


def remove_teal_edge_halo(frame: Image.Image, passes: int = 3) -> tuple[Image.Image, int]:
    output = frame.copy()
    removed_total = 0
    for _ in range(passes):
        pixels = output.load()
        to_remove: list[tuple[int, int]] = []
        for y in range(output.height):
            for x in range(output.width):
                red, green, blue, alpha = pixels[x, y]
                if not alpha:
                    continue
                touches_transparency = any(
                    0 <= x + dx < output.width
                    and 0 <= y + dy < output.height
                    and pixels[x + dx, y + dy][3] == 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                )
                teal_halo = (
                    (
                        red <= 70
                        and green >= 60
                        and blue >= 60
                        and abs(green - blue) <= 15
                    )
                    or (
                        red <= 90
                        and green >= 40
                        and blue >= 40
                        and ((green + blue) / 2 - red) >= 12
                    )
                )
                if touches_transparency and teal_halo:
                    to_remove.append((x, y))
        if not to_remove:
            break
        for x, y in to_remove:
            red, green, blue, _ = pixels[x, y]
            pixels[x, y] = (red, green, blue, 0)
        removed_total += len(to_remove)
    return output, removed_total


def extract_raw_frames(raw: Image.Image) -> list[Image.Image]:
    expected = (FRAME_SIZE[0] * GRID_SIZE[0], FRAME_SIZE[1] * GRID_SIZE[1])
    if raw.size != expected:
        raise ValueError(f"Unexpected Rika sheet size: {raw.size}; expected {expected}")
    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        x = (index % GRID_SIZE[0]) * FRAME_SIZE[0]
        y = (index // GRID_SIZE[0]) * FRAME_SIZE[1]
        frame, _ = remove_teal_edge_halo(
            chroma_to_rgba(raw.crop((x, y, x + 128, y + 128)))
        )
        frames.append(frame)
    return frames


def uniform_canvas_scale(frame: Image.Image) -> Image.Image:
    scaled_size = (
        round(FRAME_SIZE[0] * UNIFORM_CANVAS_SCALE),
        round(FRAME_SIZE[1] * UNIFORM_CANVAS_SCALE),
    )
    scaled = frame.resize(scaled_size, Image.Resampling.NEAREST)
    output = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    output.alpha_composite(
        scaled,
        ((FRAME_SIZE[0] - scaled.width) // 2, (FRAME_SIZE[1] - scaled.height) // 2),
    )
    alpha = output.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    output.putalpha(alpha)
    return output


def compose_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * GRID_SIZE[0], FRAME_SIZE[1] * GRID_SIZE[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        sheet.alpha_composite(
            frame,
            ((index % GRID_SIZE[0]) * 128, (index // GRID_SIZE[0]) * 128),
        )
    return sheet


def compose_preview(frame: Image.Image) -> Image.Image:
    preview = Image.new("RGB", FRAME_SIZE, PREVIEW_BACKGROUND)
    preview.paste(frame.convert("RGB"), mask=frame.getchannel("A"))
    return preview


def quantize_with_shared_palette(frames: list[Image.Image]) -> list[Image.Image]:
    atlas = Image.new("RGB", (FRAME_SIZE[0] * len(frames), FRAME_SIZE[1]))
    for index, frame in enumerate(frames):
        atlas.paste(compose_preview(frame), (index * FRAME_SIZE[0], 0))
    palette = atlas.quantize(
        colors=255,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    output: list[Image.Image] = []
    for frame in frames:
        quantized = compose_preview(frame).quantize(
            palette=palette,
            dither=Image.Dither.NONE,
        ).convert("RGBA")
        quantized.putalpha(frame.getchannel("A"))
        output.append(quantized)
    return output


def exact_palette_frames(previews: list[Image.Image]) -> tuple[list[Image.Image], int]:
    colors = sorted({color for frame in previews for color in frame.get_flattened_data()})
    if len(colors) > 256:
        raise ValueError(f"GIF source has {len(colors)} colors; exact GIF needs at most 256")
    color_to_index = {color: index for index, color in enumerate(colors)}
    palette = [channel for color in colors for channel in color]
    palette.extend([0] * (768 - len(palette)))
    indexed_frames: list[Image.Image] = []
    for preview in previews:
        indexed = Image.new("P", preview.size)
        indexed.putpalette(palette)
        indexed.putdata([color_to_index[color] for color in preview.get_flattened_data()])
        indexed_frames.append(indexed)
    return indexed_frames, len(colors)


def write_verified_gif(previews: list[Image.Image], path: Path, duration_ms: int) -> dict:
    indexed, palette_color_count = exact_palette_frames(previews)
    path.parent.mkdir(parents=True, exist_ok=True)
    indexed[0].save(
        path,
        save_all=True,
        append_images=indexed[1:],
        duration=[duration_ms] * len(indexed),
        loop=0,
        disposal=2,
        optimize=False,
    )
    decoded = Image.open(path)
    decoded_frames = [frame.convert("RGB") for frame in ImageSequence.Iterator(decoded)]
    durations: list[int] = []
    disposal_methods: list[int | None] = []
    for index in range(getattr(decoded, "n_frames", 1)):
        decoded.seek(index)
        durations.append(int(decoded.info.get("duration", 0)))
        disposal_methods.append(getattr(decoded, "disposal_method", None))
    exact_matches = [
        ImageChops.difference(decoded_frame, source).getbbox() is None
        for decoded_frame, source in zip(decoded_frames, previews, strict=True)
    ]
    passed = (
        len(decoded_frames) == len(previews)
        and all(exact_matches)
        and durations == [duration_ms] * len(previews)
        and all(method == 2 for method in disposal_methods)
    )
    if not passed:
        raise ValueError(f"GIF verification failed: {path}")
    return {
        "path": relative(path),
        "frame_count": len(decoded_frames),
        "durations_ms": durations,
        "disposal_methods": disposal_methods,
        "palette_color_count": palette_color_count,
        "source_preview_pixel_exact": exact_matches,
        "passed": passed,
    }


def make_processor_input(sheet: Image.Image) -> None:
    solid = Image.new("RGB", sheet.size, (255, 0, 255))
    solid.paste(sheet.convert("RGB"), mask=sheet.getchannel("A"))
    solid.save(PROCESSOR_INPUT_PATH, optimize=False)


def run_skill_processor() -> None:
    command = [
        sys.executable,
        str(SKILL_PROCESSOR),
        "process",
        "--input",
        str(PROCESSOR_INPUT_PATH),
        "--target",
        "npc",
        "--mode",
        "hover",
        "--output-dir",
        str(PROCESSOR_OUTPUT_DIR),
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
        "0.92",
        "--trim-border",
        "0",
        "--edge-clean-depth",
        "0",
        "--align",
        "center",
        "--shared-scale",
        "--scale-strategy",
        "preserve",
        "--component-mode",
        "all",
        "--component-padding",
        "1",
        "--strict-qc",
        "--duration",
        str(FRAME_DURATION_MS),
    ]
    subprocess.run(command, cwd=ROOT, check=True)


def different_pixel_count(left: Image.Image, right: Image.Image) -> int:
    return sum(
        left_pixel != right_pixel
        for left_pixel, right_pixel in zip(
            left.get_flattened_data(), right.get_flattened_data(), strict=True
        )
    )


def residual_teal_pixels(frame: Image.Image) -> int:
    return sum(
        1
        for red, green, blue, alpha in frame.get_flattened_data()
        if alpha and color_distance((red, green, blue), BACKGROUND_KEY) <= CHROMA_DISTANCE
    )


def edge_touch_frames(frames: list[Image.Image]) -> list[int]:
    result: list[int] = []
    for index, frame in enumerate(frames, start=1):
        box = frame.getchannel("A").getbbox()
        if box is None:
            continue
        if box[0] == 0 or box[1] == 0 or box[2] == 128 or box[3] == 128:
            result.append(index)
    return result


def main() -> None:
    raw = Image.open(RAW_SHEET_PATH).convert("RGB")
    uncleaned_raw_frames: list[Image.Image] = []
    halo_removed_counts: list[int] = []
    raw_frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        x = (index % GRID_SIZE[0]) * FRAME_SIZE[0]
        y = (index // GRID_SIZE[0]) * FRAME_SIZE[1]
        uncleaned = chroma_to_rgba(raw.crop((x, y, x + 128, y + 128)))
        cleaned, removed_count = remove_teal_edge_halo(uncleaned)
        uncleaned_raw_frames.append(uncleaned)
        raw_frames.append(cleaned)
        halo_removed_counts.append(removed_count)
    raw_edge_frames = edge_touch_frames(uncleaned_raw_frames)
    frames = [uniform_canvas_scale(frame) for frame in raw_frames]

    with Image.open(START_SOURCE_PATH) as start_image:
        start_frame = uniform_canvas_scale(start_image.convert("RGBA"))
    frames[0] = start_frame
    frames[-1] = start_frame.copy()
    frames = quantize_with_shared_palette(frames)

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    ZOOM_FRAME_DIR.mkdir(parents=True, exist_ok=True)
    frame_paths: list[Path] = []
    zoom_frame_paths: list[Path] = []
    for index, frame in enumerate(frames, start=1):
        frame_path = FRAME_DIR / f"frame_{index:03d}.png"
        zoom_path = ZOOM_FRAME_DIR / f"frame_{index:03d}_4x.png"
        frame.save(frame_path, optimize=False)
        frame.resize((512, 512), Image.Resampling.NEAREST).save(zoom_path, optimize=False)
        frame_paths.append(frame_path)
        zoom_frame_paths.append(zoom_path)

    sheet = compose_sheet(frames)
    sheet.save(SHEET_PATH, optimize=False)
    sheet.save(OVERVIEW_PATH, optimize=False)
    preview_sheet = Image.new("RGBA", sheet.size, (*PREVIEW_BACKGROUND, 255))
    preview_sheet.alpha_composite(sheet)
    preview_sheet.resize((2048, 2048), Image.Resampling.NEAREST).save(
        ZOOM_OVERVIEW_PATH, optimize=False
    )
    make_processor_input(sheet)
    run_skill_processor()

    previews = [compose_preview(frame) for frame in frames]
    gif_report = write_verified_gif(previews, GIF_PATH, FRAME_DURATION_MS)
    slow_gif_report = write_verified_gif(previews, SLOW_GIF_PATH, SLOW_FRAME_DURATION_MS)

    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("At least one delivery frame is empty")
    valid_boxes = [box for box in boxes if box is not None]
    delivery_edge_frames = edge_touch_frames(frames)
    alpha_binary = [
        set(frame.getchannel("A").get_flattened_data()) <= {0, 255}
        for frame in frames
    ]
    teal_spill = [residual_teal_pixels(frame) for frame in frames]
    centers_x = [(box[0] + box[2]) / 2 for box in valid_boxes]
    centers_y = [(box[1] + box[3]) / 2 for box in valid_boxes]
    sequential_differences = [
        different_pixel_count(previews[index], previews[(index + 1) % FRAME_COUNT])
        for index in range(FRAME_COUNT)
    ]
    first_last_identical = frames[0].tobytes() == frames[-1].tobytes()
    skill_meta_path = PROCESSOR_OUTPUT_DIR / "pipeline-meta.json"
    skill_meta = json.loads(skill_meta_path.read_text(encoding="utf-8"))
    submission = json.loads((MANIFEST_ROOT / "submission.json").read_text(encoding="utf-8"))
    job = json.loads((MANIFEST_ROOT / "job.json").read_text(encoding="utf-8"))
    technical_pass = (
        not delivery_edge_frames
        and all(alpha_binary)
        and all(value == 0 for value in teal_spill)
        and first_last_identical
        and bool(gif_report["passed"])
        and bool(slow_gif_report["passed"])
        and not skill_meta.get("empty_frames")
        and not skill_meta.get("output_edge_touch_frames")
        and not skill_meta.get("paste_clamped_frames")
    )
    report = {
        "version": 1,
        "service": "Rika AI",
        "generation_id": submission["gen_id"],
        "generation_call_count": 1,
        "expected_credit_change": submission["expected_cost_credits"],
        "actual_credit_change": job["actual_credit_change"],
        "credits_before": submission["credits_before"],
        "credits_after": job["credits_after"],
        "source_sheet": relative(RAW_SHEET_PATH),
        "source_sheet_sha256": hashlib.sha256(RAW_SHEET_PATH.read_bytes()).hexdigest(),
        "frame_count": FRAME_COUNT,
        "frame_size": list(FRAME_SIZE),
        "uniform_canvas_scale": UNIFORM_CANVAS_SCALE,
        "teal_edge_halo_removed_pixels_per_frame": halo_removed_counts,
        "raw_edge_touch_frames": raw_edge_frames,
        "delivery_edge_touch_frames": delivery_edge_frames,
        "frame_paths": [relative(path) for path in frame_paths],
        "zoom_frame_paths": [relative(path) for path in zoom_frame_paths],
        "alpha_bounding_boxes": [list(box) for box in valid_boxes],
        "alpha_binary": alpha_binary,
        "residual_teal_pixels": teal_spill,
        "center_x_range": [min(centers_x), max(centers_x)],
        "center_y_range": [min(centers_y), max(centers_y)],
        "bottom_anchor_range": [min(box[3] for box in valid_boxes), max(box[3] for box in valid_boxes)],
        "first_last_identical": first_last_identical,
        "sequential_difference_pixels_including_loop": sequential_differences,
        "gif": gif_report,
        "slow_gif": slow_gif_report,
        "sheet": relative(SHEET_PATH),
        "overview": relative(OVERVIEW_PATH),
        "zoom_overview": relative(ZOOM_OVERVIEW_PATH),
        "skill_processor_qc": {
            "pipeline_meta": relative(skill_meta_path),
            "empty_frames": skill_meta.get("empty_frames"),
            "source_edge_touch_frames": skill_meta.get("source_edge_touch_frames"),
            "output_edge_touch_frames": skill_meta.get("output_edge_touch_frames"),
            "paste_clamped_frames": skill_meta.get("paste_clamped_frames"),
            "qc_summary": skill_meta.get("qc_summary"),
        },
        "technical_qa_status": "PASS" if technical_pass else "BLOCKED",
        "visual_qa_status": "PENDING_MANUAL_REVIEW",
    }
    MANIFEST_ROOT.mkdir(parents=True, exist_ok=True)
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    if not technical_pass:
        raise ValueError(f"Technical QA failed; see {QA_REPORT_PATH}")
    print(f"FRAME_COUNT={FRAME_COUNT}")
    print(f"RAW_EDGE_TOUCH_FRAMES={raw_edge_frames}")
    print(f"DELIVERY_EDGE_TOUCH_FRAMES={delivery_edge_frames}")
    print(f"CENTER_X_RANGE={min(centers_x)}..{max(centers_x)}")
    print(f"CENTER_Y_RANGE={min(centers_y)}..{max(centers_y)}")
    print(f"BOTTOM_ANCHOR_RANGE={min(box[3] for box in valid_boxes)}..{max(box[3] for box in valid_boxes)}")
    print(f"FIRST_LAST_IDENTICAL={first_last_identical}")
    print(f"GIF_EXACT_PIXEL_MATCH={gif_report['passed']}")
    print(f"SLOW_GIF_EXACT_PIXEL_MATCH={slow_gif_report['passed']}")
    print(f"TECHNICAL_QA={'PASS' if technical_pass else 'BLOCKED'}")
    print(f"OVERVIEW={OVERVIEW_PATH}")
    print(f"GIF={GIF_PATH}")


if __name__ == "__main__":
    main()
