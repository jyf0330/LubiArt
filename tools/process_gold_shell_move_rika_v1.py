from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
ANIMATION_ROOT = ROOT / "art/images/shared/pets/animations/gold_shell"
IMAGE_ROOT = ANIMATION_ROOT / "preview_v1"
RAW_SHEET_PATH = IMAGE_ROOT / "raw/output_001.png"
FRAME_DIR = IMAGE_ROOT / "move"
SHEET_PATH = ANIMATION_ROOT / "gold_shell_move_preview_v1.png"
ZOOM_SHEET_PATH = ROOT / "output/gold_shell_move_frames_4x_v1.png"
GIF_PATH = ROOT / "output/gold_shell_frame_move_preview_v1.gif"
SLOW_GIF_PATH = ROOT / "output/gold_shell_frame_move_preview_slow_v1.gif"
QA_REPORT_PATH = (
    ROOT / "art/manifests/shared/pets/animations/gold_shell/preview_v1/qa_report.json"
)

FRAME_SIZE = (128, 128)
GRID_SIZE = (4, 4)
FRAME_COUNT = 16
CHROMA_DISTANCE = 24
PREVIEW_BACKGROUND = (32, 32, 32)
FRAME_DURATION_MS = 160
SLOW_FRAME_DURATION_MS = 360


def save_derived_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=False)


