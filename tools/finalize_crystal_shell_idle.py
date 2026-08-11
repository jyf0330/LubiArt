from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


FRAME_COUNT = 16
FRAME_SIZE = 128
FRAME_DURATION_MS = 240
SLOW_FRAME_DURATION_MS = 300


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Finalize the processed crystal-shell idle loop and verify PNG/GIF parity."
    )
    parser.add_argument("--processor-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args()


def harden_alpha(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA")).copy()
    opaque = rgba[:, :, 3] >= 128
    rgba[:, :, 3] = np.where(opaque, 255, 0).astype(np.uint8)
    rgba[~opaque, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def remove_small_components(image: Image.Image, minimum_area: int = 8) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA")).copy()
    opaque = rgba[:, :, 3] == 255
    visited = np.zeros_like(opaque, dtype=bool)
    height, width = opaque.shape
    for y in range(height):
        for x in range(width):
            if not opaque[y, x] or visited[y, x]:
                continue
            stack = [(x, y)]
            visited[y, x] = True
            points: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                points.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if 0 <= nx < width and 0 <= ny < height and opaque[ny, nx] and not visited[ny, nx]:
                        visited[ny, nx] = True
                        stack.append((nx, ny))
            if len(points) < minimum_area:
                for px, py in points:
                    rgba[py, px] = (0, 0, 0, 0)
    return Image.fromarray(rgba, "RGBA")


def make_shared_palette(frames: list[Image.Image]) -> tuple[Image.Image, list[int]]:
    foreground = []
    for frame in frames:
        rgba = np.asarray(frame)
        foreground.append(rgba[rgba[:, :, 3] == 255, :3])
    pixels = np.concatenate(foreground, axis=0)
    palette_source = Image.fromarray(pixels.reshape(1, -1, 3).astype(np.uint8), "RGB")
    quantized = palette_source.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    opaque_palette = list((quantized.getpalette() or [])[: 255 * 3])
    opaque_palette += [0] * (255 * 3 - len(opaque_palette))

    palette_image = Image.new("P", (1, 1), 0)
    palette_image.putpalette(opaque_palette + [0, 0, 0])
    final_palette = [0, 0, 0] + opaque_palette
    return palette_image, final_palette


def quantize_frame(
    frame: Image.Image,
    palette_image: Image.Image,
    final_palette: list[int],
) -> Image.Image:
    rgba = np.asarray(frame.convert("RGBA"))
    opaque = rgba[:, :, 3] == 255
    rgb = rgba[:, :, :3]
    quantized = Image.fromarray(rgb, "RGB").quantize(
        palette=palette_image,
        dither=Image.Dither.NONE,
    )
    indices = np.asarray(quantized, dtype=np.uint16) + 1
    indices[~opaque] = 0
    result = Image.fromarray(indices.astype(np.uint8), "P")
    result.putpalette(final_palette)
    result.info["transparency"] = 0
    return result


def build_overview(frames: list[Image.Image], output_path: Path) -> None:
    scale = 4
    columns = 4
    rows = 4
    gap = 20
    margin = 20
    label_height = 22
    scaled_size = FRAME_SIZE * scale
    width = margin * 2 + columns * scaled_size + (columns - 1) * gap
    height = margin * 2 + rows * (label_height + scaled_size) + (rows - 1) * gap
    overview = Image.new("RGBA", (width, height), (31, 35, 42, 255))
    draw = ImageDraw.Draw(overview)
    for index, frame in enumerate(frames):
        row, column = divmod(index, columns)
        x = margin + column * (scaled_size + gap)
        y = margin + row * (label_height + scaled_size + gap)
        draw.text((x, y), f"{index + 1:02d}", fill=(230, 233, 240, 255))
        enlarged = frame.convert("RGBA").resize(
            (scaled_size, scaled_size),
            resample=Image.Resampling.NEAREST,
        )
        overview.alpha_composite(enlarged, (x, y + label_height))
    overview.convert("RGB").save(output_path, optimize=True)


def build_transparent_sheet(frames: list[Image.Image], output_path: Path) -> None:
    sheet = Image.new("RGBA", (FRAME_SIZE * 4, FRAME_SIZE * 4), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        row, column = divmod(index, 4)
        sheet.alpha_composite(frame.convert("RGBA"), (column * FRAME_SIZE, row * FRAME_SIZE))
    sheet.save(output_path, optimize=True)


def build_background_check(frames: list[Image.Image], output_path: Path) -> None:
    scale = 2
    tile = FRAME_SIZE * scale
    backgrounds = [
        ("light", (222, 226, 232, 255)),
        ("dark", (31, 35, 42, 255)),
        ("battle", (87, 122, 84, 255)),
    ]
    gap = 16
    margin = 16
    label_height = 22
    panel_width = tile * 4
    panel_height = label_height + tile * 4
    canvas = Image.new(
        "RGBA",
        (margin * 2 + panel_width * 3 + gap * 2, margin * 2 + panel_height),
        (16, 18, 22, 255),
    )
    draw = ImageDraw.Draw(canvas)
    for panel_index, (label, color) in enumerate(backgrounds):
        panel_x = margin + panel_index * (panel_width + gap)
        draw.text((panel_x, margin), label, fill=(235, 238, 244, 255))
        for index, frame in enumerate(frames):
            row, column = divmod(index, 4)
            tile_image = Image.new("RGBA", (tile, tile), color)
            enlarged = frame.convert("RGBA").resize((tile, tile), Image.Resampling.NEAREST)
            tile_image.alpha_composite(enlarged)
            canvas.alpha_composite(
                tile_image,
                (panel_x + column * tile, margin + label_height + row * tile),
            )
    canvas.convert("RGB").save(output_path, optimize=True)


def alpha_bbox(frame: Image.Image) -> tuple[int, int, int, int] | None:
    return frame.convert("RGBA").getchannel("A").getbbox()


def connected_components(alpha: np.ndarray) -> list[int]:
    opaque = alpha == 255
    visited = np.zeros_like(opaque, dtype=bool)
    areas: list[int] = []
    height, width = opaque.shape
    for y in range(height):
        for x in range(width):
            if not opaque[y, x] or visited[y, x]:
                continue
            stack = [(x, y)]
            visited[y, x] = True
            area = 0
            while stack:
                px, py = stack.pop()
                area += 1
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if 0 <= nx < width and 0 <= ny < height and opaque[ny, nx] and not visited[ny, nx]:
                        visited[ny, nx] = True
                        stack.append((nx, ny))
            areas.append(area)
    return sorted(areas, reverse=True)


def save_gif(frames: list[Image.Image], output_path: Path, duration_ms: int) -> None:
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0,
        transparency=0,
        disposal=2,
        optimize=False,
    )


def verify_gif(gif_path: Path, frames: list[Image.Image], duration_ms: int) -> dict[str, object]:
    expected = [np.asarray(frame.convert("RGBA")) for frame in frames]
    decoded: list[np.ndarray] = []
    durations: list[int] = []
    disposals: list[int] = []
    with Image.open(gif_path) as gif:
        for index in range(gif.n_frames):
            gif.seek(index)
            decoded.append(np.asarray(gif.convert("RGBA")).copy())
            durations.append(int(gif.info.get("duration", 0)))
            disposals.append(int(getattr(gif, "disposal_method", 0)))
    exact = len(decoded) == len(expected) and all(
        np.array_equal(actual, wanted) for actual, wanted in zip(decoded, expected, strict=True)
    )
    return {
        "decoded_frame_count": len(decoded),
        "durations_ms": durations,
        "disposal_methods": disposals,
        "frame_count_matches": len(decoded) == len(expected),
        "duration_matches": all(value == duration_ms for value in durations),
        "all_frames_exact_rgba_match": exact,
    }


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    frames_dir = args.output_dir / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)

    processed = []
    for index in range(1, FRAME_COUNT + 1):
        with Image.open(args.processor_dir / f"idle-{index}.png") as image:
            processed.append(remove_small_components(harden_alpha(image)))

    palette_image, final_palette = make_shared_palette(processed)
    frames = [quantize_frame(frame, palette_image, final_palette) for frame in processed]
    frame_paths: list[Path] = []
    for index, frame in enumerate(frames, start=1):
        frame_path = frames_dir / f"frame_{index:03d}.png"
        frame.save(frame_path, transparency=0, optimize=True)
        frame_paths.append(frame_path)

    frames = []
    for frame_path in frame_paths:
        with Image.open(frame_path) as saved:
            saved.load()
            frames.append(saved.copy())

    gif_path = args.output_dir / "anim_spr_999_idle_001.gif"
    slow_gif_path = args.output_dir / "anim_spr_999_idle_001_slow.gif"
    overview_path = args.output_dir / "anim_spr_999_idle_001_overview.png"
    sheet_path = args.output_dir / "anim_spr_999_idle_001_sheet.png"
    edge_check_path = args.output_dir / "anim_spr_999_idle_001_edge_check.png"
    save_gif(frames, gif_path, FRAME_DURATION_MS)
    save_gif(frames, slow_gif_path, SLOW_FRAME_DURATION_MS)
    build_overview(frames, overview_path)
    build_transparent_sheet(frames, sheet_path)
    build_background_check(frames, edge_check_path)

    bboxes = [alpha_bbox(frame) for frame in frames]
    margins = [
        [bbox[0], bbox[1], FRAME_SIZE - bbox[2], FRAME_SIZE - bbox[3]]
        for bbox in bboxes
        if bbox is not None
    ]
    centers_x = [(bbox[0] + bbox[2]) / 2.0 for bbox in bboxes if bbox]
    bottoms = [bbox[3] for bbox in bboxes if bbox]
    components = [connected_components(np.asarray(frame.convert("RGBA"))[:, :, 3]) for frame in frames]
    alpha_values = sorted(
        {
            int(value)
            for frame in frames
            for value in np.unique(np.asarray(frame.convert("RGBA"))[:, :, 3])
        }
    )
    normal_gif = verify_gif(gif_path, frames, FRAME_DURATION_MS)
    slow_gif = verify_gif(slow_gif_path, frames, SLOW_FRAME_DURATION_MS)
    if not normal_gif["all_frames_exact_rgba_match"] or not slow_gif["all_frames_exact_rgba_match"]:
        raise RuntimeError("GIF decode does not exactly match the delivery PNG frames")

    report = {
        "asset_id": "SPR_999",
        "asset_name": "crystal_shell",
        "animation_id": "ANIM_SPR_999_IDLE_001",
        "action": "idle",
        "source": "user_supplied_4x4_sheet",
        "identity_anchor": "user_supplied_transparent_reference",
        "frame_count": FRAME_COUNT,
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "frame_duration_ms": FRAME_DURATION_MS,
        "loop_duration_ms": FRAME_DURATION_MS * FRAME_COUNT,
        "alpha_values": alpha_values,
        "alpha_bboxes": bboxes,
        "safe_margins_ltrb": margins,
        "minimum_safe_margin_pixels": min(min(values) for values in margins),
        "anchor_summary": {
            "center_x_min": min(centers_x),
            "center_x_max": max(centers_x),
            "bottom_min": min(bottoms),
            "bottom_max": max(bottoms),
        },
        "component_areas": components,
        "component_note": (
            "Each delivery frame contains one connected subject region after removing isolated "
            "processor resampling specks smaller than eight pixels."
        ),
        "gif_verification": normal_gif,
        "slow_gif_verification": slow_gif,
        "outputs": {
            "frames": [str(Path("frames") / path.name) for path in frame_paths],
            "gif": gif_path.name,
            "slow_gif": slow_gif_path.name,
            "overview": overview_path.name,
            "sheet": sheet_path.name,
            "edge_check": edge_check_path.name,
        },
    }
    (args.output_dir / "qa_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
