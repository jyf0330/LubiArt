from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = (
    ROOT
    / "output/sprite_animation_candidates/shadow_rock_wolf/preview_v2/move"
)
OUTPUT_DIR = (
    ROOT
    / "output/sprite_animation_candidates/shadow_rock_wolf/preview_v6/move"
)
STRIP_PATH = (
    ROOT
    / "output/sprite_animation_candidates/shadow_rock_wolf/"
    "shadow_rock_wolf_move_preview_v6.png"
)
GIF_PATH = ROOT / "output/shadow_rock_wolf_frame_move_preview_v6.gif"

# 用户确认的循环：1 -> 4 -> 2 -> 3。
# 直接复用 V2 原图完整帧，不拆头、不拼接、不重画。
FRAME_ORDER = (1, 4, 2, 3)
FRAME_DURATION_MS = 190
PREVIEW_BACKGROUND = (32, 32, 32, 255)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    GIF_PATH.parent.mkdir(parents=True, exist_ok=True)

    frames: list[Image.Image] = []
    for output_index, source_index in enumerate(FRAME_ORDER, start=1):
        source_path = SOURCE_DIR / f"frame_{source_index:03d}.png"
        frame = Image.open(source_path).convert("RGBA")
        if frame.size != (200, 200):
            raise ValueError(f"Unexpected frame size: {source_path} -> {frame.size}")

        output_path = OUTPUT_DIR / f"frame_{output_index:03d}.png"
        frame.save(output_path, optimize=False)
        frames.append(frame)

    strip = Image.new("RGBA", (200 * len(frames), 200), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * 200, 0))
    strip.save(STRIP_PATH, optimize=False)

    preview_frames: list[Image.Image] = []
    for frame in frames:
        preview = Image.new("RGBA", frame.size, PREVIEW_BACKGROUND)
        preview.alpha_composite(frame)
        preview_frames.append(preview.convert("RGB"))

    preview_frames[0].save(
        GIF_PATH,
        save_all=True,
        append_images=preview_frames[1:],
        duration=[FRAME_DURATION_MS] * len(preview_frames),
        loop=0,
        disposal=2,
        optimize=False,
    )


if __name__ == "__main__":
    main()
