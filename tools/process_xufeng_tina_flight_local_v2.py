from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
PARENT_SCRIPT = ROOT / "tools/process_xufeng_tina_flight_rika_v1.py"
spec = importlib.util.spec_from_file_location("xufeng_tina_flight_v1", PARENT_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load parent processor: {PARENT_SCRIPT}")
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)

PARENT_ROOT = ROOT / "art/images/shared/pets/animations/xufeng_tina/flight_v1"
PARENT_MANIFEST_ROOT = ROOT / "art/manifests/shared/pets/animations/xufeng_tina/flight_v1"
VERSION_ROOT = ROOT / "art/images/shared/pets/animations/xufeng_tina/flight_v2"
MANIFEST_ROOT = ROOT / "art/manifests/shared/pets/animations/xufeng_tina/flight_v2"
SOURCE_DIR = VERSION_ROOT / "source"
FRAME_DIR = VERSION_ROOT / "frames"
ZOOM_FRAME_DIR = VERSION_ROOT / "frames_4x"
PROCESSOR_OUTPUT_DIR = VERSION_ROOT / "processor_qc"

PARENT_FRAME_DIR = PARENT_ROOT / "frames"
PARENT_PROMPT_PATH = PARENT_ROOT / "source/prompt-used.txt"
MASK_PATH = SOURCE_DIR / "xufeng_tina_eye_lock_mask_v2.png"
PROCESSOR_INPUT_PATH = SOURCE_DIR / "xufeng_tina_flight_magenta_v2.png"
SHEET_PATH = VERSION_ROOT / "xufeng_tina_flight_sheet_v2.png"
OVERVIEW_PATH = VERSION_ROOT / "xufeng_tina_flight_overview_v2.png"
ZOOM_OVERVIEW_PATH = VERSION_ROOT / "xufeng_tina_flight_overview_4x_v2.png"
GIF_PATH = VERSION_ROOT / "xufeng_tina_flight_preview_v2.gif"
SLOW_GIF_PATH = VERSION_ROOT / "xufeng_tina_flight_slow_check_v2.gif"
QA_REPORT_PATH = MANIFEST_ROOT / "qa_report.json"

SKILL_PROCESSOR = (
    Path.home() / ".codex/skills/generate2dsprite/scripts/generate2dsprite.py"
)
FRAME_SIZE = (128, 128)
FRAME_COUNT = 16
GRID_SIZE = (4, 4)
PREVIEW_BACKGROUND = (28, 30, 36)
FRAME_DURATION_MS = 120
SLOW_FRAME_DURATION_MS = 420
LEFT_EYE_REGION = (55, 53, 66, 62)
RIGHT_EYE_REGION = (68, 52, 78, 61)


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_parent_frames() -> list[Image.Image]:
    paths = sorted(PARENT_FRAME_DIR.glob("frame_*.png"))
    if len(paths) != FRAME_COUNT:
        raise ValueError(f"Expected {FRAME_COUNT} parent frames, found {len(paths)}")
    return [Image.open(path).convert("RGBA") for path in paths]


def is_inside_region(x: int, y: int, region: tuple[int, int, int, int]) -> bool:
    return region[0] <= x < region[2] and region[1] <= y < region[3]


def build_eye_contour_mask(reference: Image.Image) -> tuple[Image.Image, list[tuple[int, int]]]:
    mask = Image.new("L", FRAME_SIZE, 0)
    mask_pixels = mask.load()
    reference_pixels = reference.load()
    points: list[tuple[int, int]] = []
    for y in range(FRAME_SIZE[1]):
        for x in range(FRAME_SIZE[0]):
            if not (
                is_inside_region(x, y, LEFT_EYE_REGION)
                or is_inside_region(x, y, RIGHT_EYE_REGION)
            ):
                continue
            red, green, blue, alpha = reference_pixels[x, y]
            if not alpha:
                continue
            is_face_skin = red >= 220 and green >= 150 and blue >= 150
            is_closed_eye = 120 <= red <= 180 and green <= 110 and blue <= 125
            if is_face_skin or is_closed_eye:
                mask_pixels[x, y] = 255
                points.append((x, y))
    if not points:
        raise ValueError("Eye contour mask is empty")
    return mask, points


def pink_head_top(frame: Image.Image) -> int:
    ys: list[int] = []
    for y in range(20, 76):
        for x in range(36, 92):
            red, green, blue, alpha = frame.getpixel((x, y))
            if (
                alpha
                and red >= 180
                and blue >= 100
                and green <= 175
                and red >= blue + 30
            ):
                ys.append(y)
    if not ys:
        raise ValueError("Could not locate the pink head mass")
    return min(ys)


