from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = (
    ROOT / "art/images/shared/pets/sheets/slices/pet_style_007_rock_claw.png"
)
ANIMATION_ROOT = ROOT / "output/sprite_animation_candidates/rock_claw"
SOURCE_OUTPUT = ANIMATION_ROOT / "sources/rock_claw_neutral_v1.png"
CLOSED_SOURCE_PATH = ANIMATION_ROOT / "sources/rock_claw_closed_user_v1.png"
FRAME_DIR = ANIMATION_ROOT / "preview_v1/idle"
STRIP_PATH = ANIMATION_ROOT / "rock_claw_idle_preview_v1.png"
GIF_PATH = ROOT / "output/rock_claw_frame_idle_preview_v1.gif"

CANVAS_SIZE = (200, 200)
TARGET_WIDTH = 190
FOOTLINE_Y = 192
FRAME_DURATION_MS = (520, 320, 940, 100, 260, 100, 520)
PREVIEW_BACKGROUND = (32, 32, 32, 255)


def normalize_source() -> Image.Image:
    source = Image.open(SOURCE_PATH).convert("RGBA")
    alpha_bbox = source.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise ValueError("Rock claw source has no visible pixels")
    source = source.crop(alpha_bbox)

    target_height = round(source.height * TARGET_WIDTH / source.width)
    sprite = source.resize((TARGET_WIDTH, target_height), Image.Resampling.NEAREST)

    # The project uses hard-edged pixel frames. Remove the source's few partial-alpha
    # edge pixels without changing any opaque character pixels.
    alpha = sprite.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    sprite.putalpha(alpha)

    frame = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    x = (CANVAS_SIZE[0] - sprite.width) // 2
    y = FOOTLINE_Y - sprite.height
    frame.alpha_composite(sprite, (x, y))
    return frame


def breathe_up(frame: Image.Image) -> Image.Image:
    """Lift only the upper mass by one pixel while keeping both feet anchored."""
    result = frame.copy()
    pixels = frame.load()
    output = result.load()
    transition_y = 158
    for y in range(0, transition_y):
        for x in range(CANVAS_SIZE[0]):
            output[x, y] = pixels[x, y + 1]
    return result


SKIN_COLOR = (190, 176, 175, 255)
EYELID_COLOR = (18, 16, 15, 255)


def blink_half(frame: Image.Image) -> Image.Image:
    result = frame.copy()
    draw = ImageDraw.Draw(result)
    draw.polygon(((64, 133), (85, 138), (84, 144), (78, 146), (69, 141)), fill=SKIN_COLOR)
    draw.polygon(((136, 133), (115, 138), (116, 144), (122, 146), (131, 141)), fill=SKIN_COLOR)
    draw.line(((65, 132), (84, 139)), fill=EYELID_COLOR, width=2)
    draw.line(((135, 132), (116, 139)), fill=EYELID_COLOR, width=2)
    return result


def load_user_closed_frame(neutral: Image.Image) -> Image.Image:
    closed = Image.open(CLOSED_SOURCE_PATH).convert("RGBA")
    if closed.size != CANVAS_SIZE:
        raise ValueError(f"Unexpected user closed-frame size: {closed.size}")
    if closed.getchannel("A").getbbox() != neutral.getchannel("A").getbbox():
        raise ValueError("User closed frame does not share the neutral frame anchor")
    return closed


def main() -> None:
    SOURCE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    GIF_PATH.parent.mkdir(parents=True, exist_ok=True)

    expected_frame_names = {
        f"frame_{index:03d}.png" for index in range(1, len(FRAME_DURATION_MS) + 1)
    }
    for stale_frame in FRAME_DIR.glob("frame_*.png"):
        if stale_frame.name not in expected_frame_names:
            stale_frame.unlink()
            stale_import = stale_frame.with_suffix(stale_frame.suffix + ".import")
            if stale_import.exists():
                stale_import.unlink()

    for qa_name in ("rock_claw_neutral_v1_qa.png", "rock_claw_idle_preview_v1_qa.png"):
        qa_path = ROOT / "output" / qa_name
        if qa_path.exists():
            qa_path.unlink()

    neutral = normalize_source()
    neutral.save(SOURCE_OUTPUT, optimize=False)
    closed = load_user_closed_frame(neutral)

    frames = [
        neutral.copy(),
        breathe_up(neutral),
        neutral.copy(),
        blink_half(neutral),
        closed,
        blink_half(neutral),
        neutral.copy(),
    ]

    for index, frame in enumerate(frames, start=1):
        frame.save(FRAME_DIR / f"frame_{index:03d}.png", optimize=False)

    strip = Image.new("RGBA", (CANVAS_SIZE[0] * len(frames), CANVAS_SIZE[1]))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * CANVAS_SIZE[0], 0))
    strip.save(STRIP_PATH, optimize=False)

    previews = []
    for frame in frames:
        preview = Image.new("RGBA", CANVAS_SIZE, PREVIEW_BACKGROUND)
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
