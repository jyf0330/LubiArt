#!/usr/bin/env python3
"""Normalize Photoshop shop exports into confirmed Godot render units."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "outputs/shop_godot_psd_v1/raw_full_canvas"
OUTPUT_DIR = ROOT / "art/images/shop/screen_shop_godot_v1"
MANIFEST_PATH = ROOT / "art/manifests/shop/psd_layer_manifest.json"
REFERENCE_PATH = ROOT / "outputs/shop_godot_psd_v1/shop_dynamic_fields_reference.png"
SOURCE_PSD_NAME = "新商店2_三选建筑工作版_副本.psd"
SOURCE_PSD_SHA256 = "7f0a76ec48fe41f3499dc3718607522dff06d231ef30f30bf2504960e5a71fbc"
CANVAS = (1920, 1080)


def load_rgba(name: str) -> Image.Image:
    image = Image.open(RAW_DIR / f"{name}.png").convert("RGBA")
    if image.size != CANVAS:
        raise ValueError(f"{name} must be 1920x1080, got {image.size}")
    return image


def save_crop(name: str, source: Image.Image, rect: tuple[int, int, int, int]) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    cropped = source.crop(rect)
    pixels = cropped.load()
    for y in range(cropped.height):
        for x in range(cropped.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    cropped.save(OUTPUT_DIR / f"{name}.png")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_reference() -> None:
    image = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    offer_rects = [
        (498, 360, 658, 550),
        (823, 360, 983, 550),
        (1148, 360, 1308, 550),
        (498, 610, 658, 800),
        (1148, 610, 1308, 800),
    ]
    for index, rect in enumerate(offer_rects, start=1):
        draw.rectangle(rect, outline=(0, 255, 210, 220), width=3)
        draw.text((rect[0] + 6, rect[1] + 6), f"slot_offer_{index:02d}", fill=(0, 255, 210, 255))
        draw.line((rect[0] + 52, rect[3] - 18, rect[2] - 52, rect[3] - 18), fill=(255, 220, 64, 255), width=2)
    draw.rectangle((813, 566, 990, 768), outline=(255, 160, 48, 220), width=3)
    draw.text((819, 572), "merchant_dynamic", fill=(255, 160, 48, 255))
    image.save(REFERENCE_PATH)


def main() -> None:
    background = load_rgba("background")
    facade = load_rgba("shop_facade")
    merchant = load_rgba("merchant_default")
    curtain = load_rgba("refresh_curtain")
    bell_normal = load_rgba("refresh_bell_normal")
    bell_hover = load_rgba("refresh_bell_hover")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    background.save(OUTPUT_DIR / "background.png")

    # Preserve the PSD facade exactly, including its authored exit-door base.
    # RouteSharedUi's interactive exit textures intentionally render on top.
    save_crop("shop_facade", facade, (31, 76, 1797, 1064))

    # The fixed counter starts at y=768 in the facade. Clip the dynamic
    # merchant at that authored occlusion edge so no extra counter node is
    # needed and alternate merchants keep the same baseline.
    save_crop("merchant_default", merchant, (813, 566, 990, 768))
    save_crop("refresh_curtain", curtain, (492, 313, 1328, 815))
    save_crop("refresh_bell_normal", bell_normal, (945, 705, 1034, 791))
    save_crop("refresh_bell_hover", bell_hover, (945, 705, 1034, 791))
    build_reference()

    outputs = {
        path.name: {
            "path": f"res://art/images/shop/screen_shop_godot_v1/{path.name}",
            "sha256": sha256(path),
            "size": list(Image.open(path).size),
        }
        for path in sorted(OUTPUT_DIR.glob("*.png"))
    }
    manifest = {
        "schema": "lubiart_shop_psd_layer_manifest_v1",
        "canvas": {"width": 1920, "height": 1080},
        "source_art_psd": SOURCE_PSD_NAME,
        "source_art_psd_sha256": SOURCE_PSD_SHA256,
        "godot_psd": "res://art/images/shop/source_psd/screen_shop_godot_v1.psd",
        "policy": {
            "hidden_source_layers": "IGNORE",
            "offer_count": 5,
            "price": "dynamic_label_always_visible_except_refresh_curtain",
            "shared_ui": "reuse RouteSharedUi; do not export duplicated bag, party, coin, exit or bag overlay art",
        },
        "render_units": [
            {
                "source_layers": [
                    "背景/exec-75b199e0-f71a-4586-97ac-2b46a3a3451c",
                    "外围阴影",
                ],
                "classification": "MERGE_TEXTURE",
                "output": outputs["background.png"]["path"],
                "target": "ShopScene/Background",
                "rect": [0, 0, 1920, 1080],
                "note": "outer shadow is composited against the authored PSD background so its Darker Color blend is preserved",
            },
            {
                "source_layers": [
                    "商店主要界面/调色/Color Balance 1 copy 2",
                    "商店主要界面/商店底图",
                    "商店主要界面/柜台阴影",
                    "商店主要界面/遮挡柜台",
                ],
                "classification": "MERGE_TEXTURE",
                "output": outputs["shop_facade.png"]["path"],
                "target": "ShopScene/ShopFacade",
                "rect": [31, 76, 1766, 988],
                "postprocess": "preserve complete PSD facade; shared ExitButton overlays the authored door",
            },
            {
                "source_layers": ["商店主要界面/调色/Color Balance 1 copy 2", "商店主要界面/商人立绘"],
                "classification": "DYNAMIC_FIELD",
                "output": outputs["merchant_default.png"]["path"],
                "target": "ShopScene/Merchant",
                "rect": [813, 566, 177, 202],
                "state": "fallback merchant; identity lookup is ready and waits for confirmed same-style variants",
            },
            {
                "source_layers": [
                    "商店主要界面/调色/Color Balance 1 copy 2",
                    "商店主要界面/刷新帘子/帘子右",
                    "商店主要界面/刷新帘子/帘子左",
                    "商店主要界面/刷新帘子/帘子中",
                ],
                "classification": "STATE_RESOURCE",
                "output": outputs["refresh_curtain.png"]["path"],
                "target": "ShopScene/RefreshCurtain",
                "rect": [492, 313, 836, 502],
                "state": "refresh only",
            },
            {
                "source_layers": ["商店主要界面/调色/Color Balance 1 copy 2", "商店主要界面/刷新铃铛/刷新铃铛"],
                "classification": "STATE_RESOURCE",
                "output": outputs["refresh_bell_normal.png"]["path"],
                "target": "ShopScene/RefreshButton",
                "rect": [945, 705, 89, 86],
                "state": "normal",
            },
            {
                "source_layers": [
                    "商店主要界面/调色/Color Balance 1 copy 2",
                    "商店主要界面/刷新铃铛/刷新铃铛",
                    "商店主要界面/刷新铃铛/铃铛高亮",
                ],
                "classification": "STATE_RESOURCE",
                "output": outputs["refresh_bell_hover.png"]["path"],
                "target": "ShopScene/RefreshButton",
                "rect": [945, 705, 89, 86],
                "state": "hover_pressed_focused",
            },
        ],
        "dynamic_fields": [
            {"name": f"slot_offer_{index:02d}", "target": f"ShopScene/Offers/Offer{index:02d}", "classification": "GODOT_CONTROL", "rect": rect}
            for index, rect in enumerate([
                [498, 360, 160, 190], [823, 360, 160, 190], [1148, 360, 160, 190],
                [498, 610, 160, 190], [1148, 610, 160, 190],
            ], start=1)
        ],
        "ignored_visible_reference_layers": [
            "商店主要界面/商店精灵/*",
            "商店主要界面/金币/*",
            "商店主要界面/背包/*",
            "商店主要界面/队伍栏位/*",
            "商店主要界面/精灵/*",
            "商店主要界面/退出选择高亮/*",
            "打开背包/*",
        ],
        "outputs": outputs,
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
