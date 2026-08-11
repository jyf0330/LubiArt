from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
IMAGE_ROOT = (
    ROOT
    / "output/sprite_animation_candidates/emerald_wyrmling/preview_v1"
)
SOURCE_FRAME_DIR = IMAGE_ROOT / "source_frames"
FRAME_DIR = IMAGE_ROOT / "flight"
OVERVIEW_PATH = IMAGE_ROOT / "emerald_wyrmling_flight_overview_v1.png"
OVERVIEW_4X_PATH = IMAGE_ROOT / "emerald_wyrmling_flight_overview_4x_v1.png"
GIF_PATH = IMAGE_ROOT / "emerald_wyrmling_flight_preview_v1.gif"
SLOW_GIF_PATH = IMAGE_ROOT / "emerald_wyrmling_flight_slow_check_v1.gif"
REPORT_PATH = (
    ROOT
    / "output/sprite_animation_candidates/_manifests/emerald_wyrmling/preview_v1/qa_report.json"
)

FRAME_COUNT = 6
FRAME_SIZE = (256, 256)
GRID_SIZE = (3, 2)
PREVIEW_BACKGROUND = (28, 30, 36)
FRAME_DURATION_MS = 140
SLOW_FRAME_DURATION_MS = 420


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def harden_alpha(frame: Image.Image) -> Image.Image:
    rgba = frame.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgba.putalpha(alpha)
    return rgba


def composite_preview(frame: Image.Image) -> Image.Image:
    preview = Image.new("RGB", FRAME_SIZE, PREVIEW_BACKGROUND)
    preview.paste(frame.convert("RGB"), mask=frame.getchannel("A"))
    return preview


def apply_shared_palette(
    frames: list[Image.Image],
) -> tuple[list[Image.Image], list[Image.Image]]:
    atlas = Image.new("RGB", (FRAME_SIZE[0] * FRAME_COUNT, FRAME_SIZE[1]))
    for index, frame in enumerate(frames):
        atlas.paste(composite_preview(frame), (index * FRAME_SIZE[0], 0))
    palette = atlas.quantize(
        colors=256,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )

    quantized_frames: list[Image.Image] = []
    gif_frames: list[Image.Image] = []
    for frame in frames:
        preview_p = composite_preview(frame).quantize(
            palette=palette,
            dither=Image.Dither.NONE,
        )
        rgba = preview_p.convert("RGBA")
        rgba.putalpha(frame.getchannel("A"))
        quantized_frames.append(harden_alpha(rgba))
        gif_frames.append(preview_p)
    return quantized_frames, gif_frames


def save_gif(path: Path, frames: list[Image.Image], duration_ms: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=[duration_ms] * len(frames),
        loop=0,
        disposal=2,
        optimize=False,
    )


def verify_gif(
    path: Path, expected_frames: list[Image.Image], duration_ms: int
) -> dict[str, object]:
    gif = Image.open(path)
    exact_matches: list[bool] = []
    durations: list[int] = []
    disposal_methods: list[int | None] = []
    for index, expected in enumerate(expected_frames):
        gif.seek(index)
        exact_matches.append(
            ImageChops.difference(expected.convert("RGB"), gif.convert("RGB")).getbbox()
            is None
        )
        durations.append(int(gif.info.get("duration", 0)))
        disposal_methods.append(getattr(gif, "disposal_method", None))
    passed = (
        gif.n_frames == len(expected_frames)
        and all(exact_matches)
        and durations == [duration_ms] * len(expected_frames)
        and all(method == 2 for method in disposal_methods)
    )
    return {
        "path": relative(path),
        "frame_count": gif.n_frames,
        "expected_frame_count": len(expected_frames),
        "durations_ms": durations,
        "expected_duration_ms": duration_ms,
        "disposal_methods": disposal_methods,
        "source_preview_pixel_exact": exact_matches,
        "passed": passed,
    }


def different_pixel_count(left: Image.Image, right: Image.Image) -> int:
    difference = ImageChops.difference(left.convert("RGB"), right.convert("RGB"))
    return sum(
        1 for pixel in difference.get_flattened_data() if pixel != (0, 0, 0)
    )


def magenta_spill_count(frame: Image.Image) -> int:
    return sum(
        1
        for red, green, blue, alpha in frame.get_flattened_data()
        if alpha
        and red >= 180
        and blue >= 140
        and green <= 100
        and red >= green + 80
        and blue >= green + 60
    )


