#!/usr/bin/env python3
import argparse
import json
import random
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter


SKIP_NAMES = (
    "遮罩",
    "高亮",
    "光效",
    "发光",
    "阴影",
)

SKIP_EXACT = {
    "Layer 11",
    "Layer 12",
    "Layer 13",
    "Layer 6",
}


def should_skip(layer):
    name = layer["name"]
    if name in SKIP_EXACT:
        return "过场烟雾效果"
    if any(token in name for token in SKIP_NAMES):
        return "遮罩/高亮/光效类特效层"
    return ""


def quantized_overlay(rgb, colors):
    pal = rgb.convert("P", palette=Image.Palette.ADAPTIVE, colors=colors)
    return pal.convert("RGB")


def add_speckles(rgba, seed, strength=7):
    arr = np.array(rgba).astype(np.int16)
    alpha = arr[:, :, 3]
    if alpha.max() == 0:
        return rgba

    rng = np.random.default_rng(seed)
    noise = rng.normal(0, strength, size=arr[:, :, :3].shape)
    mask = (alpha > 28)[:, :, None]
    arr[:, :, :3] = np.where(mask, arr[:, :, :3] + noise, arr[:, :, :3])

    opaque = np.argwhere(alpha > 70)
    if len(opaque):
        count = max(12, min(900, len(opaque) // 55))
        picked = opaque[rng.choice(len(opaque), size=count, replace=False)]
        h, w = alpha.shape
        for y, x in picked:
            radius = int(rng.integers(1, 3))
            delta = int(rng.choice([-1, 1]) * rng.integers(8, 18))
            y0, y1 = max(0, y - radius), min(h, y + radius + 1)
            x0, x1 = max(0, x - radius), min(w, x + radius + 1)
            local = alpha[y0:y1, x0:x1] > 45
            arr[y0:y1, x0:x1, :3][local] += delta

    arr[:, :, :3] = np.clip(arr[:, :, :3], 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def soften_alpha_edges(rgba):
    alpha = rgba.getchannel("A")
    if alpha.getextrema()[1] == 0:
        return rgba
    softened = alpha.filter(ImageFilter.GaussianBlur(0.35))
    out = rgba.copy()
    out.putalpha(Image.blend(alpha, softened, 0.35))
    return out


def stylize_layer(image, seed):
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    if alpha.getextrema()[1] == 0:
        return rgba

    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)

    # Blocky hand-painted pass: fewer colors, softened contrast, then a light
    # texture pass to echo the reference map backgrounds without destroying UI silhouettes.
    longest = max(rgba.size)
    scale = 0.62 if longest > 900 else 0.72 if longest > 250 else 0.86
    small_size = (max(1, int(rgba.width * scale)), max(1, int(rgba.height * scale)))
    small = rgb.resize(small_size, Image.Resampling.BICUBIC)
    small = small.filter(ImageFilter.MedianFilter(3))
    colors = 36 if longest > 900 else 28 if longest > 180 else 20
    small = quantized_overlay(small, colors)
    painted = small.resize(rgba.size, Image.Resampling.NEAREST).filter(ImageFilter.SMOOTH)

    original_soft = rgb.filter(ImageFilter.SMOOTH_MORE)
    mixed = Image.blend(original_soft, painted, 0.62)
    mixed = ImageEnhance.Color(mixed).enhance(0.88)
    mixed = ImageEnhance.Contrast(mixed).enhance(0.92)
    mixed = ImageEnhance.Brightness(mixed).enhance(1.03)

    out = Image.merge("RGBA", (*mixed.split(), alpha))
    out = add_speckles(out, seed=seed)
    out = soften_alpha_edges(out)
    return out


def composite_preview(manifest, out_dir, preview_path):
    canvas = manifest["canvas"]
    base = Image.new("RGBA", (canvas["width"], canvas["height"]), (0, 0, 0, 0))
    visible_layers = [x for x in manifest["layers"] if x.get("file") and x.get("visible", True)]
    for layer in reversed(visible_layers):
        path = out_dir / layer["file"]
        if not path.exists():
            continue
        img = Image.open(path).convert("RGBA")
        x, y = layer["left"], layer["top"]
        if layer.get("blend_mode") == "mul ":
            patch = Image.new("RGBA", base.size, (0, 0, 0, 0))
            patch.alpha_composite(img, (x, y))
            b = np.array(base).astype(np.float32)
            p = np.array(patch).astype(np.float32)
            pa = p[:, :, 3:4] / 255.0
            b[:, :, :3] = b[:, :, :3] * (1 - pa) + (b[:, :, :3] * p[:, :, :3] / 255.0) * pa
            b[:, :, 3:4] = np.maximum(b[:, :, 3:4], p[:, :, 3:4])
            base = Image.fromarray(np.clip(b, 0, 255).astype(np.uint8), "RGBA")
        else:
            base.alpha_composite(img, (x, y))
    base.convert("RGB").save(preview_path, quality=94)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("layers_dir")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    src = Path(args.layers_dir)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((src / "manifest.json").read_text(encoding="utf-8"))

    random.seed(20260731)
    processed = []
    for layer in manifest["layers"]:
        if not layer.get("file"):
            processed.append(layer)
            continue
        skip_reason = should_skip(layer)
        src_file = src / layer["file"]
        dst_file = out / layer["file"]
        item = dict(layer)
        if skip_reason:
            shutil.copy2(src_file, dst_file)
            item["style_status"] = "skipped"
            item["skip_reason"] = skip_reason
        else:
            image = Image.open(src_file)
            stylized = stylize_layer(image, seed=20260731 + layer["index"])
            stylized.save(dst_file)
            item["style_status"] = "converted"
        processed.append(item)

    new_manifest = {
        "canvas": manifest["canvas"],
        "notes": {
            "style": "morning map style: soft hand-painted blocks, light pixel grain, lower contrast",
            "skipped": "过场烟雾效果 group plus mask/highlight/glow/shadow effect layers",
        },
        "layers": processed,
    }
    (out / "manifest.json").write_text(json.dumps(new_manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    composite_preview(new_manifest, out, out / "preview_visible_layers.jpg")


if __name__ == "__main__":
    main()
