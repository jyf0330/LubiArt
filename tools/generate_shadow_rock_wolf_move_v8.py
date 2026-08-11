from pathlib import Path

import generate_shadow_rock_wolf_move_v7 as generator


ROOT = Path(__file__).resolve().parents[1]
ANIMATION_ROOT = ROOT / "output/sprite_animation_candidates/shadow_rock_wolf"

generator.SHEET_PATH = (
    ANIMATION_ROOT / "sources/shadow_rock_wolf_walk_sheet_transparent_v8.png"
)
generator.FRAME_DIR = ANIMATION_ROOT / "preview_v8/move"
generator.STRIP_PATH = ANIMATION_ROOT / "shadow_rock_wolf_move_preview_v8.png"
generator.GIF_PATH = ROOT / "output/shadow_rock_wolf_frame_move_preview_v8.gif"
generator.TARGET_GEM = (44, 50)
generator.SCALE_MULTIPLIER = 0.975


if __name__ == "__main__":
    generator.main()
