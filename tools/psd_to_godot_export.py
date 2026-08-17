#!/usr/bin/env python3
"""Export a Photoshop PSD into Godot-friendly UI assets and layout metadata."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from psd_tools import PSDImage


TEXT_HINTS = {
    "txt",
    "text",
    "label",
    "hp",
    "ap",
    "cost",
    "value",
}

TEXT_VALUES = {
    "方向",
    "消耗AP",
    "行动",
    "不可用",
    "向右",
    "暂无可用目标",
    "风槽1",
    "风槽2",
    "风槽3",
    "3层",
    "未用",
    "当前形状",
    "效果",
    "右侧隔两格",
    "形状03/一格",
    "阻挡",
    "结算3次",
    "技能",
    "castleReduce",
    "机制",
    "首击免疫",
    "捣蛋猫",
    "青铜",
    "小型坦克",
}


TRANSLATIONS = {
    "Background": "bg_battle_main",
    "方向": "label_direction",
    "消耗AP": "label_ap_cost",
    "行动": "label_action",
    "不可用": "label_unavailable",
    "向右": "label_move_right",
    "暂无可用目标": "label_no_target",
    "方块": "card_wind_slot_01",
    "方块 copy": "card_wind_slot_02",
    "方块 copy 2": "card_wind_slot_03",
    "风槽1": "label_wind_slot_01",
    "风槽2": "label_wind_slot_02",
    "风槽3": "label_wind_slot_03",
    "3层": "txt_stack_count",
    "未用": "label_unused",
    "当前形状": "label_current_shape",
    "效果": "label_effect",
    "右侧隔两格": "label_right_two_cells",
    "形状03/一格": "label_shape_03_one_cell",
    "阻挡": "label_block",
    "结算3次": "label_resolve_three_times",
    "技能": "label_skill",
    "castleReduce": "label_skill_castle_reduce",
    "机制": "label_mechanic",
    "首击免疫": "label_first_hit_immunity",
    "攻": "label_attack",
    "防": "label_defense",
    "盾": "label_shield",
    "移": "label_move",
    "捣蛋猫": "label_enemy_name",
    "青铜": "label_rank_bronze",
    "小型坦克": "label_enemy_type_tank",
    "风": "label_element_wind",
}


GROUP_TRANSLATIONS = {
    "1": "enemy_area",
    "2": "player_status",
    "3": "player_stats",
    "4": "enemy_mechanic",
    "5": "current_shape_panel",
    "6": "card_slots",
    "7": "target_hint",
    "8": "action_panel",
}


@dataclass
class LayerRecord:
    index: int
    source_name: str
    export_name: str
    kind: str
    role: str
    visible: bool
    bbox: tuple[int, int, int, int]
    parent_path: list[str]
    export_path: str | None
    node_name: str


def sanitize_name(name: str, fallback: str) -> str:
    translated = TRANSLATIONS.get(name) or name
    translated = translated.strip().lower()
    translated = re.sub(r"copy\s*(\d*)", r"copy_\1", translated)
    translated = re.sub(r"[^a-z0-9]+", "_", translated)
    translated = re.sub(r"_+", "_", translated).strip("_")
    return translated or fallback


def group_slug(layer) -> str:
    parent_path = iter_parent_path(layer)
    for name in reversed(parent_path):
        slug = sanitize_name(GROUP_TRANSLATIONS.get(name, name), "")
        if slug:
            return slug
    return "screen"


def is_photoshop_default_name(name: str, slug: str) -> bool:
    if re.search(r"图层\s*\d+", name):
        return True
    return bool(re.fullmatch(r"\d+(?:_copy_?\d*)?", slug))


def make_export_base_name(layer, index: int) -> str:
    translated = TRANSLATIONS.get(layer.name)
    if translated:
        return sanitize_name(translated, f"layer_{index:03d}")

    if re.fullmatch(r"\d+(/\d+)?", layer.name.strip()):
        return f"txt_value_{index:03d}"

    slug = sanitize_name(layer.name, f"layer_{index:03d}")
    if is_photoshop_default_name(layer.name, slug):
        return f"{group_slug(layer)}_layer_{index:03d}"
    return slug


def pascal_case(name: str) -> str:
    return "".join(part.capitalize() for part in name.split("_") if part)


def is_text_like(layer_name: str, export_name: str, layer_kind: str) -> bool:
    if layer_kind == "type":
        return True
    if layer_name in TEXT_VALUES:
        return True
    if re.fullmatch(r"\d+(/\d+)?", layer_name.strip()):
        return True
    parts = set(export_name.split("_"))
    return bool(parts & TEXT_HINTS)


def role_for(layer_name: str, export_name: str, layer_kind: str) -> str:
    if export_name.startswith("bg_"):
        return "background"
    if export_name.startswith("btn_"):
        return "button_asset"
    if export_name.startswith("panel_") or export_name.startswith("nine_"):
        return "panel_asset"
    if export_name.startswith("icon_") or export_name.startswith("asset_"):
        return "image_asset"
    if export_name.startswith("label_") or export_name.startswith("txt_"):
        return "godot_label"
    if is_text_like(layer_name, export_name, layer_kind):
        return "godot_label"
    return "image_asset"


def iter_parent_path(layer) -> list[str]:
    names: list[str] = []
    parent = getattr(layer, "parent", None)
    while parent is not None and hasattr(parent, "name"):
        if parent.name:
            names.append(parent.name)
        parent = getattr(parent, "parent", None)
    names.reverse()
    return names


def unique_names(raw_names: Iterable[str]) -> list[str]:
    seen: Counter[str] = Counter()
    result: list[str] = []
    for raw in raw_names:
        seen[raw] += 1
        if seen[raw] == 1:
            result.append(raw)
        else:
            result.append(f"{raw}_{seen[raw]:02d}")
    return result


def export(psd_path: Path, out_dir: Path, screen_name: str) -> None:
    psd = PSDImage.open(psd_path)

    preview_dir = out_dir / "preview"
    export_dir = out_dir / "export" / "ui" / screen_name
    layout_dir = out_dir / "layout"
    notes_dir = out_dir / "notes"
    for directory in (preview_dir, export_dir, layout_dir, notes_dir):
        directory.mkdir(parents=True, exist_ok=True)

    composite = psd.composite(force=True)
    preview_path = preview_dir / f"{screen_name}_ref.png"
    composite.save(preview_path)

    leaf_layers = [layer for layer in psd.descendants() if not layer.is_group()]
    base_names = [make_export_base_name(layer, index) for index, layer in enumerate(leaf_layers, 1)]
    export_names = unique_names(base_names)

    records: list[LayerRecord] = []
    role_counts: Counter[str] = Counter()
    skipped_counts: Counter[str] = Counter()
    duplicate_sources: defaultdict[str, list[str]] = defaultdict(list)

    for index, (layer, export_name) in enumerate(zip(leaf_layers, export_names), 1):
        bbox = tuple(int(value) for value in layer.bbox)
        layer_kind = getattr(layer, "kind", "unknown")
        kind = str(layer_kind)
        role = role_for(layer.name, export_name, kind)
        role_counts[role] += 1
        parent_path = iter_parent_path(layer)

        export_rel: str | None = None
        should_export = layer.is_visible() and role != "godot_label" and bbox[2] > bbox[0] and bbox[3] > bbox[1]
        if should_export:
            image = layer.composite()
            if image is None:
                skipped_counts["empty_composite"] += 1
            else:
                asset_path = export_dir / f"{export_name}.png"
                image.save(asset_path)
                export_rel = str(asset_path.relative_to(out_dir))
                duplicate_sources[layer.name].append(export_rel)
        else:
            if not layer.is_visible():
                skipped_counts["hidden"] += 1
            elif role == "godot_label":
                skipped_counts["godot_label"] += 1
            else:
                skipped_counts["empty_bbox"] += 1

        node_prefix = {
            "godot_label": "Label",
            "button_asset": "Button",
            "background": "Texture",
            "panel_asset": "Panel",
            "image_asset": "Texture",
        }.get(role, "Node")
        node_name = pascal_case(export_name)
        if role == "godot_label" and not node_name.endswith("Label"):
            node_name = f"{node_name}Label"
        elif role == "button_asset" and not node_name.endswith("Button"):
            node_name = f"{node_name}Button"
        elif role in {"background", "panel_asset", "image_asset"} and node_name:
            node_name = f"{node_name}{node_prefix}Rect"

        records.append(
            LayerRecord(
                index=index,
                source_name=layer.name,
                export_name=export_name,
                kind=kind,
                role=role,
                visible=layer.is_visible(),
                bbox=bbox,
                parent_path=parent_path,
                export_path=export_rel,
                node_name=node_name,
            )
        )

    layout = {
        "source_psd": str(psd_path),
        "screen_name": screen_name,
        "canvas": {"width": int(psd.width), "height": int(psd.height)},
        "preview": str(preview_path.relative_to(out_dir)),
        "summary": {
            "leaf_layers": len(leaf_layers),
            "visible_leaf_layers": sum(1 for layer in leaf_layers if layer.is_visible()),
            "exported_assets": sum(1 for record in records if record.export_path),
            "roles": dict(sorted(role_counts.items())),
            "skipped": dict(sorted(skipped_counts.items())),
        },
        "layers": [
            {
                "index": record.index,
                "source_name": record.source_name,
                "export_name": record.export_name,
                "kind": record.kind,
                "role": record.role,
                "visible": record.visible,
                "bbox": {
                    "x": record.bbox[0],
                    "y": record.bbox[1],
                    "width": record.bbox[2] - record.bbox[0],
                    "height": record.bbox[3] - record.bbox[1],
                    "x2": record.bbox[2],
                    "y2": record.bbox[3],
                },
                "parent_path": record.parent_path,
                "export_path": record.export_path,
                "suggested_godot_node": record.node_name,
            }
            for record in records
        ],
    }
    layout_path = layout_dir / f"{screen_name}_layers.json"
    layout_path.write_text(json.dumps(layout, ensure_ascii=False, indent=2), encoding="utf-8")

    mapping_path = layout_dir / f"{screen_name}_name_mapping.csv"
    with mapping_path.open("w", encoding="utf-8") as handle:
        handle.write("index,source_name,export_name,role,visible,bbox,export_path,suggested_godot_node\n")
        for record in records:
            bbox_text = " ".join(str(value) for value in record.bbox)
            export_path_text = record.export_path or ""
            row = [
                str(record.index),
                record.source_name.replace('"', '""'),
                record.export_name,
                record.role,
                str(record.visible).lower(),
                bbox_text,
                export_path_text,
                record.node_name,
            ]
            handle.write(",".join(f'"{value}"' for value in row) + "\n")

    note_path = notes_dir / f"{screen_name}_notes.md"
    note_path.write_text(
        "\n".join(
            [
                f"# {screen_name} PSD 转换记录",
                "",
                f"- 源 PSD：`{psd_path}`",
                f"- 画布：`{psd.width}x{psd.height}`",
                f"- 图层：`{len(leaf_layers)}` 个叶子图层，`{layout['summary']['visible_leaf_layers']}` 个可见叶子图层",
                f"- 已导出图片资产：`{layout['summary']['exported_assets']}` 个",
                f"- 整屏参考图：`{preview_path.relative_to(out_dir)}`",
                f"- 布局 JSON：`{layout_path.relative_to(out_dir)}`",
                f"- 命名映射：`{mapping_path.relative_to(out_dir)}`",
                "",
                "## Godot 重建提醒",
                "",
                "- `godot_label` 角色不要直接使用导出的图片，应在 Godot 里创建 `Label` 或 `RichTextLabel`。",
                "- `image_asset`、`panel_asset`、`background` 可以作为 `TextureRect` / `NinePatchRect` 的纹理。",
                "- 按钮需要人工确认点击区域和状态图；当前脚本只根据命名和图层信息做初步分类。",
                "- 当前 PSD 的中文图层名已经在映射表里转换成 ASCII 建议名，后续美术应直接按规则命名。",
                "",
            ]
        ),
        encoding="utf-8",
    )

    print(json.dumps(layout["summary"], ensure_ascii=False, indent=2))
    print(f"preview={preview_path}")
    print(f"layout={layout_path}")
    print(f"mapping={mapping_path}")
    print(f"notes={note_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("psd", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--screen-name", default="battle_main")
    args = parser.parse_args()
    export(args.psd.expanduser().resolve(), args.out.expanduser().resolve(), args.screen_name)


if __name__ == "__main__":
    main()
