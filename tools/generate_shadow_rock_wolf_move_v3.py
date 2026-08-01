from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
APPROVED_CLOSED_FRAME = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/sources/shadow_rock_wolf_closed_neutral_v1.png"
V2_FRAME_DIR = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/preview_v2/move"
FRAME_DIR = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/preview_v4/move"
STRIP_PATH = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/shadow_rock_wolf_move_preview_v4.png"
GIF_PATH = ROOT / "output/shadow_rock_wolf_frame_move_preview_v4.gif"

FRAME_SIZE = (200, 200)
SOURCE_ORDER = [1, 4, 2, 3]
HEAD_SCALE = 0.88
GEM_TO_COLLAR_Y = 57


def make_approved_head_layer(frame: Image.Image) -> Image.Image:
    layer = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    source = frame.load()
    target = layer.load()
    for y in range(10, 109):
        for x in range(58, 189):
            red, green, blue, alpha = source[x, y]
            if not alpha:
                continue
            source_y = y - 10
            if source_y <= 88:
                target[x, y] = source[x, y]
            elif source_y <= 98:
                # Keep the grayscale chin but leave the gold collar behind.
                if max(red, green, blue) - min(red, green, blue) <= 58 or max(red, green, blue) < 72:
                    target[x, y] = source[x, y]
    return layer


def find_gem_center(image: Image.Image) -> tuple[float, float]:
    points: list[tuple[int, int]] = []
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = image.getpixel((x, y))
            if (
                alpha > 128
                and blue > 130
                and green > 80
                and blue > red * 1.35
                and green > red * 1.2
            ):
                points.append((x, y))
    if not points:
        raise ValueError("Could not find gem in approved head")
    return (
        sum(point[0] for point in points) / len(points),
        sum(point[1] for point in points) / len(points),
    )


def prepare_approved_head(frame: Image.Image) -> tuple[Image.Image, tuple[int, int]]:
    layer = make_approved_head_layer(frame)
    box = layer.getchannel("A").getbbox()
    if box is None:
        raise ValueError("Approved head layer is empty")
    gem_x, gem_y = find_gem_center(layer)
    crop = layer.crop(box)
    resized = crop.resize(
        (round(crop.width * HEAD_SCALE), round(crop.height * HEAD_SCALE)),
        Image.Resampling.NEAREST,
    )
    gem_relative = (
        round((gem_x - box[0]) * HEAD_SCALE),
        round((gem_y - box[1]) * HEAD_SCALE),
    )
    return resized, gem_relative


def find_collar_center(frame: Image.Image) -> tuple[int, int]:
    points: list[tuple[int, int]] = []
    for y in range(104, 136):
        for x in range(0, 130):
            red, green, blue, alpha = frame.getpixel((x, y))
            if (
                alpha
                and red > 135
                and green > 65
                and blue < 115
                and green > blue * 1.25
                and red / green < 2.8
            ):
                points.append((x, y))
    if not points:
        raise ValueError("Could not locate the gold collar")
    return (
        round(sum(point[0] for point in points) / len(points)),
        round(sum(point[1] for point in points) / len(points)),
    )


def remove_generated_head(frame: Image.Image) -> Image.Image:
    body = frame.copy()
    pixels = body.load()
    for y in range(0, 111):
        for x in range(0, 126):
            red, green, blue, alpha = pixels[x, y]
            if not alpha:
                continue
            if y <= 96:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                chroma = max(red, green, blue) - min(red, green, blue)
                # Remove the remaining gray/white chin and its dark outline,
                # while preserving the saturated gold collar and red clothing.
                if chroma <= 62 or max(red, green, blue) < 72:
                    pixels[x, y] = (0, 0, 0, 0)
    return body


def compose_frame(
    source_frame: Image.Image,
    approved_head: Image.Image,
    gem_relative: tuple[int, int],
) -> Image.Image:
    collar_x, collar_y = find_collar_center(source_frame)
    target_gem = (collar_x + 2, collar_y - GEM_TO_COLLAR_Y)
    head_destination = (
        target_gem[0] - gem_relative[0],
        target_gem[1] - gem_relative[1],
    )
    frame = remove_generated_head(source_frame)
    frame.alpha_composite(approved_head, head_destination)
    return frame


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
        duration=[190, 190, 190, 190],
        loop=0,
        disposal=2,
        optimize=False,
    )


def main() -> None:
    approved_frame = Image.open(APPROVED_CLOSED_FRAME).convert("RGBA")
    approved_head, gem_relative = prepare_approved_head(approved_frame)

    source_frames = {
        index: Image.open(V2_FRAME_DIR / f"frame_{index:03d}.png").convert("RGBA")
        for index in SOURCE_ORDER
    }
    frames = [
        compose_frame(source_frames[index], approved_head, gem_relative)
        for index in SOURCE_ORDER
    ]

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames, start=1):
        frame.save(FRAME_DIR / f"frame_{index:03d}.png")
    save_strip(frames)
    save_gif(frames)


if __name__ == "__main__":
    main()
