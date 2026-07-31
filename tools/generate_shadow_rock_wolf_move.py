from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SHEET_SOURCE = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/sources/shadow_rock_wolf_walk_sheet_transparent_v2.png"
FRAME_DIR = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/preview_v2/move"
STRIP_PATH = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/shadow_rock_wolf_move_preview_v2.png"
GIF_PATH = ROOT / "output/shadow_rock_wolf_frame_move_preview_v2.gif"

FRAME_SIZE = (200, 200)
FRAME_COUNT = 6
TARGET_GEM = (46, 50)
TARGET_FOOTLINE = 190


def find_gem_center(panel: Image.Image) -> tuple[float, float]:
    points: list[tuple[int, int]] = []
    pixels = panel.load()
    for y in range(120, min(300, panel.height)):
        for x in range(panel.width):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha > 128
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
            if alpha < 128:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)
    return result


def lock_footline(image: Image.Image) -> Image.Image:
    alpha_box = image.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("Normalized walk frame is empty")
    shift_y = TARGET_FOOTLINE - alpha_box[3]
    if shift_y == 0:
        return image
    canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(image, (0, shift_y))
    return canvas


def normalize_panel(panel: Image.Image) -> Image.Image:
    gem_x, gem_y = find_gem_center(panel)
    cleaned = panel.copy()
    alpha_box = cleaned.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("Walk frame is empty")
    foot_y = alpha_box[3] - 1

    # Lock both the forehead gem and the supporting footline. The tiny scale
    # correction compensates for inconsistent empty padding in the generated
    # key poses without introducing whole-body horizontal drift.
    scale = (TARGET_FOOTLINE - TARGET_GEM[1]) / (foot_y - gem_y)
    resized = cleaned.resize(
        (round(cleaned.width * scale), round(cleaned.height * scale)),
        Image.Resampling.NEAREST,
    )
    destination = (
        round(TARGET_GEM[0] - gem_x * scale),
        round(TARGET_GEM[1] - gem_y * scale),
    )
    canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(resized, destination)
    return lock_footline(harden_alpha(canvas))


def find_character_runs(sheet: Image.Image) -> list[tuple[int, int]]:
    alpha = sheet.getchannel("A")
    occupied = [
        alpha.crop((x, 0, x + 1, sheet.height)).getbbox() is not None
        for x in range(sheet.width)
    ]
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for x, has_pixel in enumerate(occupied + [False]):
        if has_pixel and start is None:
            start = x
        elif not has_pixel and start is not None:
            if x - start > 100:
                runs.append((start, x))
            start = None
    if len(runs) != FRAME_COUNT:
        raise ValueError(f"Expected {FRAME_COUNT} walk poses, found {len(runs)}")
    return runs


def build_frames(sheet: Image.Image) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for left, right in find_character_runs(sheet):
        panel = sheet.crop((left, 0, right, sheet.height))
        frames.append(normalize_panel(panel))
    return frames


def save_strip(frames: list[Image.Image]) -> None:
    strip = Image.new("RGBA", (FRAME_SIZE[0] * len(frames), FRAME_SIZE[1]), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE[0], 0))
    STRIP_PATH.parent.mkdir(parents=True, exist_ok=True)
    strip.save(STRIP_PATH)


def save_gif(frames: list[Image.Image]) -> None:
    preview_frames: list[Image.Image] = []
    for frame in frames:
        flattened = Image.new("RGBA", FRAME_SIZE, (43, 46, 52, 255))
        flattened.alpha_composite(frame)
        preview_frames.append(flattened.convert("RGB"))
    GIF_PATH.parent.mkdir(parents=True, exist_ok=True)
    preview_frames[0].save(
        GIF_PATH,
        save_all=True,
        append_images=preview_frames[1:],
        duration=[170, 160, 170, 170, 160, 170],
        loop=0,
        disposal=2,
        optimize=False,
    )


def main() -> None:
    sheet = Image.open(SHEET_SOURCE).convert("RGBA")
    frames = build_frames(sheet)
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames, start=1):
        frame.save(FRAME_DIR / f"frame_{index:03d}.png")
    save_strip(frames)
    save_gif(frames)


if __name__ == "__main__":
    main()
