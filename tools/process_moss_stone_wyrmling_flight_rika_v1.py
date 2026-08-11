from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
VERSION_ROOT = ROOT / "output/sprite_animation_candidates/moss_stone_wyrmling/flight_v1"
MANIFEST_ROOT = ROOT / "output/sprite_animation_candidates/_manifests/moss_stone_wyrmling/flight_v1"
RAW_SHEET = VERSION_ROOT / "raw/output_001.png"
START_SOURCE = VERSION_ROOT / "source/frame_001_first_160.png"
MID_SOURCE = VERSION_ROOT / "source/frame_002_airborne_mid_face_scale_matched_160.png"
FRAME_DIR = VERSION_ROOT / "frames"
SHEET_PATH = VERSION_ROOT / "moss_stone_wyrmling_flight_sheet_v1.png"
OVERVIEW_PATH = VERSION_ROOT / "moss_stone_wyrmling_flight_overview_v1.png"
ZOOM_OVERVIEW_PATH = VERSION_ROOT / "moss_stone_wyrmling_flight_overview_4x_v1.png"
GIF_PATH = VERSION_ROOT / "moss_stone_wyrmling_flight_preview_v1.gif"
SLOW_GIF_PATH = VERSION_ROOT / "moss_stone_wyrmling_flight_slow_check_v1.gif"
QA_REPORT_PATH = MANIFEST_ROOT / "qa_report.json"

FRAME_SIZE = (128, 128)
RAW_GRID = (4, 4)
BACKGROUND_KEY = (0, 63, 64)
CHROMA_DISTANCE = 45
PREVIEW_BACKGROUND = (28, 30, 36)
FRAME_DURATION_MS = 120
SLOW_FRAME_DURATION_MS = 420
MID_DELIVERY_FRAME = 9


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def color_distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> float:
    return math.sqrt(sum((left[index] - right[index]) ** 2 for index in range(3)))


def harden_alpha(frame: Image.Image) -> Image.Image:
    rgba = frame.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgba.putalpha(alpha)
    return rgba


