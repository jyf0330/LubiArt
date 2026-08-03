from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "output/shadow_rock_wolf_walk_v10"
SOURCE_PATH = OUTPUT_ROOT / "source/shadow_rock_wolf_walk_sheet_transparent_v10.png"
FRAME_DIR = OUTPUT_ROOT / "frames"
OVERVIEW_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_overview_v10.png"
GIF_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_preview_v10.gif"

FRAME_SIZE = (200, 200)
GRID_SIZE = (4, 2)
FRAME_COUNT = GRID_SIZE[0] * GRID_SIZE[1]
TARGET_GEM_X: int | None = None
TARGET_FOOTLINE = 190
TARGET_MAX_WIDTH = 190
TARGET_MAX_HEIGHT = 180
FRAME_DURATION_MS = 125
PREVIEW_BACKGROUND = (43, 46, 52, 255)
STABILIZE_ABOVE_Y: int | None = None


def harden_alpha(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha >= 128:
                pixels[x, y] = (red, green, blue, 255)
            else:
                pixels[x, y] = (0, 0, 0, 0)
    return result


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


def split_panels(sheet: Image.Image) -> list[Image.Image]:
    panels: list[Image.Image] = []
    for row in range(GRID_SIZE[1]):
        for column in range(GRID_SIZE[0]):
            left = round(column * sheet.width / GRID_SIZE[0])
            top = round(row * sheet.height / GRID_SIZE[1])
            right = round((column + 1) * sheet.width / GRID_SIZE[0])
            bottom = round((row + 1) * sheet.height / GRID_SIZE[1])
            panel = harden_alpha(
                sheet.crop((left, top, right, bottom))
            )
            # A neighboring pose overlaps the final few pixels of one generated
            # cell. All eight intended poses finish before this protected gutter.
            panel.paste(
                (0, 0, 0, 0),
                (panel.width - 16, 0, panel.width, panel.height),
            )
            panels.append(panel)
    return panels


def content_box(image: Image.Image) -> tuple[int, int, int, int]:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise ValueError("A walk pose is empty")
    return box


def normalize_panel(panel: Image.Image, scale: float) -> Image.Image:
    box = content_box(panel)
    gem_x, _gem_y = find_gem_center(panel)
    resized = panel.resize(
        (round(panel.width * scale), round(panel.height * scale)),
        Image.Resampling.NEAREST,
    )
    resized_box = content_box(resized)
    if TARGET_GEM_X is None:
        destination_x = round(
            (FRAME_SIZE[0] - (resized_box[2] - resized_box[0])) / 2
        )
        destination_x -= resized_box[0]
    else:
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

    normalized_box = content_box(frame)
    if normalized_box[3] != TARGET_FOOTLINE:
        raise ValueError("Foot baseline normalization failed")
    return frame


def main() -> None:
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SOURCE_PATH).convert("RGBA")
    panels = split_panels(sheet)
    if len(panels) != FRAME_COUNT:
        raise ValueError(f"Expected {FRAME_COUNT} frames, found {len(panels)}")

    boxes = [content_box(panel) for panel in panels]
    max_width = max(box[2] - box[0] for box in boxes)
    max_height = max(box[3] - box[1] for box in boxes)
    fixed_scale = min(TARGET_MAX_WIDTH / max_width, TARGET_MAX_HEIGHT / max_height)
    frames = [normalize_panel(panel, fixed_scale) for panel in panels]

    if STABILIZE_ABOVE_Y is not None:
        stable_upper = frames[0].crop((0, 0, FRAME_SIZE[0], STABILIZE_ABOVE_Y))
        for frame in frames[1:]:
            frame.paste(
                (0, 0, 0, 0),
                (0, 0, FRAME_SIZE[0], STABILIZE_ABOVE_Y),
            )
            frame.alpha_composite(stable_upper, (0, 0))

    for index, frame in enumerate(frames, start=1):
        frame.save(FRAME_DIR / f"frame_{index:03d}.png", optimize=False)

    overview = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * GRID_SIZE[0], FRAME_SIZE[1] * GRID_SIZE[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        x = (index % GRID_SIZE[0]) * FRAME_SIZE[0]
        y = (index // GRID_SIZE[0]) * FRAME_SIZE[1]
        overview.alpha_composite(frame, (x, y))
    overview.save(OVERVIEW_PATH, optimize=False)

    previews: list[Image.Image] = []
    for frame in frames:
        preview = Image.new("RGBA", FRAME_SIZE, PREVIEW_BACKGROUND)
        preview.alpha_composite(frame)
        previews.append(preview.convert("RGB"))
    previews[0].save(
        GIF_PATH,
        save_all=True,
        append_images=previews[1:],
        duration=[FRAME_DURATION_MS] * FRAME_COUNT,
        loop=0,
        disposal=2,
        optimize=False,
    )


if __name__ == "__main__":
    main()
