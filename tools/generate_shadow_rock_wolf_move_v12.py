import json
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "output/shadow_rock_wolf_walk_v12"
SOURCE_PATH = OUTPUT_ROOT / "source/shadow_rock_wolf_walk_sheet_transparent_v12.png"
FRAME_DIR = OUTPUT_ROOT / "frames"
OVERVIEW_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_overview_v12.png"
OVERVIEW_4X_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_overview_4x_v12.png"
GIF_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_preview_v12.gif"
SLOW_GIF_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_slow_check_v12.gif"
REPORT_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_qa_v12.json"

FRAME_SIZE = (200, 200)
GRID_SIZE = (4, 3)
FRAME_COUNT = 12
TARGET_GEM_X = 148
TARGET_FOOTLINE = 190
TARGET_MAX_WIDTH = 190
TARGET_MAX_HEIGHT = 180
FRAME_DURATION_MS = 80
SLOW_FRAME_DURATION_MS = 400
PREVIEW_BACKGROUND = (43, 46, 52, 255)


def harden_alpha(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (
                (red, green, blue, 255) if alpha >= 128 else (0, 0, 0, 0)
            )
    return result


def content_box(image: Image.Image) -> tuple[int, int, int, int]:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise ValueError("A walk pose is empty")
    return box


def find_gem_center(image: Image.Image) -> tuple[float, float]:
    points: list[tuple[int, int]] = []
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha >= 128
                and blue >= 125
                and green >= 70
                and blue > red * 1.35
                and green > red * 1.15
            ):
                points.append((x, y))
    if not points:
        raise ValueError("Could not find the blue forehead gem")
    return (
        sum(point[0] for point in points) / len(points),
        sum(point[1] for point in points) / len(points),
    )


def split_whole_frames(sheet: Image.Image) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for row in range(GRID_SIZE[1]):
        for column in range(GRID_SIZE[0]):
            left = round(column * sheet.width / GRID_SIZE[0])
            top = round(row * sheet.height / GRID_SIZE[1])
            right = round((column + 1) * sheet.width / GRID_SIZE[0])
            bottom = round((row + 1) * sheet.height / GRID_SIZE[1])
            frames.append(harden_alpha(sheet.crop((left, top, right, bottom))))
    return frames


def normalize_whole_frame(panel: Image.Image, scale: float) -> Image.Image:
    source_box = content_box(panel)
    gem_x, _gem_y = find_gem_center(panel)
    resized = panel.resize(
        (round(panel.width * scale), round(panel.height * scale)),
        Image.Resampling.NEAREST,
    )
    resized_box = content_box(resized)
    destination_x = round(TARGET_GEM_X - gem_x * scale)
    destination_y = TARGET_FOOTLINE - resized_box[3]

    left = destination_x + resized_box[0]
    right = destination_x + resized_box[2]
    if left < 1:
        destination_x += 1 - left
    if right > FRAME_SIZE[0] - 1:
        destination_x -= right - (FRAME_SIZE[0] - 1)

    frame = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    frame.alpha_composite(resized, (destination_x, destination_y))
    frame = harden_alpha(frame)
    if content_box(frame)[3] != TARGET_FOOTLINE:
        raise ValueError("Foot baseline normalization failed")
    return frame


def composite_preview(frame: Image.Image) -> Image.Image:
    preview = Image.new("RGBA", FRAME_SIZE, PREVIEW_BACKGROUND)
    preview.alpha_composite(frame)
    return preview.convert("RGB")


def opaque_component_sizes(image: Image.Image) -> list[int]:
    alpha = image.getchannel("A")
    remaining = {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if alpha.getpixel((x, y)) >= 128
    }
    sizes: list[int] = []
    while remaining:
        stack = [remaining.pop()]
        size = 0
        while stack:
            x, y = stack.pop()
            size += 1
            for neighbor_y in range(max(0, y - 1), min(image.height, y + 2)):
                for neighbor_x in range(max(0, x - 1), min(image.width, x + 2)):
                    neighbor = (neighbor_x, neighbor_y)
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        stack.append(neighbor)
        sizes.append(size)
    return sorted(sizes, reverse=True)


def remove_tiny_opaque_components(
    image: Image.Image,
    maximum_size: int = 4,
) -> Image.Image:
    result = image.copy()
    alpha = result.getchannel("A")
    remaining = {
        (x, y)
        for y in range(result.height)
        for x in range(result.width)
        if alpha.getpixel((x, y)) >= 128
    }
    while remaining:
        seed = remaining.pop()
        component = [seed]
        stack = [seed]
        while stack:
            x, y = stack.pop()
            for neighbor_y in range(max(0, y - 1), min(result.height, y + 2)):
                for neighbor_x in range(max(0, x - 1), min(result.width, x + 2)):
                    neighbor = (neighbor_x, neighbor_y)
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        component.append(neighbor)
                        stack.append(neighbor)
        if len(component) <= maximum_size:
            for x, y in component:
                result.putpixel((x, y), (0, 0, 0, 0))
    return result


def green_spill_pixel_count(image: Image.Image) -> int:
    return sum(
        1
        for red, green, blue, alpha in image.getdata()
        if (
            alpha >= 128
            and green > 140
            and green > red * 1.8
            and green > blue * 1.4
        )
    )


