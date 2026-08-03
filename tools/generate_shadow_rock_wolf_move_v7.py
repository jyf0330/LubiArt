from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ANIMATION_ROOT = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf"
SHEET_PATH = ANIMATION_ROOT / "sources/shadow_rock_wolf_walk_sheet_transparent_v7.png"
FRAME_DIR = ANIMATION_ROOT / "preview_v7/move"
STRIP_PATH = ANIMATION_ROOT / "shadow_rock_wolf_move_preview_v7.png"
GIF_PATH = ROOT / "output/shadow_rock_wolf_frame_move_preview_v7.gif"

FRAME_SIZE = (200, 200)
FRAME_COUNT = 8
TARGET_GEM = (46, 50)
TARGET_FOOTLINE = 190
FRAME_DURATION_MS = (190,) * FRAME_COUNT
PREVIEW_BACKGROUND = (43, 46, 52, 255)
SCALE_MULTIPLIER = 1.0


def find_character_runs(sheet: Image.Image) -> list[tuple[int, int]]:
    alpha = sheet.getchannel("A")
    occupied = []
    for x in range(sheet.width):
        column = alpha.crop((x, 0, x + 1, sheet.height))
        occupied.append(sum(1 for value in column.getdata() if value >= 128) >= 5)

    runs: list[tuple[int, int]] = []
    start: int | None = None
    for x, has_pixels in enumerate(occupied + [False]):
        if has_pixels and start is None:
            start = x
        elif not has_pixels and start is not None:
            if x - start > 100:
                runs.append((start, x))
            start = None
    if len(runs) != FRAME_COUNT:
        raise ValueError(f"Expected {FRAME_COUNT} walk poses, found {len(runs)}")
    return runs


def find_gem_center(panel: Image.Image) -> tuple[float, float]:
    points: list[tuple[int, int]] = []
    pixels = panel.load()
    for y in range(180, min(360, panel.height)):
        for x in range(panel.width):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha >= 128
                and blue > 130
                and green > 80
                and blue > red * 1.35
                and green > red * 1.2
            ):
                points.append((x, y))
    if not points:
        raise ValueError("Could not locate the forehead gem")
    return (
        sum(point[0] for point in points) / len(points),
        sum(point[1] for point in points) / len(points),
    )


def harden_alpha(image: Image.Image) -> Image.Image:
    result = image.copy()
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (
                (red, green, blue, 255) if alpha >= 128 else (0, 0, 0, 0)
            )
    return result


def measure_panel(panel: Image.Image) -> tuple[float, float, int]:
    gem_x, gem_y = find_gem_center(panel)
    alpha_box = panel.getchannel("A").point(
        lambda value: 255 if value >= 128 else 0
    ).getbbox()
    if alpha_box is None:
        raise ValueError("Walk pose has no visible pixels")
    return gem_x, gem_y, alpha_box[3] - 1


def normalize_panel(panel: Image.Image, scale: float) -> Image.Image:
    gem_x, _gem_y, source_footline = measure_panel(panel)

    resized = panel.resize(
        (round(panel.width * scale), round(panel.height * scale)),
        Image.Resampling.NEAREST,
    )
    resized_bbox = resized.getchannel("A").point(
        lambda value: 255 if value >= 128 else 0
    ).getbbox()
    if resized_bbox is None:
        raise ValueError("Resized walk pose is empty")
    destination_x = round(TARGET_GEM[0] - gem_x * scale)
    if destination_x + resized_bbox[0] < 1:
        destination_x += 1 - (destination_x + resized_bbox[0])
    if destination_x + resized_bbox[2] > FRAME_SIZE[0] - 1:
        destination_x -= destination_x + resized_bbox[2] - (FRAME_SIZE[0] - 1)
    destination = (
        destination_x,
        round(TARGET_FOOTLINE - source_footline * scale),
    )
    frame = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    frame.alpha_composite(resized, destination)
    frame = harden_alpha(frame)

    bbox = frame.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Normalized walk pose is empty")
    shift_y = TARGET_FOOTLINE - bbox[3]
    if shift_y:
        shifted = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        shifted.alpha_composite(frame, (0, shift_y))
        frame = shifted
    return frame


def main() -> None:
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    GIF_PATH.parent.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(SHEET_PATH).convert("RGBA")
    panels = [
        sheet.crop((left, 0, right, sheet.height))
        for left, right in find_character_runs(sheet)
    ]
    _first_gem_x, first_gem_y, first_footline = measure_panel(panels[0])
    fixed_scale = (
        (TARGET_FOOTLINE - TARGET_GEM[1])
        / (first_footline - first_gem_y)
        * SCALE_MULTIPLIER
    )
    frames = [normalize_panel(panel, fixed_scale) for panel in panels]

    expected_names = {f"frame_{index:03d}.png" for index in range(1, FRAME_COUNT + 1)}
    for stale_frame in FRAME_DIR.glob("frame_*.png"):
        if stale_frame.name not in expected_names:
            stale_frame.unlink()
            stale_import = stale_frame.with_suffix(stale_frame.suffix + ".import")
            if stale_import.exists():
                stale_import.unlink()

    for index, frame in enumerate(frames, start=1):
        frame.save(FRAME_DIR / f"frame_{index:03d}.png", optimize=False)

    strip = Image.new("RGBA", (FRAME_SIZE[0] * FRAME_COUNT, FRAME_SIZE[1]))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE[0], 0))
    strip.save(STRIP_PATH, optimize=False)

    previews = []
    for frame in frames:
        preview = Image.new("RGBA", FRAME_SIZE, PREVIEW_BACKGROUND)
        preview.alpha_composite(frame)
        previews.append(preview.convert("RGB"))
    previews[0].save(
        GIF_PATH,
        save_all=True,
        append_images=previews[1:],
        duration=list(FRAME_DURATION_MS),
        loop=0,
        disposal=2,
        optimize=False,
    )


if __name__ == "__main__":
    main()