def lock_eye_contour(
    frame: Image.Image,
    reference: Image.Image,
    contour_points: list[tuple[int, int]],
    head_y_offset: int,
) -> tuple[Image.Image, set[tuple[int, int]]]:
    output = frame.copy()
    output_pixels = output.load()
    reference_pixels = reference.load()
    target_points: set[tuple[int, int]] = set()
    for source_x, source_y in contour_points:
        target_x = source_x
        target_y = source_y + head_y_offset
        if not (0 <= target_x < FRAME_SIZE[0] and 0 <= target_y < FRAME_SIZE[1]):
            raise ValueError("Shifted eye contour left the frame")
        output_pixels[target_x, target_y] = reference_pixels[source_x, source_y]
        target_points.add((target_x, target_y))
    return output, target_points


def compose_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(
            frame,
            ((index % GRID_SIZE[0]) * 128, (index // GRID_SIZE[0]) * 128),
        )
    return sheet


def compose_preview(frame: Image.Image) -> Image.Image:
    preview = Image.new("RGB", FRAME_SIZE, PREVIEW_BACKGROUND)
    preview.paste(frame.convert("RGB"), mask=frame.getchannel("A"))
    return preview


def exact_palette_frames(previews: list[Image.Image]) -> tuple[list[Image.Image], int]:
    colors = sorted({color for frame in previews for color in frame.get_flattened_data()})
    if len(colors) > 256:
        raise ValueError(f"GIF source has {len(colors)} colors; exact GIF needs at most 256")
    color_to_index = {color: index for index, color in enumerate(colors)}
    palette = [channel for color in colors for channel in color]
    palette.extend([0] * (768 - len(palette)))
    indexed_frames: list[Image.Image] = []
    for preview in previews:
        indexed = Image.new("P", preview.size)
        indexed.putpalette(palette)
        indexed.putdata([color_to_index[color] for color in preview.get_flattened_data()])
        indexed_frames.append(indexed)
    return indexed_frames, len(colors)


def write_verified_gif(previews: list[Image.Image], path: Path, duration_ms: int) -> dict:
    indexed, palette_color_count = exact_palette_frames(previews)
    path.parent.mkdir(parents=True, exist_ok=True)
    indexed[0].save(
        path,
        save_all=True,
        append_images=indexed[1:],
        duration=[duration_ms] * len(indexed),
        loop=0,
        disposal=2,
        optimize=False,
    )
    decoded = Image.open(path)
    decoded_frames = [frame.convert("RGB") for frame in ImageSequence.Iterator(decoded)]
    durations: list[int] = []
    disposal_methods: list[int | None] = []
    for index in range(decoded.n_frames):
        decoded.seek(index)
        durations.append(int(decoded.info.get("duration", 0)))
        disposal_methods.append(getattr(decoded, "disposal_method", None))
    exact_matches = [
        ImageChops.difference(decoded_frame, source).getbbox() is None
        for decoded_frame, source in zip(decoded_frames, previews, strict=True)
    ]
    passed = (
        len(decoded_frames) == len(previews)
        and all(exact_matches)
        and durations == [duration_ms] * len(previews)
        and all(method == 2 for method in disposal_methods)
    )
    if not passed:
        raise ValueError(f"GIF verification failed: {path}")
    return {
        "path": relative(path),
        "frame_count": len(decoded_frames),
        "durations_ms": durations,
        "disposal_methods": disposal_methods,
        "palette_color_count": palette_color_count,
        "source_preview_pixel_exact": exact_matches,
        "passed": passed,
    }


def make_processor_input(sheet: Image.Image) -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    solid = Image.new("RGB", sheet.size, (255, 0, 255))
    solid.paste(sheet.convert("RGB"), mask=sheet.getchannel("A"))
    solid.save(PROCESSOR_INPUT_PATH, optimize=False)


def run_skill_processor() -> None:
    command = [
        sys.executable,
        str(SKILL_PROCESSOR),
        "process",
        "--input",
        str(PROCESSOR_INPUT_PATH),
        "--target",
        "npc",
        "--mode",
        "hover",
        "--output-dir",
        str(PROCESSOR_OUTPUT_DIR),
        "--rows",
        "4",
        "--cols",
        "4",
        "--cell-size",
        "128",
        "--label-prefix",
        "frame",
        "--prompt-file",
        str(PARENT_PROMPT_PATH),
        "--fit-scale",
        "0.92",
        "--trim-border",
        "0",
        "--edge-clean-depth",
        "0",
        "--align",
        "center",
        "--shared-scale",
        "--scale-strategy",
        "preserve",
        "--component-mode",
        "all",
        "--component-padding",
        "1",
        "--strict-qc",
        "--duration",
        str(FRAME_DURATION_MS),
    ]
    subprocess.run(command, cwd=ROOT, check=True)


def changed_points(left: Image.Image, right: Image.Image) -> set[tuple[int, int]]:
    points: set[tuple[int, int]] = set()
    left_pixels = left.load()
    right_pixels = right.load()
    for y in range(FRAME_SIZE[1]):
        for x in range(FRAME_SIZE[0]):
            if left_pixels[x, y] != right_pixels[x, y]:
                points.add((x, y))
    return points


def edge_touch_frames(frames: list[Image.Image]) -> list[int]:
    result: list[int] = []
    for index, frame in enumerate(frames, start=1):
        box = frame.getchannel("A").getbbox()
        if box is None:
            continue
        if box[0] == 0 or box[1] == 0 or box[2] == 128 or box[3] == 128:
            result.append(index)
    return result


def main() -> None:
    parent_frames = load_parent_frames()
    reference = parent_frames[0]
    contour_mask, contour_points = build_eye_contour_mask(reference)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    contour_mask.save(MASK_PATH, optimize=False)

    reference_head_top = pink_head_top(reference)
    head_y_offsets = [pink_head_top(frame) - reference_head_top for frame in parent_frames]
    frames: list[Image.Image] = []
    target_point_sets: list[set[tuple[int, int]]] = []
    for frame, head_y_offset in zip(parent_frames, head_y_offsets, strict=True):
        locked, target_points = lock_eye_contour(
            frame, reference, contour_points, head_y_offset
        )
        frames.append(locked)
        target_point_sets.append(target_points)

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    ZOOM_FRAME_DIR.mkdir(parents=True, exist_ok=True)
    frame_paths: list[Path] = []
    zoom_frame_paths: list[Path] = []
    for index, frame in enumerate(frames, start=1):
        frame_path = FRAME_DIR / f"frame_{index:03d}.png"
        zoom_path = ZOOM_FRAME_DIR / f"frame_{index:03d}_4x.png"
        frame.save(frame_path, optimize=False)
        frame.resize((512, 512), Image.Resampling.NEAREST).save(zoom_path, optimize=False)
        frame_paths.append(frame_path)
        zoom_frame_paths.append(zoom_path)

    sheet = compose_sheet(frames)
    sheet.save(SHEET_PATH, optimize=False)
    sheet.save(OVERVIEW_PATH, optimize=False)
    preview_sheet = Image.new("RGBA", sheet.size, (*PREVIEW_BACKGROUND, 255))
    preview_sheet.alpha_composite(sheet)
    preview_sheet.resize((2048, 2048), Image.Resampling.NEAREST).save(
        ZOOM_OVERVIEW_PATH, optimize=False
    )
    make_processor_input(sheet)
    run_skill_processor()

    previews = [compose_preview(frame) for frame in frames]
    gif_report = write_verified_gif(previews, GIF_PATH, FRAME_DURATION_MS)
    slow_gif_report = write_verified_gif(previews, SLOW_GIF_PATH, SLOW_FRAME_DURATION_MS)

    changed_per_frame: list[int] = []
    changed_outside_eye_contour: list[int] = []
    for parent_frame, frame, target_points in zip(
        parent_frames, frames, target_point_sets, strict=True
    ):
        changes = changed_points(parent_frame, frame)
        changed_per_frame.append(len(changes))
        changed_outside_eye_contour.append(len(changes - target_points))

    relative_eye_match: list[bool] = []
    reference_pixels = reference.load()
    for frame, head_y_offset in zip(frames, head_y_offsets, strict=True):
        pixels = frame.load()
        relative_eye_match.append(
            all(
                pixels[x, y + head_y_offset] == reference_pixels[x, y]
                for x, y in contour_points
            )
        )

    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("At least one delivery frame is empty")
    delivery_edge_frames = edge_touch_frames(frames)
    first_last_identical = frames[0].tobytes() == frames[-1].tobytes()
    alpha_binary = [
        set(frame.getchannel("A").get_flattened_data()) <= {0, 255}
        for frame in frames
    ]
    skill_meta_path = PROCESSOR_OUTPUT_DIR / "pipeline-meta.json"
    skill_meta = json.loads(skill_meta_path.read_text(encoding="utf-8"))
    parent_report = json.loads(
        (PARENT_MANIFEST_ROOT / "qa_report.json").read_text(encoding="utf-8")
    )
    technical_pass = (
        not delivery_edge_frames
        and all(alpha_binary)
        and first_last_identical
        and all(value == 0 for value in changed_outside_eye_contour)
        and all(relative_eye_match)
        and bool(gif_report["passed"])
        and bool(slow_gif_report["passed"])
        and not skill_meta.get("empty_frames")
        and not skill_meta.get("output_edge_touch_frames")
        and not skill_meta.get("paste_clamped_frames")
    )
    report = {
        "version": 2,
        "revision_type": "deterministic_local_eye_lock",
        "parent_version": "flight_v1",
        "parent_qa_report": relative(PARENT_MANIFEST_ROOT / "qa_report.json"),
        "source_rika_generation_id": parent_report["generation_id"],
        "rika_generation_call_count_for_v2": 0,
        "rika_credit_change_for_v2": 0,
        "frame_count": FRAME_COUNT,
        "frame_size": list(FRAME_SIZE),
        "frame_paths": [relative(path) for path in frame_paths],
        "zoom_frame_paths": [relative(path) for path in zoom_frame_paths],
        "eye_lock": {
            "reference_frame": relative(PARENT_FRAME_DIR / "frame_001.png"),
            "mask": relative(MASK_PATH),
            "mask_pixel_count": len(contour_points),
            "mask_method": "source face-skin and closed-eye pixels inside two eye neighborhoods; contour pixels only, no rectangular paste",
            "left_eye_region_for_mask_discovery": list(LEFT_EYE_REGION),
            "right_eye_region_for_mask_discovery": list(RIGHT_EYE_REGION),
            "head_y_offsets": head_y_offsets,
            "relative_eye_match_reference": relative_eye_match,
            "changed_pixels_vs_v1": changed_per_frame,
            "changed_pixels_outside_shifted_eye_contour": changed_outside_eye_contour,
        },
        "delivery_edge_touch_frames": delivery_edge_frames,
        "alpha_binary": alpha_binary,
        "first_last_identical": first_last_identical,
        "gif": gif_report,
        "slow_gif": slow_gif_report,
        "sheet": relative(SHEET_PATH),
        "overview": relative(OVERVIEW_PATH),
        "zoom_overview": relative(ZOOM_OVERVIEW_PATH),
        "sheet_sha256": hashlib.sha256(SHEET_PATH.read_bytes()).hexdigest(),
        "skill_processor_qc": {
            "pipeline_meta": relative(skill_meta_path),
            "empty_frames": skill_meta.get("empty_frames"),
            "source_edge_touch_frames": skill_meta.get("source_edge_touch_frames"),
            "output_edge_touch_frames": skill_meta.get("output_edge_touch_frames"),
            "paste_clamped_frames": skill_meta.get("paste_clamped_frames"),
            "qc_summary": skill_meta.get("qc_summary"),
        },
        "technical_qa_status": "PASS" if technical_pass else "BLOCKED",
        "visual_qa_status": "PENDING_MANUAL_REVIEW",
    }
    MANIFEST_ROOT.mkdir(parents=True, exist_ok=True)
    QA_REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    if not technical_pass:
        raise ValueError(f"Technical QA failed; see {QA_REPORT_PATH}")
    print(f"EYE_MASK_PIXELS={len(contour_points)}")
    print(f"HEAD_Y_OFFSETS={head_y_offsets}")
    print(f"CHANGED_PIXELS_VS_V1={changed_per_frame}")
    print(f"CHANGED_OUTSIDE_EYE_CONTOUR={changed_outside_eye_contour}")
    print(f"RELATIVE_EYE_MATCH={relative_eye_match}")
    print(f"DELIVERY_EDGE_TOUCH_FRAMES={delivery_edge_frames}")
    print(f"FIRST_LAST_IDENTICAL={first_last_identical}")
    print(f"GIF_EXACT_PIXEL_MATCH={gif_report['passed']}")
    print(f"SLOW_GIF_EXACT_PIXEL_MATCH={slow_gif_report['passed']}")
    print(f"TECHNICAL_QA={'PASS' if technical_pass else 'BLOCKED'}")
    print(f"OVERVIEW={ZOOM_OVERVIEW_PATH}")
    print(f"GIF={GIF_PATH}")


if __name__ == "__main__":
    main()
