#!/usr/bin/env python3
"""Normalize Photoshop exports into stable Godot render-unit canvases."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "outputs" / "three_choice_godot_psd_v3"
RAW_DIR = OUTPUT_ROOT / "raw_full_canvas"
EXPORT_DIR = OUTPUT_ROOT / "exports"
PREVIEW_DIR = OUTPUT_ROOT / "previews"
CURRENT_DIR = ROOT / "art" / "images" / "route" / "three_choice_psd"
SOURCE_PSD_DIR = CURRENT_DIR / "source_psd"
FORMAL_MANIFEST = ROOT / "art" / "manifests" / "route" / "three_choice" / "psd_layer_manifest.json"

CANVAS_SIZE = (1920, 1080)
CARD_SIZE = (365, 500)
PORTRAIT_TARGET_HEIGHT = 220
PORTRAIT_MAX_WIDTH = 260
PORTRAIT_VISUAL_CENTER_X = 160
PORTRAIT_BASELINE_Y = 370
CARD_ORIGINS = {
    "shop": (436, 346),
    "event": (747, 346),
    "reward": (1072, 346),
}


def open_rgba(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != CANVAS_SIZE:
        raise ValueError(f"Expected 1920x1080 Photoshop export: {path} ({image.size})")
    return image


def alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("Render unit has no visible pixels")
    return bbox


def normalize_portrait_card(source: Image.Image) -> Image.Image:
    """Place visible portrait content on the parchment's authored visual center."""
    source = source.convert("RGBA")
    bbox = alpha_bbox(source)
    portrait = source.crop(bbox)
    scale = min(
        PORTRAIT_TARGET_HEIGHT / portrait.height,
        PORTRAIT_MAX_WIDTH / portrait.width,
    )
    normalized_size = (
        max(1, round(portrait.width * scale)),
        max(1, round(portrait.height * scale)),
    )
    portrait = portrait.resize(normalized_size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", CARD_SIZE, (0, 0, 0, 0))
    destination = (
        round(PORTRAIT_VISUAL_CENTER_X - normalized_size[0] * 0.5),
        PORTRAIT_BASELINE_Y - normalized_size[1],
    )
    canvas.alpha_composite(portrait, destination)
    return canvas


def save_crop(name: str, source: Image.Image, bbox: tuple[int, int, int, int]) -> dict:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = EXPORT_DIR / f"{name}.png"
    source.crop(bbox).save(path, optimize=True)
    return {
        "name": name,
        "path": f"exports/{name}.png",
        "bbox": list(bbox),
        "size": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
    }


def save_card_image(name: str, source: Image.Image, slot: str, note: str = "") -> dict:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = EXPORT_DIR / f"{name}.png"
    source.save(path, optimize=True)
    origin_x, origin_y = CARD_ORIGINS[slot]
    record = {
        "name": name,
        "path": f"exports/{name}.png",
        "bbox": [origin_x, origin_y, origin_x + CARD_SIZE[0], origin_y + CARD_SIZE[1]],
        "size": list(CARD_SIZE),
    }
    if note:
        record["note"] = note
    return record


def save_card_crop(name: str, source: Image.Image, slot: str) -> dict:
    left, top = CARD_ORIGINS[slot]
    bbox = (left, top, left + CARD_SIZE[0], top + CARD_SIZE[1])
    card = source.crop(bbox)
    if name.startswith("route_portrait_"):
        card = normalize_portrait_card(card)
        return save_card_image(
            name,
            card,
            slot,
            "Visible portrait content is nearest-neighbor normalized to the shared height, center line, and baseline.",
        )
    return save_card_image(name, card, slot)


def masked_graded_unit(name: str, mask_name: str | None = None) -> Image.Image:
    graded = open_rgba(RAW_DIR / f"{name}.png")
    mask = open_rgba(RAW_DIR / f"{mask_name or name + '_ungraded'}.png")
    graded.putalpha(mask.getchannel("A"))
    return graded


def remove_open_bag_closed_state_fragment(image: Image.Image) -> Image.Image:
    """Remove the legacy closed-chest stair strip painted behind the open state."""
    cleaned = image.copy()
    alpha = cleaned.getchannel("A")
    alpha.paste(0, (313, 865, 359, 919))
    cleaned.putalpha(alpha)
    return cleaned


def place_existing_card_art(
    name: str,
    source_name: str,
    target_bbox: tuple[int, int, int, int],
    slot: str,
) -> dict:
    source = Image.open(CURRENT_DIR / source_name).convert("RGBA")
    if name.startswith("route_portrait_"):
        return save_card_image(
            name,
            normalize_portrait_card(source),
            slot,
            "Reuses the imported portrait and nearest-neighbor normalizes visible content to the shared height, center line, and baseline.",
        )
    width = target_bbox[2] - target_bbox[0]
    height = target_bbox[3] - target_bbox[1]
    source = source.resize((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", CARD_SIZE, (0, 0, 0, 0))
    origin_x, origin_y = CARD_ORIGINS[slot]
    canvas.alpha_composite(source, (target_bbox[0] - origin_x, target_bbox[1] - origin_y))
    return save_card_image(
        name,
        canvas,
        slot,
        "Reuses the already imported icon and normalizes it onto the authored card canvas.",
    )


def composite_preview(entries: list[dict], visible_names: list[str], output_name: str) -> None:
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    by_name = {item["name"]: item for item in entries}
    for name in visible_names:
        item = by_name[name]
        image = Image.open(OUTPUT_ROOT / item["path"]).convert("RGBA")
        canvas.alpha_composite(image, (item["bbox"][0], item["bbox"][1]))
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(PREVIEW_DIR / output_name, quality=95)


def main() -> None:
    install = "--install" in sys.argv[1:]
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    entries: list[dict] = []

    background = open_rgba(RAW_DIR / "background.png")
    entries.append(save_crop("background", background, (0, 0, *CANVAS_SIZE)))

    building = masked_graded_unit("building")
    building_ungraded = open_rgba(RAW_DIR / "building_ungraded.png")
    entries.append(save_crop("building", building, alpha_bbox(building_ungraded)))

    fixed_units = {
        "bag_inventory_base": (502, 399, 1320, 838),
        "bag_item_highlight": (542, 430, 723, 604),
    }
    for name, bbox in fixed_units.items():
        raw_name = "bag_open" if name == "bag_open_full" else name
        entries.append(save_crop(name, open_rgba(RAW_DIR / f"{raw_name}.png"), bbox))

    graded_units = {
        "party_shelf": (519, 607, 1401, 1026),
        "exit_normal": (1410, 510, 1679, 982),
        "exit_hover": (1410, 510, 1679, 982),
        "bag_closed": (313, 796, 549, 1029),
        "bag_open_full": (313, 796, 549, 1029),
        "coin_panel_static": (1303, 905, 1468, 1029),
    }
    for name, bbox in graded_units.items():
        raw_name = "bag_open" if name == "bag_open_full" else name
        unit = masked_graded_unit(raw_name)
        if name == "bag_open_full":
            unit = remove_open_bag_closed_state_fragment(unit)
        entries.append(save_crop(name, unit, bbox))

    slot_assets = {
        "route_highlight_shop": ("route_highlight_1", "shop"),
        "route_highlight_event": ("route_highlight_2", "event"),
        "route_highlight_reward": ("route_highlight_3", "reward"),
        "route_portrait_shop_bai_xiaochang": ("portrait_slot_1_bai_xiaochang", "shop"),
        "route_portrait_shop_variant_3": ("portrait_slot_1_variant_3", "shop"),
        "route_portrait_shop_variant_5": ("portrait_slot_1_variant_5", "shop"),
        "route_portrait_event_herb_merchant": ("portrait_slot_2_herb_merchant", "event"),
        "route_portrait_event_fish_merchant": ("portrait_slot_2_fish_merchant", "event"),
        "route_portrait_event_ox_merchant": ("portrait_slot_2_ox_merchant", "event"),
        "route_portrait_reward_short_samurai": ("portrait_slot_3_short_samurai", "reward"),
        "route_portrait_reward_variant_4": ("portrait_slot_3_variant_4", "reward"),
    }
    for export_name, (raw_name, slot) in slot_assets.items():
        entries.append(save_card_crop(export_name, open_rgba(RAW_DIR / f"{raw_name}.png"), slot))

    entries.extend(
        [
            place_existing_card_art(
                "route_portrait_shop", "route_portrait_shop.png", (509, 524, 685, 706), "shop"
            ),
            place_existing_card_art(
                "route_portrait_event", "route_portrait_event.png", (818, 484, 1012, 715), "event"
            ),
            place_existing_card_art(
                "route_portrait_reward", "route_portrait_reward.png", (1169, 513, 1295, 712), "reward"
            ),
            place_existing_card_art(
                "route_icon_shop", "route_icon_shop.png", (575, 394, 615, 456), "shop"
            ),
            place_existing_card_art(
                "route_icon_event", "route_icon_event.png", (890, 394, 929, 456), "event"
            ),
            place_existing_card_art(
                "route_icon_reward", "route_icon_reward.png", (1201, 394, 1242, 456), "reward"
            ),
        ]
    )

    manifest = {
        "source_psd": "新三选3.psd",
        "canvas": list(CANVAS_SIZE),
        "route_portrait_normalization": {
            "canvas": list(CARD_SIZE),
            "visible_content_height": PORTRAIT_TARGET_HEIGHT,
            "max_visible_content_width": PORTRAIT_MAX_WIDTH,
            "horizontal_anchor": "parchment_visual_center",
            "horizontal_anchor_x": PORTRAIT_VISUAL_CENTER_X,
            "baseline_y": PORTRAIT_BASELINE_Y,
            "resampling": "nearest_neighbor",
        },
        "note": "Candidate Godot-dedicated render units. The page background is sourced from 新背景. 调色 is masked and baked into the building, chest states, coin panel, exit states, and party shelf; route portraits and runtime party sprites remain ungraded. Route portraits use the parchment visual center rather than the transparent card canvas center. The chest renders below the party shelf. Paths are relative to this delivery folder until user approval.",
        "exports": entries,
        "dynamic_fields": [
            {"name": "txt_coin_amount", "target": "MainBG/Containers/Top/Hud/CoinLabel"},
            *[
                {"name": f"slot_party_pet_{index}", "target": f"MainBG/Containers/Party/Party_Container/Party_Pet{index}"}
                for index in range(1, 5)
            ],
            *[
                {"name": f"slot_bag_item_{index}", "target": f"MainBG/Containers/Middle/Middle_Bag/ItemBar/Slots/ItemSlot{index}"}
                for index in range(1, 9)
            ],
        ],
        "godot_controls": [
            {
                "name": "hit_exit_button",
                "type": "TextureButton",
                "target": "MainBG/Containers/ExitButton",
                "rect": [1410, 510, 1679, 982],
            },
            {
                "name": "dim_bag_overlay",
                "type": "ColorRect",
                "target": "MainBG/Containers/BagOverlayMask",
                "rect": [0, 0, 1920, 1080],
            },
        ],
        "ignored": [
            "香炉、香炉烟、烟雾 (confirmed obsolete visual source and removed from the authored Scene/prefab)",
            "PSD sample party pets and sample bag pet (runtime data placeholders)",
            "hidden route icons already imported in the project (existing files reused)",
        ],
    }
    (OUTPUT_ROOT / "candidate_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    if install:
        CURRENT_DIR.mkdir(parents=True, exist_ok=True)
        for item in entries:
            source_path = OUTPUT_ROOT / item["path"]
            shutil.copy2(source_path, CURRENT_DIR / source_path.name)
        SOURCE_PSD_DIR.mkdir(parents=True, exist_ok=True)
        godot_psd = OUTPUT_ROOT / "screen_three_choice_godot_v3.psd"
        if not godot_psd.exists():
            raise FileNotFoundError("Build the Godot-dedicated PSD before --install")
        shutil.copy2(godot_psd, SOURCE_PSD_DIR / godot_psd.name)

        category_by_name = {
            "background": "MERGE_TEXTURE",
            "building": "MERGE_TEXTURE",
            "coin_panel_static": "MERGE_TEXTURE",
            "party_shelf": "MERGE_TEXTURE",
            "route_portrait_shop": "COMPONENT",
            "route_portrait_event": "COMPONENT",
            "route_portrait_reward": "COMPONENT",
            "route_icon_shop": "COMPONENT",
            "route_icon_event": "COMPONENT",
            "route_icon_reward": "COMPONENT",
        }
        target_by_name = {
            "background": "MainBG",
            "building": "MainBG/Temple",
            "coin_panel_static": "MainBG/Containers/Top/Hud/CoinIcon",
            "party_shelf": "MainBG/Containers/Bags/BagStorageState",
            "exit_normal": "MainBG/Containers/ExitButton:texture_normal",
            "exit_hover": "MainBG/Containers/ExitButton:texture_hover,texture_pressed,texture_focused",
            "bag_closed": "MainBG/Containers/Bags/Bag_Button:texture_normal",
            "bag_open_full": "MainBG/Containers/Bags/Bag_Button:open_state",
            "bag_inventory_base": "MainBG/Containers/Middle/Middle_Bag/ItemBar",
            "bag_item_highlight": "ItemSlotHoverHighlight:bag_state",
        }
        formal_exports = []
        for item in entries:
            record = item.copy()
            record["path"] = "res://art/images/route/three_choice_psd/%s" % Path(item["path"]).name
            record["classification"] = category_by_name.get(
                item["name"],
                "COMPONENT" if item["name"].startswith("route_portrait_") or item["name"].startswith("route_icon_") else "STATE_RESOURCE",
            )
            record["target"] = target_by_name.get(
                item["name"],
                "ThreeChoiceCard/%s" % ("RouteHighlight" if item["name"].startswith("route_highlight_") else "Portrait"),
            )
            formal_exports.append(record)
        formal_manifest = manifest.copy()
        formal_manifest["godot_psd"] = "res://art/images/route/three_choice_psd/source_psd/screen_three_choice_godot_v3.psd"
        formal_manifest["note"] = "Approved 新三选3 Godot runtime mapping. 调色 is baked only into the building, chest states, coin panel, exit states, and party shelf; route portraits and runtime party sprites remain ungraded. All route portraits share one authored visible-content height, parchment visual center, and baseline inside the static 365x500 card canvas. Existing bag overlay presentation is retained unchanged."
        formal_manifest["exports"] = formal_exports
        FORMAL_MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        FORMAL_MANIFEST.write_text(
            json.dumps(formal_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    default_visible = [
        "background",
        "building",
        "bag_closed",
        "party_shelf",
        "route_portrait_shop",
        "route_portrait_event",
        "route_portrait_reward",
        "route_icon_shop",
        "route_icon_event",
        "route_icon_reward",
        "exit_normal",
        "coin_panel_static",
    ]
    composite_preview(entries, default_visible, "three_choice_default.jpg")
    composite_preview(
        entries,
        [
            "background",
            "building",
            "bag_open_full",
            "party_shelf",
            "route_portrait_shop",
            "route_portrait_event",
            "route_portrait_reward",
            "route_icon_shop",
            "route_icon_event",
            "route_icon_reward",
            "exit_hover",
            "coin_panel_static",
            "bag_inventory_base",
            "bag_item_highlight",
        ],
        "three_choice_bag_open_and_exit_hover.jpg",
    )


if __name__ == "__main__":
    main()