def extract_raw_frames(raw: Image.Image) -> list[Image.Image]:
    expected = (FRAME_SIZE[0] * RAW_GRID[0], FRAME_SIZE[1] * RAW_GRID[1])
    if raw.size != expected:
        raise ValueError(f"Unexpected Rika sheet size: {raw.size}; expected {expected}")
    frames: list[Image.Image] = []
    for index in range(RAW_GRID[0] * RAW_GRID[1]):
        x = (index % RAW_GRID[0]) * FRAME_SIZE[0]
        y = (index // RAW_GRID[0]) * FRAME_SIZE[1]
        rgb = raw.crop((x, y, x + FRAME_SIZE[0], y + FRAME_SIZE[1])).convert("RGB")
        rgba = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        source_pixels = rgb.load()
        target_pixels = rgba.load()
        for py in range(FRAME_SIZE[1]):
            for px in range(FRAME_SIZE[0]):
                color = source_pixels[px, py]
                alpha = 0 if color_distance(color, BACKGROUND_KEY) <= CHROMA_DISTANCE else 255
                target_pixels[px, py] = (*color, alpha)
        frames.append(rgba)
    return frames


def prepared_keyframe(path: Path) -> Image.Image:
    with Image.open(path) as source:
        rgba = source.convert("RGBA")
    if rgba.size != (160, 160):
        raise ValueError(f"Expected a 160x160 user keyframe: {path}, got {rgba.size}")
    return harden_alpha(rgba.resize(FRAME_SIZE, Image.Resampling.NEAREST))


def compose_preview(frame: Image.Image) -> Image.Image:
    preview = Image.new("RGB", FRAME_SIZE, PREVIEW_BACKGROUND)
    preview.paste(frame.convert("RGB"), mask=frame.getchannel("A"))
    return preview


def quantize_with_shared_palette(frames: list[Image.Image]) -> list[Image.Image]:
    atlas = Image.new("RGB", (FRAME_SIZE[0] * len(frames), FRAME_SIZE[1]))
    for index, frame in enumerate(frames):
        atlas.paste(compose_preview(frame), (index * FRAME_SIZE[0], 0))
    palette = atlas.quantize(
        colors=256,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    output: list[Image.Image] = []
    for frame in frames:
        preview = compose_preview(frame).quantize(
            palette=palette,
            dither=Image.Dither.NONE,
        ).convert("RGBA")
        preview.putalpha(frame.getchannel("A"))
        output.append(harden_alpha(preview))
    return output


def compose_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * RAW_GRID[0], FRAME_SIZE[1] * RAW_GRID[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        sheet.alpha_composite(
            frame,
            (
                (index % RAW_GRID[0]) * FRAME_SIZE[0],
                (index // RAW_GRID[0]) * FRAME_SIZE[1],
            ),
        )
    return sheet


def exact_palette_frames(previews: list[Image.Image]) -> list[Image.Image]:
    colors = sorted({color for frame in previews for color in frame.get_flattened_data()})
    if len(colors) > 256:
        raise ValueError(f"GIF source has {len(colors)} colors after shared quantization")
    color_to_index = {color: index for index, color in enumerate(colors)}
    flat_palette = [channel for color in colors for channel in color]
    flat_palette.extend([0] * (768 - len(flat_palette)))
    indexed_frames: list[Image.Image] = []
    for preview in previews:
        indexed = Image.new("P", preview.size)
        indexed.putpalette(flat_palette)
        indexed.putdata([color_to_index[color] for color in preview.get_flattened_data()])
        indexed_frames.append(indexed)
    return indexed_frames


def write_verified_gif(previews: list[Image.Image], path: Path, duration_ms: int) -> dict:
    indexed = exact_palette_frames(previews)
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
        "source_preview_pixel_exact": exact_matches,
        "passed": passed,
    }


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


def main() -> None:
    raw = Image.open(RAW_SHEET).convert("RGB")
    frames = extract_raw_frames(raw)
    start = prepared_keyframe(START_SOURCE)
    middle = prepared_keyframe(MID_SOURCE)
    frames[0] = start
    frames[MID_DELIVERY_FRAME - 1] = middle
    frames[-1] = start.copy()
    frames = quantize_with_shared_palette(frames)

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    frame_paths: list[Path] = []
    for index, frame in enumerate(frames, start=1):
        path = FRAME_DIR / f"frame_{index:03d}.png"
        frame.save(path, optimize=False)
        frame_paths.append(path)

    sheet = compose_sheet(frames)
    sheet.save(SHEET_PATH, optimize=False)
    sheet.save(OVERVIEW_PATH, optimize=False)
    preview_sheet = Image.new("RGBA", sheet.size, (*PREVIEW_BACKGROUND, 255))
    preview_sheet.alpha_composite(sheet)
    preview_sheet.resize(
        (preview_sheet.width * 4, preview_sheet.height * 4),
        Image.Resampling.NEAREST,
    ).save(ZOOM_OVERVIEW_PATH, optimize=False)

    previews = [compose_preview(frame) for frame in frames]
    gif_report = write_verified_gif(previews, GIF_PATH, FRAME_DURATION_MS)
    slow_gif_report = write_verified_gif(previews, SLOW_GIF_PATH, SLOW_FRAME_DURATION_MS)

    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("At least one delivery frame is empty")
    valid_boxes = [box for box in boxes if box is not None]
    edge_touch_frames = [
        index + 1
        for index, box in enumerate(valid_boxes)
        if box[0] == 0 or box[1] == 0 or box[2] == FRAME_SIZE[0] or box[3] == FRAME_SIZE[1]
    ]
    alpha_binary = [
        set(frame.getchannel("A").get_flattened_data()) <= {0, 255}
        for frame in frames
    ]
    spill_counts = [residual_teal_pixels(frame) for frame in frames]
    sequential_differences = [
        different_pixel_count(previews[index], previews[(index + 1) % len(previews)])
        for index in range(len(previews))
    ]
    first_last_identical = frames[0].tobytes() == frames[-1].tobytes()
    technical_pass = (
        not edge_touch_frames
        and all(alpha_binary)
        and all(count == 0 for count in spill_counts)
        and first_last_identical
        and bool(gif_report["passed"])
        and bool(slow_gif_report["passed"])
    )
    submission = json.loads((MANIFEST_ROOT / "submission.json").read_text(encoding="utf-8"))
    job = json.loads((MANIFEST_ROOT / "job.json").read_text(encoding="utf-8"))
    report = {
        "version": 1,
        "service": "Rika AI",
        "generation_id": submission["gen_id"],
        "generation_call_count": 1,
        "actual_credit_change": job["actual_credit_change"],
        "rika_padding": {
            "use_padding": submission["params"]["use_padding"],
            "padding_position": submission["params"]["padding_position"],
        },
        "source_sheet": relative(RAW_SHEET),
        "source_sheet_sha256": hashlib.sha256(RAW_SHEET.read_bytes()).hexdigest(),
        "frame_count": len(frames),
        "frame_size": list(FRAME_SIZE),
        "frame_paths": [relative(path) for path in frame_paths],
        "keyframe_contract": {
            "start_source": relative(START_SOURCE),
            "mid_source": relative(MID_SOURCE),
            "end_source": relative(START_SOURCE),
            "start_delivery_frame": 1,
            "mid_delivery_frame": MID_DELIVERY_FRAME,
            "end_delivery_frame": len(frames),
            "processing": "160x160 to 128x128 nearest-neighbor resize, binary alpha, shared palette without dithering",
        },
        "alpha_bounding_boxes": [list(box) for box in valid_boxes],
        "alpha_binary": alpha_binary,
        "edge_touch_frames": edge_touch_frames,
        "residual_teal_pixels": spill_counts,
        "first_last_identical": first_last_identical,
        "sequential_difference_pixels_including_loop": sequential_differences,
        "gif": gif_report,
        "slow_gif": slow_gif_report,
        "sheet": relative(SHEET_PATH),
        "overview": relative(OVERVIEW_PATH),
        "zoom_overview": relative(ZOOM_OVERVIEW_PATH),
        "technical_qa_status": "PASS" if technical_pass else "BLOCKED",
        "visual_qa_status": "PENDING_MANUAL_REVIEW",
    }
    MANIFEST_ROOT.mkdir(parents=True, exist_ok=True)
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not technical_pass:
        raise ValueError(f"Technical QA failed; see {QA_REPORT_PATH}")
    print(f"FRAME_COUNT={len(frames)}")
    print(f"EDGE_TOUCH_FRAMES={edge_touch_frames}")
    print(f"FIRST_LAST_IDENTICAL={first_last_identical}")
    print(f"GIF_EXACT_PIXEL_MATCH={gif_report['passed']}")
    print(f"SLOW_GIF_EXACT_PIXEL_MATCH={slow_gif_report['passed']}")
    print(f"OVERVIEW={OVERVIEW_PATH}")
    print(f"GIF={GIF_PATH}")


if __name__ == "__main__":
    main()
