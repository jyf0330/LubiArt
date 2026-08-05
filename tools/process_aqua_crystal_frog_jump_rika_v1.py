from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
ANIMATION_ROOT = ROOT / "art/images/shared/pets/animations/aqua_crystal_frog"
IMAGE_ROOT = ANIMATION_ROOT / "jump_v1"
RAW_SHEET_PATH = IMAGE_ROOT / "raw/output_001.png"
FRAME_DIR = IMAGE_ROOT / "frames"
SHEET_PATH = ANIMATION_ROOT / "aqua_crystal_frog_jump_preview_v1.png"
ZOOM_SHEET_PATH = ROOT / "output/aqua_crystal_frog_jump_frames_4x_v1.png"
GIF_PATH = ROOT / "output/aqua_crystal_frog_jump_preview_v1.gif"
SLOW_GIF_PATH = ROOT / "output/aqua_crystal_frog_jump_preview_slow_v1.gif"
QA_REPORT_PATH = (
    ROOT
    / "art/manifests/shared/pets/animations/aqua_crystal_frog/jump_v1/qa_report.json"
)

FRAME_SIZE = (128, 128)
GRID_SIZE = (4, 4)
FRAME_COUNT = 16
PREVIEW_BACKGROUND = (32, 32, 32)
FRAME_DURATION_MS = 110
SLOW_FRAME_DURATION_MS = 360


def save_derived_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=False)


def border_connected_key_mask(
    rgb: Image.Image, key: tuple[int, int, int]
) -> Image.Image:
    """Remove only key-colored pixels connected to the frame border."""
    width, height = rgb.size
    pixels = rgb.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if visited[index] or pixels[x, y] != key:
            return
        visited[index] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    alpha = Image.new("L", (width, height), 255)
    alpha.putdata([0 if value else 255 for value in visited])
    return alpha


def keep_largest_alpha_component(rgba: Image.Image) -> tuple[Image.Image, int]:
    width, height = rgba.size
    alpha = rgba.getchannel("A")
    pixels = alpha.load()
    visited: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not pixels[x, y] or (x, y) in visited:
                continue
            component: list[tuple[int, int]] = []
            queue = [(x, y)]
            visited.add((x, y))
            while queue:
                current_x, current_y = queue.pop()
                component.append((current_x, current_y))
                for next_x, next_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if not (0 <= next_x < width and 0 <= next_y < height):
                        continue
                    if not pixels[next_x, next_y] or (next_x, next_y) in visited:
                        continue
                    visited.add((next_x, next_y))
                    queue.append((next_x, next_y))
            components.append(component)

    if not components:
        raise ValueError("Frame contains no opaque component")
    largest = max(components, key=len)
    largest_points = set(largest)
    removed = sum(len(component) for component in components) - len(largest)
    cleaned_alpha = Image.new("L", (width, height), 0)
    cleaned_alpha.putdata(
        [
            255 if (x, y) in largest_points else 0
            for y in range(height)
            for x in range(width)
        ]
    )
    cleaned = rgba.copy()
    cleaned.putalpha(cleaned_alpha)
    return cleaned, removed


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
        rgba = rgb.convert("RGBA")
        rgba.putalpha(border_connected_key_mask(rgb, key))
        rgba, _ = keep_largest_alpha_component(rgba)
        if rgba.getchannel("A").getbbox() is None:
            raise ValueError(f"Frame {index + 1} became fully transparent")
        frames.append(rgba)
    # The generated recovery pose is visually close but not pixel-identical.
    # Reuse the confirmed first frame as the final frame for a clean loop.
    frames[-1] = frames[0].copy()
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


def make_preview_sheet(previews: list[Image.Image]) -> Image.Image:
    sheet = Image.new(
        "RGB",
        (FRAME_SIZE[0] * GRID_SIZE[0], FRAME_SIZE[1] * GRID_SIZE[1]),
        PREVIEW_BACKGROUND,
    )
    for index, preview in enumerate(previews):
        x = (index % GRID_SIZE[0]) * FRAME_SIZE[0]
        y = (index // GRID_SIZE[0]) * FRAME_SIZE[1]
        sheet.paste(preview, (x, y))
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
    durations: list[int] = []
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
    previews = [compose_preview(frame) for frame in frames]
    preview_sheet = make_preview_sheet(previews)
    zoom_sheet = preview_sheet.resize(
        (preview_sheet.width * 4, preview_sheet.height * 4),
        Image.Resampling.NEAREST,
    )
    save_derived_image(zoom_sheet, ZOOM_SHEET_PATH)

    _, palette_color_count = build_exact_palette(previews)
    gif_exact, gif_durations = write_gif(previews, GIF_PATH, FRAME_DURATION_MS)
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
    key_colors = [
        raw_sheet.getpixel(((index % 4) * 128, (index // 4) * 128))
        for index in range(FRAME_COUNT)
    ]
    residual_key_pixels = [
        sum(
            1
            for red, green, blue, alpha in frame.get_flattened_data()
            if alpha and (red, green, blue) == key_colors[index]
        )
        for index, frame in enumerate(frames)
    ]
    centers_x = [(box[0] + box[2]) / 2 for box in alpha_boxes]
    top_edges = [box[1] for box in alpha_boxes]
    bottom_edges = [box[3] for box in alpha_boxes]
    source_edge_touch_frames = [
        index + 1
        for index, box in enumerate(alpha_boxes)
        if box[0] == 0 or box[1] == 0 or box[2] == 128 or box[3] == 128
    ]
    sequential_differences = [
        count_different_pixels(previews[index], previews[(index + 1) % FRAME_COUNT])
        for index in range(FRAME_COUNT)
    ]
    duplicate_groups: list[list[int]] = []
    claimed: set[int] = set()
    for left in range(FRAME_COUNT):
        if left in claimed:
            continue
        group = [
            right + 1
            for right in range(left, FRAME_COUNT)
            if frames[left].tobytes() == frames[right].tobytes()
        ]
        if len(group) > 1:
            duplicate_groups.append(group)
            claimed.update(index - 1 for index in group)

    report = {
        "version": 1,
        "service": "Rika AI",
        "generation_id": "ecd3f354-637f-4293-9950-8833bac5cb31",
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
        "key_colors": [list(color) for color in key_colors],
        "residual_connected_chroma_pixels": residual_key_pixels,
        "horizontal_centers": centers_x,
        "top_edges": top_edges,
        "bottom_edges": bottom_edges,
        "source_edge_touch_frames": source_edge_touch_frames,
        "sequential_difference_pixels_including_loop": sequential_differences,
        "first_last_identical": frames[0].tobytes() == frames[-1].tobytes(),
        "duplicate_frame_groups": duplicate_groups,
        "deterministic_postprocess": {
            "largest_component_only": True,
            "final_frame_reuses_first_frame": True,
        },
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
        "technical_qa_status": "PASS" if not source_edge_touch_frames else "BLOCKED",
        "user_review_note": (
            "Review the full jump arc, eye identity, rear-leg extension, landing, "
            "and the repeated recovery frames before runtime integration."
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
    print(f"EDGE_TOUCH_FRAMES={source_edge_touch_frames}")
    print(f"DUPLICATE_GROUPS={duplicate_groups}")
    print(f"TECHNICAL_QA_STATUS={report['technical_qa_status']}")
    print(f"OVERVIEW={SHEET_PATH}")
    print(f"GIF={GIF_PATH}")


if __name__ == "__main__":
    main()
