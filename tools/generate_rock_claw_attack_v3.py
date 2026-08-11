from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ANIMATION_ROOT = ROOT / "output/sprite_animation_candidates/rock_claw"
NEUTRAL_PATH = ANIMATION_ROOT / "sources/rock_claw_neutral_v1.png"
SHEET_PATH = ANIMATION_ROOT / "sources/rock_claw_attack_sheet_transparent_v3.png"
FRAME_DIR = ANIMATION_ROOT / "preview_v3/attack"
STRIP_PATH = ANIMATION_ROOT / "rock_claw_attack_preview_v3.png"
GIF_PATH = ROOT / "output/rock_claw_frame_attack_preview_v3.gif"

CANVAS_SIZE = (200, 200)
CELL_WIDTH = 310
CELL_HEIGHT = 257
FIRST_CELL_CENTER_X = 170
CELL_CENTER_STEP_X = 305
SOURCE_TOP = 236
NORMALIZED_CELL_HEIGHT = 166
FOOTLINE_Y = 192
FRAME_DURATION_MS = (280, 120, 180, 320, 90, 190, 160, 140, 320)
PREVIEW_BACKGROUND = (32, 32, 32, 255)
SOURCE_RUNS = (
    (23, 316),
    (354, 601),
    (675, 896),
    (973, 1207),
    (1283, 1541),
    (1596, 1795),
    (1854, 2145),
)


def load_neutral() -> Image.Image:
    neutral = Image.open(NEUTRAL_PATH).convert("RGBA")
    if neutral.size != CANVAS_SIZE:
        raise ValueError(f"Unexpected neutral size: {neutral.size}")
    return neutral


def extract_generated_pose(sheet: Image.Image, index: int) -> Image.Image:
    center_x = FIRST_CELL_CENTER_X + index * CELL_CENTER_STEP_X
    left = center_x - CELL_WIDTH // 2
    cell = sheet.crop((left, SOURCE_TOP, left + CELL_WIDTH, SOURCE_TOP + CELL_HEIGHT))
    run_left, run_right = SOURCE_RUNS[index]
    local_left = max(0, run_left - left)
    local_right = min(CELL_WIDTH, run_right - left)
    source_alpha = cell.getchannel("A")
    isolated_alpha = Image.new("L", cell.size, 0)
    isolated_alpha.paste(
        source_alpha.crop((local_left, 0, local_right, CELL_HEIGHT)),
        (local_left, 0),
    )
    cell.putalpha(isolated_alpha)
    cell = cell.resize(
        (CANVAS_SIZE[0], NORMALIZED_CELL_HEIGHT), Image.Resampling.NEAREST
    )

    alpha = cell.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    cell.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"Generated pose {index} has no visible pixels")

    frame = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    frame.alpha_composite(cell, (0, FOOTLINE_Y - bbox[3]))
    return frame


def main() -> None:
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    GIF_PATH.parent.mkdir(parents=True, exist_ok=True)

    neutral = load_neutral()
    sheet = Image.open(SHEET_PATH).convert("RGBA")
    if sheet.size != (2172, 724):
        raise ValueError(f"Unexpected generated sheet size: {sheet.size}")

    # The generated key poses provide the full-body weight transfer. The approved
    # mother frame is restored exactly at both ends to lock identity and looping.
    frames = [neutral.copy()]
    frames.extend(extract_generated_pose(sheet, index) for index in range(7))
    frames.append(neutral.copy())

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
