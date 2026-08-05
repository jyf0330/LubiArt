from pathlib import Path

import generate_shadow_rock_wolf_move_v10 as generator


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "output/shadow_rock_wolf_walk_v11"

generator.OUTPUT_ROOT = OUTPUT_ROOT
generator.SOURCE_PATH = (
    OUTPUT_ROOT / "source/shadow_rock_wolf_walk_sheet_transparent_v11.png"
)
generator.FRAME_DIR = OUTPUT_ROOT / "frames"
generator.OVERVIEW_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_overview_v11.png"
generator.GIF_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_preview_v11.gif"
generator.GRID_SIZE = (4, 3)
generator.FRAME_COUNT = 12
generator.FRAME_DURATION_MS = 80
generator.TARGET_GEM_X = 148
generator.STABILIZE_ABOVE_Y = 150


if __name__ == "__main__":
    generator.main()