def color_distance_squared(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    return sum((left[index] - right[index]) ** 2 for index in range(3))


def is_chroma_background(
    color: tuple[int, int, int], key: tuple[int, int, int]
) -> bool:
    if color_distance_squared(color, key) <= CHROMA_DISTANCE**2:
        return True
    red, green, blue = color
    if (
        red <= 120
        and green >= red + 18
        and blue >= red + 18
        and abs(green - blue) <= 35
    ):
        return True
    return (
        red <= 56
        and green >= 36
        and blue >= 36
        and green >= red + 12
        and blue >= red + 12
        and abs(green - blue) <= 28
    )


def extract_frames(sheet: Image.Image) -> list[Image.Image]:
    expected_size = (
        FRAME_SIZE[0] * GRID_SIZE[0],
        FRAME_SIZE[1] * GRID_SIZE[1],
    )
    if sheet.size != expected_size:
        raise ValueError(f"Unexpected Rika sheet size: {sheet.size}; expected {expected_size}")

    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        column = index % GRID_SIZE[0]
        row = index // GRID_SIZE[0]
        left = column * FRAME_SIZE[0]
        top = row * FRAME_SIZE[1]
        rgb = sheet.crop(
            (left, top, left + FRAME_SIZE[0], top + FRAME_SIZE[1])
        ).convert("RGB")
        key = rgb.getpixel((0, 0))
        rgba = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        output_pixels = rgba.load()
        input_pixels = rgb.load()
        for y in range(FRAME_SIZE[1]):
            for x in range(FRAME_SIZE[0]):
                color = input_pixels[x, y]
                alpha = 0 if is_chroma_background(color, key) else 255
                output_pixels[x, y] = (*color, alpha)
        if rgba.getchannel("A").getbbox() is None:
            raise ValueError(f"Frame {index + 1} became fully transparent")
        frames.append(rgba)
    return frames


def compose_preview(frame: Image.Image) -> Image.Image:
    preview = Image.new("RGB", FRAME_SIZE, PREVIEW_BACKGROUND)
    preview.paste(frame.convert("RGB"), mask=frame.getchannel("A"))
    return preview


def make_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * GRID_SIZE[0], FRAME_SIZE[1] * GRID_SIZE[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        x = (index % GRID_SIZE[0]) * FRAME_SIZE[0]
        y = (index // GRID_SIZE[0]) * FRAME_SIZE[1]
        sheet.alpha_composite(frame, (x, y))
    return sheet


def build_exact_palette(previews: list[Image.Image]) -> tuple[list[Image.Image], int]:
    colors = sorted(
        {color for frame in previews for color in frame.get_flattened_data()}
    )
    if len(colors) > 256:
        raise ValueError(
            f"Exact GIF verification is impossible with {len(colors)} RGB colors"
        )
    color_to_index = {color: index for index, color in enumerate(colors)}
    flat_palette = [channel for color in colors for channel in color]
    flat_palette.extend([0] * (768 - len(flat_palette)))

    indexed_frames: list[Image.Image] = []
    for preview in previews:
        indexed = Image.new("P", preview.size)
        indexed.putpalette(flat_palette)
        indexed.putdata(
            [color_to_index[color] for color in preview.get_flattened_data()]
        )
        indexed_frames.append(indexed)
    return indexed_frames, len(colors)


def write_gif(
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
    durations = []
    decoded.seek(0)
    for index in range(getattr(decoded, "n_frames", 1)):
        decoded.seek(index)
        durations.append(int(decoded.info.get("duration", 0)))

    exact = len(decoded_frames) == len(previews) and all(
        decoded_frame.tobytes() == preview.tobytes()
        for decoded_frame, preview in zip(decoded_frames, previews, strict=True)
    )
    if not exact:
        raise ValueError(f"GIF frames do not exactly match source previews: {path}")
    if durations != [duration_ms] * len(previews):
        raise ValueError(f"Unexpected GIF durations for {path}: {durations}")
    return exact, durations


def count_different_pixels(left: Image.Image, right: Image.Image) -> int:
    return sum(
        left_pixel != right_pixel
        for left_pixel, right_pixel in zip(
            left.get_flattened_data(), right.get_flattened_data(), strict=True
        )
    )


def main() -> None:
    raw_sheet = Image.open(RAW_SHEET_PATH).convert("RGB")
    frames = extract_frames(raw_sheet)
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames, start=1):
        save_derived_image(frame, FRAME_DIR / f"frame_{index:03d}.png")

    transparent_sheet = make_sheet(frames)
    save_derived_image(transparent_sheet, SHEET_PATH)
    zoom_sheet = transparent_sheet.resize(
        (transparent_sheet.width * 4, transparent_sheet.height * 4),
        Image.Resampling.NEAREST,
    )
    save_derived_image(zoom_sheet, ZOOM_SHEET_PATH)

    previews = [compose_preview(frame) for frame in frames]
    _, palette_color_count = build_exact_palette(previews)
    gif_exact, gif_durations = write_gif(
        previews, GIF_PATH, FRAME_DURATION_MS
    )
    slow_gif_exact, slow_gif_durations = write_gif(
        previews, SLOW_GIF_PATH, SLOW_FRAME_DURATION_MS
    )

    alpha_boxes = [frame.getchannel("A").getbbox() for frame in frames]
    alpha_values = sorted(
        {
            value
            for frame in frames
            for value in frame.getchannel("A").get_flattened_data()
        }
    )
    residual_chroma_pixels = sum(
        1
        for frame in frames
        for red, green, blue, alpha in frame.get_flattened_data()
        if alpha
        and red <= 120
        and green >= red + 18
        and blue >= red + 18
        and abs(green - blue) <= 35
    )
    head_centers_x: list[float] = []
    for frame in frames:
        head_x = [
            x
            for y in range(45)
            for x in range(FRAME_SIZE[0])
            if frame.getpixel((x, y))[3]
        ]
        head_centers_x.append((min(head_x) + max(head_x) + 1) / 2)
    footline_bottoms = [box[3] for box in alpha_boxes]
    sequential_differences = [
        count_different_pixels(previews[index], previews[(index + 1) % FRAME_COUNT])
        for index in range(FRAME_COUNT)
    ]
    report = {
        "version": 1,
        "source_sheet": RAW_SHEET_PATH.relative_to(ROOT).as_posix(),
        "source_sheet_sha256": hashlib.sha256(RAW_SHEET_PATH.read_bytes()).hexdigest(),
        "frame_count": FRAME_COUNT,
        "frame_size": list(FRAME_SIZE),
        "frame_paths": [
            (FRAME_DIR / f"frame_{index:03d}.png").relative_to(ROOT).as_posix()
            for index in range(1, FRAME_COUNT + 1)
        ],
        "alpha_bounding_boxes": [list(box) for box in alpha_boxes],
        "alpha_values": alpha_values,
        "residual_chroma_pixels": residual_chroma_pixels,
        "head_centers_x": head_centers_x,
        "footline_bottoms": footline_bottoms,
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
        "overview": SHEET_PATH.relative_to(ROOT).as_posix(),
        "zoom_overview": ZOOM_SHEET_PATH.relative_to(ROOT).as_posix(),
        "technical_qa_status": "PASS",
        "user_review_note": (
            "Frames 8 and 16 contain the model's brief facial/blink variation; "
            "confirm this expression before integrating the move animation."
        ),
    }
    QA_REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"FRAME_COUNT={FRAME_COUNT}")
    print(f"PALETTE_COLOR_COUNT={palette_color_count}")
    print(f"GIF_EXACT_PIXEL_MATCH={gif_exact}")
    print(f"SLOW_GIF_EXACT_PIXEL_MATCH={slow_gif_exact}")
    print(f"FIRST_LAST_IDENTICAL={report['first_last_identical']}")
    print(f"OVERVIEW={SHEET_PATH}")
    print(f"GIF={GIF_PATH}")


if __name__ == "__main__":
    main()
