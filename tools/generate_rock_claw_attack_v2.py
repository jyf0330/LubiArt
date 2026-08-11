from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ANIMATION_ROOT = ROOT / "output/sprite_animation_candidates/rock_claw"
NEUTRAL_PATH = ANIMATION_ROOT / "sources/rock_claw_neutral_v1.png"
FRAME_DIR = ANIMATION_ROOT / "preview_v2/attack"
STRIP_PATH = ANIMATION_ROOT / "rock_claw_attack_preview_v2.png"
GIF_PATH = ROOT / "output/rock_claw_frame_attack_preview_v2.gif"

CANVAS_SIZE = (200, 200)
PREVIEW_BACKGROUND = (32, 32, 32, 255)
FRAME_DURATION_MS = (300, 160, 300, 80, 190, 150, 320)

# Keep the arm's original silhouette and texture. Only the distal stone arm is
# separated; a broad shoulder root remains on the body so every translated pose
# visibly overlaps the shoulder instead of looking detached.
ARM_POLYGON = (
    (157, 91),
    (174, 96),
    (188, 113),
    (198, 134),
    (198, 157),
    (181, 164),
    (159, 155),
    (149, 139),
    (151, 116),
)


def load_neutral() -> Image.Image:
    neutral = Image.open(NEUTRAL_PATH).convert("RGBA")
    if neutral.size != CANVAS_SIZE:
        raise ValueError(f"Unexpected neutral frame size: {neutral.size}")
    return neutral


def split_throwing_arm(neutral: Image.Image) -> tuple[Image.Image, Image.Image]:
    mask = Image.new("L", CANVAS_SIZE, 0)
    ImageDraw.Draw(mask).polygon(ARM_POLYGON, fill=255)
    mask = ImageChops.multiply(mask, neutral.getchannel("A"))

    arm = neutral.copy()
    arm.putalpha(mask)

    body = neutral.copy()
    body.putalpha(
        ImageChops.multiply(neutral.getchannel("A"), ImageChops.invert(mask))
    )
    return body, arm


def translate_arm(
    body: Image.Image,
    arm: Image.Image,
    offset: tuple[int, int],
) -> Image.Image:
    dx, dy = offset
    moved_arm = arm.transform(
        CANVAS_SIZE,
        Image.Transform.AFFINE,
        (1, 0, -dx, 0, 1, -dy),
        resample=Image.Resampling.NEAREST,
    )
    result = body.copy()
    result.alpha_composite(moved_arm)
    return result


def main() -> None:
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    GIF_PATH.parent.mkdir(parents=True, exist_ok=True)

    neutral = load_neutral()
    body, arm = split_throwing_arm(neutral)
    frames = [
        neutral.copy(),
        translate_arm(body, arm, (1, -2)),
        translate_arm(body, arm, (2, -4)),
        translate_arm(body, arm, (-3, -1)),
        translate_arm(body, arm, (-9, 1)),
        translate_arm(body, arm, (-4, 1)),
        neutral.copy(),
    ]

    expected_names = {f"frame_{index:03d}.png" for index in range(1, len(frames) + 1)}
    for stale_frame in FRAME_DIR.glob("frame_*.png"):
        if stale_frame.name not in expected_names:
            stale_frame.unlink()
            stale_import = stale_frame.with_suffix(stale_frame.suffix + ".import")
            if stale_import.exists():
                stale_import.unlink()

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
