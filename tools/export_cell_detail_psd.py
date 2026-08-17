#!/usr/bin/env python3
"""Export the authored runtime layers from the CellDetail PSD.

The source PSD remains read-only. Dynamic pet name/stat text is intentionally
not exported because Godot owns those runtime values.
"""

from __future__ import annotations

import argparse
from datetime import date
from pathlib import Path

from PIL import Image
from psd_tools import PSDImage


DEFAULT_SOURCE = Path("/Users/ywh/Downloads/宠物信息栏实装(修改).psd")
DEFAULT_OUTPUT = Path("art/images/shared/pets/info_panel")

LAYERS = {
    "card_base_bronze.png": ("卡底", "same", "青铜卡底"),
    "card_base_silver.png": ("卡底", "same", "白银卡底"),
    "card_base_gold.png": ("卡底", "same", "黄金卡底"),
    "card_base_crystal.png": ("卡底", "same", "水晶卡底"),
    "attack_grid_bronze.png": ("攻击格式盘子", "攻击棋盘", "same", "青铜攻击棋盘"),
    "attack_grid_silver.png": ("攻击格式盘子", "攻击棋盘", "same", "白银攻击棋盘"),
    "attack_grid_gold.png": ("攻击格式盘子", "攻击棋盘", "same", "黄金攻击棋盘"),
    "attack_grid_crystal.png": ("攻击格式盘子", "攻击棋盘", "same", "水晶攻击棋盘"),
    "stat_slots_bronze.png": ("数值格子", "same", "青铜"),
    "stat_slots_silver.png": ("数值格子", "same", "白银"),
    "stat_slots_gold.png": ("数值格子", "same", "黄金"),
    "stat_slots_crystal.png": ("数值格子", "same", "水晶"),
    "attack_origin.png": ("攻击格式盘子", "宠物"),
    "attack_target.png": ("攻击格式盘子", "红色格子素材"),
    "stat_hp.png": ("数值格子", "数值UI", "HP"),
    "stat_attack.png": ("数值格子", "数值UI", "ATK"),
    "stat_ap.png": ("数值格子", "数值UI", "AP"),
    "stat_defense.png": ("数值格子", "数值UI", "DEF"),
    "stat_shield.png": ("数值格子", "数值UI", "护盾"),
    "stat_regen.png": ("数值格子", "数值UI", "再生"),
    "trait_silver.png": ("特性格子", "白银特性", "护体"),
    "trait_gold.png": ("特性格子", "黄金特性", "正向强化"),
    "trait_crystal.png": ("特性格子", "水晶特性", "反向结算"),
    "trait_lock_silver.png": ("特性格子", "白银特性", "锁"),
    "trait_lock_gold.png": ("特性格子", "黄金特性", "锁"),
    "trait_lock_crystal.png": ("特性格子", "水晶特性", "锁"),
}

ELEMENT_LAYERS = {
    "element_dark.png": ("属性", "same", "_0000_暗"),
    "element_water.png": ("属性", "same", "_0001_水"),
    "element_ice.png": ("属性", "same", "_0002_冰"),
    "element_grass.png": ("属性", "same", "_0003_草"),
    "element_electric.png": ("属性", "same", "_0004_电"),
    "element_wind.png": ("属性", "same", "_0005_风"),
    "element_fire.png": ("属性", "same", "_0006_火"),
    "element_dragon.png": ("属性", "same", "_0007_龙"),
    "element_earth.png": ("属性", "same", "_0008_土"),
}
ELEMENT_AUTHORED_SIZE = (93, 115)

OBSOLETE_OUTPUTS = (
    "panel_base.png",
    "panel_base_bronze.png",
    "panel_base_silver.png",
    "panel_base_gold.png",
    "panel_base_crystal.png",
    "frame_bronze.png",
    "frame_silver.png",
    "frame_gold.png",
    "frame_crystal.png",
    "attack_header_decoration.png",
    "attack_grid.png",
    "stat_slot_1.png",
    "stat_slot_2.png",
    "stat_slot_3.png",
    "stat_slot_4.png",
    "stat_slot_5.png",
    "stat_slot_6.png",
)


def find_layer(root, path: tuple[str, ...]):
    current = root
    for name in path:
        match = next((child for child in current if child.name == name), None)
        if match is None:
            raise KeyError(f"missing PSD layer: {'/'.join(path)} (stopped at {name})")
        current = match
    return current


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--psd", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    psd = PSDImage.open(args.psd)
    if psd.size != (476, 539):
        raise ValueError(f"unexpected CellDetail canvas: {psd.size}")
    args.out.mkdir(parents=True, exist_ok=True)

    manifest_lines = [
        f"source: {args.psd}",
        f"canvas: {psd.width}x{psd.height}",
        f"exported: {date.today().isoformat()}",
        "role: BattleArtScene/CellDetail pet information",
        "dynamic: pet name, element, quality, attack shape, and six stat values remain Godot runtime data",
        "resource_groups: PSD same groups are image collections only and do not become Godot nodes",
        "image_roots: image-backed functional roots directly carry one image and use its authored size",
        "layers:",
    ]
    for filename, layer_path in LAYERS.items():
        layer = find_layer(psd, layer_path)
        # Variant resources are often authored under a hidden `same` group.
        # Render the selected leaf explicitly so inactive variants still export
        # as usable runtime images instead of transparent placeholders.
        image = layer.composite(layer_filter=lambda _layer: True)
        if image is None:
            raise ValueError(f"PSD layer did not render: {'/'.join(layer_path)}")
        image.save(args.out / filename)
        bbox = tuple(layer.bbox)
        manifest_lines.append(
            f"  {filename}: {'/'.join(layer_path)} @ {bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}"
        )

    for filename, layer_path in ELEMENT_LAYERS.items():
        layer = find_layer(psd, layer_path)
        # Element variants live under the hidden PSD `same` resource group.
        # Render the selected layer explicitly; its hidden authored state must
        # not turn the exported resource into a transparent placeholder.
        image = layer.composite(layer_filter=lambda _layer: True)
        if image is None:
            raise ValueError(f"PSD layer did not render: {'/'.join(layer_path)}")
        normalized = image.resize(ELEMENT_AUTHORED_SIZE, Image.Resampling.LANCZOS)
        normalized.save(args.out / filename)
        bbox = tuple(layer.bbox)
        manifest_lines.append(
            f"  {filename}: {'/'.join(layer_path)} @ {bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}"
            f" normalized={ELEMENT_AUTHORED_SIZE[0]}x{ELEMENT_AUTHORED_SIZE[1]}"
        )

    for filename in OBSOLETE_OUTPUTS:
        (args.out / filename).unlink(missing_ok=True)
        (args.out / f"{filename}.import").unlink(missing_ok=True)

    (args.out / "source_manifest.txt").write_text(
        "\n".join(manifest_lines) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
