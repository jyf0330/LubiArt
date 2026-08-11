from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


SOURCE = Path(r"C:\Users\jyf\Desktop\overview_121_frames_dark.png")
OUTPUT = Path("output/sprite_animations/rock_creature_breathing_idle_16f_v1")

GRID_ROWS = 11
GRID_COLUMNS = 11
FRAME_SIZE = 128
GRID_X = 60
GRID_Y = 5
GRID_STEP_X = 244
GRID_STEP_Y = 139

# Even phase samples across a 121-frame loop. The final source frame is omitted so
# the wrap back to frame 1 has the same seven/eight-frame spacing as every other step.
SOURCE_FRAME_INDICES = [0, 8, 15, 23, 30, 38, 45, 53, 60, 68, 76, 83, 91, 98, 106, 113]
FRAME_DURATION_MS = 150

BACKGROUND_COLORS = np.array([[31, 35, 42], [32, 36, 43]], dtype=np.int16)
OVERVIEW_BACKGROUND = (31, 35, 42, 255)


def extract_source_frame(sheet: Image.Image, source_index: int) -> Image.Image:
    row, column = divmod(source_index, GRID_COLUMNS)
    x = GRID_X + column * GRID_STEP_X
    y = GRID_Y + row * GRID_STEP_Y
    crop = sheet.crop((x, y, x + FRAME_SIZE, y + FRAME_SIZE)).convert("RGBA")

    pixels = np.asarray(crop).copy()
    rgb = pixels[:, :, :3].astype(np.int16)
    differences = rgb[:, :, None, :] - BACKGROUND_COLORS[None, None, :, :]
    distances_squared = np.sum(differences * differences, axis=3)
    background = np.min(distances_squared, axis=2) <= 4
    pixels[:, :, 3] = np.where(background, 0, 255).astype(np.uint8)
    pixels[background, :3] = 0
    return Image.fromarray(pixels, "RGBA")


def make_shared_palette(frames: list[Image.Image]) -> Image.Image:
    foreground = []
    for frame in frames:
        array = np.asarray(frame)
        foreground.append(array[array[:, :, 3] > 0, :3])
    pixels = np.concatenate(foreground, axis=0)
    palette_source = Image.fromarray(pixels.reshape(1, -1, 3).astype(np.uint8), "RGB")
    quantized = palette_source.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    opaque_palette = quantized.getpalette()[: 255 * 3]
    opaque_palette += [0] * (255 * 3 - len(opaque_palette))

    palette = [255, 0, 255] + opaque_palette
    palette_image = Image.new("P", (1, 1), 0)
    palette_image.putpalette(palette)
    return palette_image


def quantize_frame(frame: Image.Image, palette_image: Image.Image) -> Image.Image:
    rgba = np.asarray(frame)
    rgb = rgba[:, :, :3].copy()
    transparent = rgba[:, :, 3] == 0
    rgb[transparent] = (255, 0, 255)
    quantized = Image.fromarray(rgb, "RGB").quantize(
        palette=palette_image,
        dither=Image.Dither.NONE,
    )
    indices = np.asarray(quantized).copy()
    indices[transparent] = 0
    if np.any((~transparent) & (indices == 0)):
        raise RuntimeError("An opaque sprite pixel mapped to the reserved transparency index")
    result = Image.fromarray(indices.astype(np.uint8), "P")
    result.putpalette(palette_image.getpalette())
    result.info["transparency"] = 0
    return result


def build_overview(frames: list[Image.Image], output_path: Path) -> None:
    scale = 4
    columns = 4
    rows = 4
    gap = 24
    margin = 24
    label_height = 24
    scaled_size = FRAME_SIZE * scale
    width = margin * 2 + columns * scaled_size + (columns - 1) * gap
    height = margin * 2 + rows * (scaled_size + label_height) + (rows - 1) * gap
    overview = Image.new("RGBA", (width, height), OVERVIEW_BACKGROUND)
    draw = ImageDraw.Draw(overview)

    for index, frame in enumerate(frames):
        row, column = divmod(index, columns)
        x = margin + column * (scaled_size + gap)
        y = margin + row * (scaled_size + label_height + gap)
        draw.text((x, y), f"{index + 1:02d}", fill=(220, 224, 230, 255))
        enlarged = frame.convert("RGBA").resize(
            (scaled_size, scaled_size),
            resample=Image.Resampling.NEAREST,
        )
        overview.alpha_composite(enlarged, (x, y + label_height))

    overview.convert("RGB").save(output_path, optimize=True)


