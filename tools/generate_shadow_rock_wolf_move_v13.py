from pathlib import Path
import hashlib
import json

import generate_shadow_rock_wolf_move_v12 as base
from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "output/shadow_rock_wolf_walk_v13"

base.OUTPUT_ROOT = OUTPUT_ROOT
base.SOURCE_PATH = (
    OUTPUT_ROOT / "source/shadow_rock_wolf_walk_sheet_transparent_v13.png"
)
base.FRAME_DIR = OUTPUT_ROOT / "frames"
base.OVERVIEW_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_overview_v13.png"
base.OVERVIEW_4X_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_overview_4x_v13.png"
base.GIF_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_preview_v13.gif"
base.SLOW_GIF_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_slow_check_v13.gif"
base.REPORT_PATH = OUTPUT_ROOT / "shadow_rock_wolf_walk_qa_v13.json"
base.TARGET_MAX_WIDTH = 180


_split_whole_frames = base.split_whole_frames


def keep_largest_opaque_component(image):
    result = image.copy()
    alpha = result.getchannel("A")
    remaining = {
        (x, y)
        for y in range(result.height)
        for x in range(result.width)
        if alpha.getpixel((x, y)) >= 128
    }
    components = []
    while remaining:
        seed = remaining.pop()
        component = [seed]
        stack = [seed]
        while stack:
            x, y = stack.pop()
            for neighbor_y in range(max(0, y - 1), min(result.height, y + 2)):
                for neighbor_x in range(max(0, x - 1), min(result.width, x + 2)):
                    neighbor = (neighbor_x, neighbor_y)
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        component.append(neighbor)
                        stack.append(neighbor)
        components.append(component)
    if not components:
        raise ValueError("A walk pose is empty")
    largest = set(max(components, key=len))
    for y in range(result.height):
        for x in range(result.width):
            if alpha.getpixel((x, y)) >= 128 and (x, y) not in largest:
                result.putpixel((x, y), (0, 0, 0, 0))
    return result


def split_clean_whole_frames(sheet):
    return [keep_largest_opaque_component(frame) for frame in _split_whole_frames(sheet)]


base.split_whole_frames = split_clean_whole_frames


def augment_qa_report():
    frame_paths = sorted(base.FRAME_DIR.glob("frame_*.png"))
    frames = [Image.open(path).convert("RGBA") for path in frame_paths]
    hashes = [hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames]
    consecutive_difference_boxes = [
        ImageChops.difference(frames[index], frames[(index + 1) % len(frames)]).getbbox()
        for index in range(len(frames))
    ]
    gem_centers = [base.find_gem_center(frame) for frame in frames]
    report = json.loads(base.REPORT_PATH.read_text(encoding="utf-8"))
    report["motion_cycle"] = {
        "unique_frame_count": len(set(hashes)),
        "expected_unique_frame_count": len(frames),
        "all_neighbor_transitions_have_pixel_changes": all(
            box is not None for box in consecutive_difference_boxes
        ),
        "neighbor_difference_boxes": [
            list(box) if box is not None else None
            for box in consecutive_difference_boxes
        ],
        "gem_centers": [[round(x, 3), round(y, 3)] for x, y in gem_centers],
        "gem_x_span": round(
            max(center[0] for center in gem_centers)
            - min(center[0] for center in gem_centers),
            3,
        ),
    }
    report["motion_cycle"]["passed"] = (
        report["motion_cycle"]["unique_frame_count"] == len(frames)
        and report["motion_cycle"]["all_neighbor_transitions_have_pixel_changes"]
        and report["motion_cycle"]["gem_x_span"] <= 2.0
    )
    report["passed"] = report["passed"] and report["motion_cycle"]["passed"]
    base.REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    if not report["passed"]:
        raise ValueError(f"Extended QA failed; see {base.REPORT_PATH}")


if __name__ == "__main__":
    base.main()
    augment_qa_report()
