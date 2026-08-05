from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ANIMATION_ROOT = ROOT / "art/images/shared/pets/animations/rock_claw"
NEUTRAL_PATH = ANIMATION_ROOT / "sources/rock_claw_neutral_v1.png"
FRAME_DIR = ANIMATION_ROOT / "preview_v1/attack"
STRIP_PATH = ANIMATION_ROOT / "rock_claw_attack_preview_v1.png"
GIF_PATH = ROOT / "output/rock_claw_frame_attack_preview_v1.gif"

CANVAS_SIZE = (200, 200)
PREVIEW_BACKGROUND = (32, 32, 32, 255)
FRAME_DURATION_MS = (300, 150, 280, 80, 180, 140, 320)

# Image-right arm. The shoulder stays on the body while the stone forearm and fist
# travel through a readable wind-up -> throw -> follow-through arc.
ARM_POLYGON = (
    (153, 91),
    (173, 96),
    (188, 113),
    (198, 134),
    (198, 157),
    (181, 164),
    (159, 155),
    (145, 138),
    (146, 113),
)
ARM_PIVOT = (147, 126)


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
    inverse_mask = ImageChops.invert(mask)
    body.putalpha(ImageChops.multiply(neutral.getchannel("A"), inverse_mask))
    return body, arm


def pose_arm(
    body: Image.Image,
    arm: Image.Image,
    *,
    angle: float,
    translate: tuple[int, int],
) -> Image.Image:
    transformed = arm.rotate(
        angle,
        resample=Image.Resampling.NEAREST,
        center=ARM_PIVOT,
        translate=translate,
        expand=False,
    )
    result = body.copy()
    result.alpha_composite(transformed)
    return result


def main() -> None:
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    GIF_PATH.parent.mkdir(parents=True, exist_ok=True)

    neutral = load_neutral()
    body, arm = split_throwing_arm(neutral)

    frames = [
        neutral.copy(),
        pose_arm(body, arm, angle=10, translate=(0, -1)),
        pose_arm(body, arm, angle=20, translate=(-2, -3)),
        pose_arm(body, arm, angle=-6, translate=(-2, 1)),
        pose_arm(body, arm, angle=-27, translate=(-8, 5)),
        pose_arm(body, arm, angle=-14, translate=(-4, 3)),
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

    preview_frames = []
    for frame in frames:
        preview = Image.new("RGBA", CANVAS_SIZE, PREVIEW_BACKGROUND)
        preview.alpha_composite(frame)
        preview_frames.append(preview.convert("RGB"))
    preview_frames[0].save(
        GIF_PATH,
        save_all=True,
        append_images=preview_frames[1:],
        duration=list(FRAME_DURATION_MS),
        loop=0,
        disposal=2,
        optimize=False,
    )


if __name__ == "__main__":
    main()