def compare_gif_to_frames(gif_path: Path, frames: list[Image.Image]) -> dict[str, object]:
    decoded = Image.open(gif_path)
    decoded_frames: list[Image.Image] = []
    durations: list[int] = []
    try:
        for index in range(decoded.n_frames):
            decoded.seek(index)
            decoded_frames.append(decoded.convert("RGBA").copy())
            durations.append(int(decoded.info.get("duration", 0)))
    finally:
        decoded.close()

    exact_matches = []
    max_channel_differences = []
    for expected, actual in zip(frames, decoded_frames, strict=True):
        expected_array = np.asarray(expected.convert("RGBA"), dtype=np.int16)
        actual_array = np.asarray(actual, dtype=np.int16)
        difference = np.abs(expected_array - actual_array)
        exact_matches.append(bool(np.array_equal(expected_array, actual_array)))
        max_channel_differences.append(int(difference.max()))

    return {
        "decoded_frame_count": len(decoded_frames),
        "durations_ms": durations,
        "all_frames_exact_rgba_match": all(exact_matches),
        "per_frame_exact_rgba_match": exact_matches,
        "max_channel_difference": max(max_channel_differences, default=0),
    }


def alpha_bbox(frame: Image.Image) -> tuple[int, int, int, int] | None:
    return frame.getchannel("A").getbbox()


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    frames_directory = OUTPUT / "frames"
    frames_directory.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(SOURCE)
    if sheet.size != (2688, 1533):
        raise RuntimeError(f"Unexpected source overview size: {sheet.size}")
    if GRID_ROWS * GRID_COLUMNS != 121:
        raise RuntimeError("Grid definition does not describe 121 source frames")

    extracted = [extract_source_frame(sheet, index) for index in SOURCE_FRAME_INDICES]
    palette_image = make_shared_palette(extracted)
    frames = [quantize_frame(frame, palette_image) for frame in extracted]

    frame_paths = []
    for index, frame in enumerate(frames, start=1):
        frame_path = frames_directory / f"frame_{index:02d}.png"
        frame.save(frame_path, transparency=0, optimize=True)
        frame_paths.append(frame_path)

    # Reopen the delivery PNGs before GIF encoding so Pillow uses the normalized
    # on-disk palette representation for every frame.
    frames = []
    for frame_path in frame_paths:
        with Image.open(frame_path) as saved_frame:
            saved_frame.load()
            frames.append(saved_frame.copy())

    gif_path = OUTPUT / "breathing_idle_16f.gif"
    frames[0].save(
        gif_path,
        save_all=True,
        append_images=frames[1:],
        duration=FRAME_DURATION_MS,
        loop=0,
        transparency=0,
        disposal=2,
        optimize=False,
    )

    overview_path = OUTPUT / "breathing_idle_16f_overview_dark.png"
    build_overview(frames, overview_path)

    gif_report = compare_gif_to_frames(gif_path, frames)
    if not gif_report["all_frames_exact_rgba_match"]:
        raise RuntimeError(f"GIF verification failed: {gif_report}")

    bboxes = [alpha_bbox(frame.convert("RGBA")) for frame in frames]
    bottoms = [bbox[3] for bbox in bboxes if bbox is not None]
    centers_x = [(bbox[0] + bbox[2]) / 2 for bbox in bboxes if bbox is not None]
    qa_report = {
        "source_overview": SOURCE.name,
        "source_grid": {"columns": GRID_COLUMNS, "rows": GRID_ROWS, "frame_count": 121},
        "selected_source_frames_1_based": [index + 1 for index in SOURCE_FRAME_INDICES],
        "output_frame_count": len(frames),
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "frame_duration_ms": FRAME_DURATION_MS,
        "loop_duration_ms": FRAME_DURATION_MS * len(frames),
        "alpha_bboxes": bboxes,
        "anchor_summary": {
            "bottom_min": min(bottoms),
            "bottom_max": max(bottoms),
            "center_x_min": min(centers_x),
            "center_x_max": max(centers_x),
        },
        "gif_verification": gif_report,
        "outputs": {
            "overview": overview_path.name,
            "gif": gif_path.name,
            "frames": [str(Path("frames") / path.name) for path in frame_paths],
        },
    }
    (OUTPUT / "qa_report.json").write_text(
        json.dumps(qa_report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(qa_report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