def apply_shared_palette(frames: list[Image.Image]) -> tuple[list[Image.Image], list[Image.Image]]:
    atlas = Image.new("RGB", (FRAME_SIZE[0] * FRAME_COUNT, FRAME_SIZE[1]))
    for index, frame in enumerate(frames):
        atlas.paste(composite_preview(frame), (index * FRAME_SIZE[0], 0))
    palette = atlas.quantize(
        colors=256,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )

    quantized_frames: list[Image.Image] = []
    gif_frames: list[Image.Image] = []
    for frame in frames:
        preview_p = composite_preview(frame).quantize(
            palette=palette,
            dither=Image.Dither.NONE,
        )
        rgba = preview_p.convert("RGBA")
        rgba.putalpha(frame.getchannel("A"))
        quantized_frames.append(harden_alpha(rgba))
        gif_frames.append(preview_p)
    return quantized_frames, gif_frames


def save_gif(path: Path, frames: list[Image.Image], duration_ms: int) -> None:
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=[duration_ms] * len(frames),
        loop=0,
        disposal=2,
        optimize=False,
    )


def verify_gif(path: Path, previews: list[Image.Image], duration_ms: int) -> dict:
    gif = Image.open(path)
    exact_matches: list[bool] = []
    disposal_methods: list[int | None] = []
    durations: list[int | None] = []
    for index, preview in enumerate(previews):
        gif.seek(index)
        exact_matches.append(
            ImageChops.difference(preview.convert("RGB"), gif.convert("RGB")).getbbox()
            is None
        )
        disposal_methods.append(getattr(gif, "disposal_method", None))
        durations.append(gif.info.get("duration"))
    return {
        "frame_count": gif.n_frames,
        "expected_frame_count": len(previews),
        "durations_ms": durations,
        "expected_duration_ms": duration_ms,
        "disposal_methods": disposal_methods,
        "source_preview_pixel_exact": exact_matches,
        "passed": (
            gif.n_frames == len(previews)
            and all(duration == duration_ms for duration in durations)
            and all(method == 2 for method in disposal_methods)
            and all(exact_matches)
        ),
    }


def main() -> None:
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SOURCE_PATH).convert("RGBA")
    panels = split_whole_frames(sheet)
    if len(panels) != FRAME_COUNT:
        raise ValueError(f"Expected {FRAME_COUNT} frames, found {len(panels)}")

    boxes = [content_box(panel) for panel in panels]
    fixed_scale = min(
        TARGET_MAX_WIDTH / max(box[2] - box[0] for box in boxes),
        TARGET_MAX_HEIGHT / max(box[3] - box[1] for box in boxes),
    )
    normalized = [
        remove_tiny_opaque_components(normalize_whole_frame(panel, fixed_scale))
        for panel in panels
    ]
    frames, gif_frames = apply_shared_palette(normalized)

    for index, frame in enumerate(frames, start=1):
        frame.save(FRAME_DIR / f"frame_{index:03d}.png", optimize=False)

    overview = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * GRID_SIZE[0], FRAME_SIZE[1] * GRID_SIZE[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        overview.alpha_composite(
            frame,
            (
                (index % GRID_SIZE[0]) * FRAME_SIZE[0],
                (index // GRID_SIZE[0]) * FRAME_SIZE[1],
            ),
        )
    overview.save(OVERVIEW_PATH, optimize=False)

    overview_dark = Image.new("RGBA", overview.size, PREVIEW_BACKGROUND)
    overview_dark.alpha_composite(overview)
    overview_dark.resize(
        (overview.width * 4, overview.height * 4),
        Image.Resampling.NEAREST,
    ).save(OVERVIEW_4X_PATH, optimize=False)

    save_gif(GIF_PATH, gif_frames, FRAME_DURATION_MS)
    save_gif(SLOW_GIF_PATH, gif_frames, SLOW_FRAME_DURATION_MS)

    previews = [frame.convert("RGB") for frame in gif_frames]
    frame_boxes = [content_box(frame) for frame in frames]
    component_sizes = [opaque_component_sizes(frame) for frame in frames]
    green_spill_pixels = [green_spill_pixel_count(frame) for frame in frames]
    report = {
        "source_sheet_size": list(sheet.size),
        "processing": {
            "whole_frame_only": True,
            "rectangular_splice": False,
            "fixed_scale": fixed_scale,
            "target_footline": TARGET_FOOTLINE,
        },
        "frames": {
            "count": len(frames),
            "sizes": [list(frame.size) for frame in frames],
            "alpha_binary": [
                set(frame.getchannel("A").getdata()) <= {0, 255} for frame in frames
            ],
            "transparent_corners": [frame.getpixel((0, 0))[3] == 0 for frame in frames],
            "content_boxes": [list(box) for box in frame_boxes],
            "footline_box_bottom": [box[3] for box in frame_boxes],
            "opaque_component_sizes": component_sizes,
            "green_spill_pixels": green_spill_pixels,
        },
        "final_gif": verify_gif(GIF_PATH, previews, FRAME_DURATION_MS),
        "slow_check_gif": verify_gif(
            SLOW_GIF_PATH,
            previews,
            SLOW_FRAME_DURATION_MS,
        ),
    }
    report["passed"] = (
        report["processing"]["rectangular_splice"] is False
        and len(frames) == FRAME_COUNT
        and all(report["frames"]["alpha_binary"])
        and all(report["frames"]["transparent_corners"])
        and all(
            bottom == TARGET_FOOTLINE
            for bottom in report["frames"]["footline_box_bottom"]
        )
        and all(len(sizes) == 1 for sizes in component_sizes)
        and all(count == 0 for count in green_spill_pixels)
        and report["final_gif"]["passed"]
        and report["slow_check_gif"]["passed"]
    )
    REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    if not report["passed"]:
        raise ValueError(f"QA failed; see {REPORT_PATH}")


if __name__ == "__main__":
    main()
