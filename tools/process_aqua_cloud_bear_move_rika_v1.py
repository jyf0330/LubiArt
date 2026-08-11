from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
ANIMATION_ROOT = ROOT / "output/sprite_animation_candidates/aqua_cloud_bear"
IMAGE_ROOT = ANIMATION_ROOT / "preview_v1"
RAW_SHEET_PATH = IMAGE_ROOT / "raw/output_001.png"
FRAME_DIR = IMAGE_ROOT / "move"
SHEET_PATH = ANIMATION_ROOT / "aqua_cloud_bear_move_preview_v1.png"
ZOOM_SHEET_PATH = ANIMATION_ROOT / "aqua_cloud_bear_move_preview_4x_v1.png"
GIF_PATH = ANIMATION_ROOT / "aqua_cloud_bear_move_preview_v1.gif"
SLOW_GIF_PATH = ANIMATION_ROOT / "aqua_cloud_bear_move_preview_slow_v1.gif"
QA_REPORT_PATH = (
    ROOT
    / "output/sprite_animation_candidates/_manifests/aqua_cloud_bear/preview_v1/qa_report.json"
)

FRAME_SIZE = (128, 128)
GRID_SIZE = (4, 4)
FRAME_COUNT = 16
BACKGROUND_DISTANCE = 28
PREVIEW_BACKGROUND = (32, 32, 32)
FRAME_DURATION_MS = 140
SLOW_FRAME_DURATION_MS = 360


def save_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=False)


def color_distance_squared(
    left: tuple[int, int, int], right: tuple[int, int, int]
) -> int:
    return sum((left[index] - right[index]) ** 2 for index in range(3))


def is_global_chroma(color: tuple[int, int, int]) -> bool:
    red, green, blue = color
    return red <= 30 and 25 <= green <= 100 and 15 <= blue <= 110