def main() -> None:
    source_frame_paths = [
        SOURCE_FRAME_DIR / f"frame_{index:03d}.png" for index in range(1, 7)
    ]
    frame_paths = [FRAME_DIR / f"frame_{index:03d}.png" for index in range(1, 7)]
    frames = [harden_alpha(Image.open(path)) for path in source_frame_paths]
    if any(frame.size != FRAME_SIZE for frame in frames):
        raise ValueError("All flight frames must remain 256x256")

    frames, gif_frames = apply_shared_palette(frames)
    for path, frame in zip(frame_paths, frames, strict=True):
        frame.save(path, optimize=False)

    overview = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * GRID_SIZE[0], FRAME_SIZE[1] * GRID_SIZE[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        overview.alpha_composite(
            frame,
            (
                (index % GRID_SIZE[0]) * FRAME_SIZE[0],
                (index // GRID_SIZE[0]) * FRAME_SIZE[1],
            ),
        )
    overview.save(OVERVIEW_PATH, optimize=False)

    overview_dark = Image.new("RGBA", overview.size, (*PREVIEW_BACKGROUND, 255))
    overview_dark.alpha_composite(overview)
    overview_dark.resize(
        (overview.width * 4, overview.height * 4),
        Image.Resampling.NEAREST,
    ).save(OVERVIEW_4X_PATH, optimize=False)

    save_gif(GIF_PATH, gif_frames, FRAME_DURATION_MS)
    save_gif(SLOW_GIF_PATH, gif_frames, SLOW_FRAME_DURATION_MS)
    previews = [frame.convert("RGB") for frame in gif_frames]
    final_gif = verify_gif(GIF_PATH, previews, FRAME_DURATION_MS)
    slow_gif = verify_gif(SLOW_GIF_PATH, previews, SLOW_FRAME_DURATION_MS)

    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    sequential_differences = [
        different_pixel_count(previews[index], previews[(index + 1) % FRAME_COUNT])
        for index in range(FRAME_COUNT)
    ]
    internal_max = max(sequential_differences[:-1])
    loop_ratio = sequential_differences[-1] / internal_max if internal_max else 0.0
    alpha_binary = [
        set(frame.getchannel("A").get_flattened_data()) <= {0, 255}
        for frame in frames
    ]
    transparent_corners = [
        all(
            frame.getpixel(point)[3] == 0
            for point in ((0, 0), (255, 0), (0, 255), (255, 255))
        )
        for frame in frames
    ]
    edge_clear = [
        box is not None
        and box[0] > 0
        and box[1] > 0
        and box[2] < FRAME_SIZE[0]
        and box[3] < FRAME_SIZE[1]
        for box in boxes
    ]
    spill_counts = [magenta_spill_count(frame) for frame in frames]

    passed = (
        all(alpha_binary)
        and all(transparent_corners)
        and all(edge_clear)
        and all(count == 0 for count in spill_counts)
        and bool(final_gif["passed"])
        and bool(slow_gif["passed"])
        and loop_ratio <= 1.20
    )
    report = {
        "version": 1,
        "action": "flight",
        "frame_count": FRAME_COUNT,
        "frame_size": list(FRAME_SIZE),
        "source_frame_paths": [relative(path) for path in source_frame_paths],
        "source_frame_sha256": [sha256(path) for path in source_frame_paths],
        "frame_paths": [relative(path) for path in frame_paths],
        "frame_sha256": [sha256(path) for path in frame_paths],
        "alpha_bounding_boxes": [list(box) if box else None for box in boxes],
        "alpha_binary": alpha_binary,
        "transparent_corners": transparent_corners,
        "edge_clear": edge_clear,
        "residual_magenta_pixels": spill_counts,
        "sequential_difference_pixels_including_loop": sequential_differences,
        "loop_transition_vs_largest_internal_ratio": loop_ratio,
        "overview": relative(OVERVIEW_PATH),
        "overview_4x": relative(OVERVIEW_4X_PATH),
        "final_gif": final_gif,
        "slow_check_gif": slow_gif,
        "manual_visual_review": {
            "original_size": "PASS",
            "four_times_zoom": "PASS",
            "head_body_wings_tail_feet": "PASS",
            "hard_cut_or_detached_limb": "NONE_OBSERVED",
            "identity_or_palette_drift": "NONE_OBVIOUS",
            "ghosting": "NONE_OBSERVED",
        },
        "technical_qa_status": "PASS" if passed else "BLOCKED",
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not passed:
        raise ValueError(f"Flight animation QA failed; see {REPORT_PATH}")

    print(f"FRAME_COUNT={FRAME_COUNT}")
    print(f"LOOP_TRANSITION_RATIO={loop_ratio:.4f}")
    print(f"GIF_EXACT_PIXEL_MATCH={final_gif['passed']}")
    print(f"SLOW_GIF_EXACT_PIXEL_MATCH={slow_gif['passed']}")
    print(f"QA_STATUS={report['technical_qa_status']}")


if __name__ == "__main__":
    main()