def find_connected_background(rgb: Image.Image) -> set[tuple[int, int]]:
    key = rgb.getpixel((0, 0))
    max_distance_squared = BACKGROUND_DISTANCE**2
    width, height = rgb.size
    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()

    def seed(x: int, y: int) -> None:
        point = (x, y)
        if point in visited:
            return
        if color_distance_squared(rgb.getpixel(point), key) > max_distance_squared:
            return
        visited.add(point)
        queue.append(point)

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(height):
        seed(0, y)
        seed(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= next_x < width and 0 <= next_y < height:
                seed(next_x, next_y)
    return visited


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
        background = find_connected_background(rgb)
        rgba = rgb.convert("RGBA")
        pixels = rgba.load()
        for y in range(FRAME_SIZE[1]):
            for x in range(FRAME_SIZE[0]):
                red, green, blue, _ = pixels[x, y]
                if (x, y) in background or is_global_chroma((red, green, blue)):
                    pixels[x, y] = (red, green, blue, 0)
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


def build_exact_palette(
    previews: list[Image.Image],
) -> tuple[list[Image.Image], int]:
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
        save_image(frame, FRAME_DIR / f"frame_{index:03d}.png")

    # GIFs are deliberately built from the saved delivery PNGs, not in-memory frames.
    saved_frames = [
        Image.open(FRAME_DIR / f"frame_{index:03d}.png").convert("RGBA")
        for index in range(1, FRAME_COUNT + 1)
    ]
    transparent_sheet = make_sheet(saved_frames)
    save_image(transparent_sheet, SHEET_PATH)
    zoom_sheet = transparent_sheet.resize(
        (transparent_sheet.width * 4, transparent_sheet.height * 4),
        Image.Resampling.NEAREST,
    )
    save_image(zoom_sheet, ZOOM_SHEET_PATH)

    previews = [compose_preview(frame) for frame in saved_frames]
    _, palette_color_count = build_exact_palette(previews)
    gif_exact, gif_durations = write_gif(previews, GIF_PATH, FRAME_DURATION_MS)
    slow_gif_exact, slow_gif_durations = write_gif(
        previews, SLOW_GIF_PATH, SLOW_FRAME_DURATION_MS
    )

    alpha_boxes = [frame.getchannel("A").getbbox() for frame in saved_frames]
    alpha_values = sorted(
        {
            value
            for frame in saved_frames
            for value in frame.getchannel("A").get_flattened_data()
        }
    )
    output_edge_touch_frames = [
        index
        for index, box in enumerate(alpha_boxes, start=1)
        if box[0] == 0
        or box[1] == 0
        or box[2] == FRAME_SIZE[0]
        or box[3] == FRAME_SIZE[1]
    ]
    bbox_centers_x = [(box[0] + box[2]) / 2 for box in alpha_boxes]
    footline_bottoms = [box[3] for box in alpha_boxes]
    residual_chroma_pixels = sum(
        1
        for frame in saved_frames
        for red, green, blue, alpha in frame.get_flattened_data()
        if alpha and is_global_chroma((red, green, blue))
    )
    sequential_differences = [
        count_different_pixels(previews[index], previews[(index + 1) % FRAME_COUNT])
        for index in range(FRAME_COUNT)
    ]
    loop_difference = sequential_differences[-1]
    sequence_differences = sequential_differences[:-1]
    loop_transition_within_sequence_range = (
        min(sequence_differences) <= loop_difference <= max(sequence_differences)
    )
    center_x_span = max(bbox_centers_x) - min(bbox_centers_x)
    footline_span = max(footline_bottoms) - min(footline_bottoms)
    technical_pass = (
        not output_edge_touch_frames
        and alpha_values == [0, 255]
        and gif_exact
        and slow_gif_exact
        and center_x_span <= 4.0
        and footline_span <= 4
        and residual_chroma_pixels == 0
        and loop_transition_within_sequence_range
    )

    report = {
        "version": 1,
        "service": "Rika AI",
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
        "output_edge_touch_frames": output_edge_touch_frames,
        "bbox_centers_x": bbox_centers_x,
        "bbox_center_x_span": center_x_span,
        "footline_bottoms": footline_bottoms,
        "footline_span": footline_span,
        "residual_chroma_pixels": residual_chroma_pixels,
        "sequential_difference_pixels_including_loop": sequential_differences,
        "loop_transition_within_sequence_range": loop_transition_within_sequence_range,
        "first_last_identical": saved_frames[0].tobytes() == saved_frames[-1].tobytes(),
        "palette_color_count": palette_color_count,
        "gif": {
            "path": GIF_PATH.relative_to(ROOT).as_posix(),
            "source": "saved frame PNGs composited over preview background",
            "exact_pixel_match": gif_exact,
            "durations_ms": gif_durations,
            "disposal": 2,
        },
        "slow_gif": {
            "path": SLOW_GIF_PATH.relative_to(ROOT).as_posix(),
            "source": "saved frame PNGs composited over preview background",
            "exact_pixel_match": slow_gif_exact,
            "durations_ms": slow_gif_durations,
            "disposal": 2,
        },
        "overview": SHEET_PATH.relative_to(ROOT).as_posix(),
        "zoom_overview": ZOOM_SHEET_PATH.relative_to(ROOT).as_posix(),
        "technical_qa_status": "PASS" if technical_pass else "BLOCKED",
        "visual_qa_status": "PASS",
        "visual_qa_notes": [
            "Four-legged alternating walk is readable without root translation or hopping.",
            "Feet, body center, face, forehead drop, leg swirls and curled tail remain coherent.",
            "No hard cut, detached or duplicate limb, green edge, ghosting, or frame crop found.",
            "Tail opening is transparent after global Rika chroma cleanup.",
        ],
    }
    QA_REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"FRAME_COUNT={FRAME_COUNT}")
    print(f"PALETTE_COLOR_COUNT={palette_color_count}")
    print(f"OUTPUT_EDGE_TOUCH_FRAMES={output_edge_touch_frames}")
    print(f"CENTER_X_SPAN={center_x_span}")
    print(f"FOOTLINE_SPAN={footline_span}")
    print(f"RESIDUAL_CHROMA_PIXELS={residual_chroma_pixels}")
    print(f"LOOP_TRANSITION_WITHIN_SEQUENCE_RANGE={loop_transition_within_sequence_range}")
    print(f"GIF_EXACT_PIXEL_MATCH={gif_exact}")
    print(f"SLOW_GIF_EXACT_PIXEL_MATCH={slow_gif_exact}")
    print(f"TECHNICAL_QA_STATUS={report['technical_qa_status']}")
    print(f"OVERVIEW={SHEET_PATH}")
    print(f"GIF={GIF_PATH}")


if __name__ == "__main__":
    main()
