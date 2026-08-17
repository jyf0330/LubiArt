#!/usr/bin/env python3
"""Generate a Godot 4 Control scene from exported PSD layout metadata."""

from __future__ import annotations

import argparse
import json
import re
import shutil
from collections import Counter
from pathlib import Path


def pascal_case(name: str) -> str:
    return "".join(part.capitalize() for part in re.split(r"[^a-zA-Z0-9]+", name) if part)


def escape_tscn_text(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def unique_node_name(base: str, seen: Counter[str]) -> str:
    base = base or "Node"
    seen[base] += 1
    if seen[base] == 1:
        return base
    return f"{base}{seen[base]:02d}"


def generate(layout_path: Path, project_root: Path, out_scene: Path, asset_root: Path) -> None:
    layout = json.loads(layout_path.read_text(encoding="utf-8"))
    delivery_root = layout_path.parents[1]
    canvas = layout["canvas"]
    screen_name = layout["screen_name"]

    asset_root.mkdir(parents=True, exist_ok=True)
    out_scene.parent.mkdir(parents=True, exist_ok=True)

    exported_layers = [layer for layer in layout["layers"] if layer.get("export_path")]
    copied_assets: dict[str, str] = {}
    for layer in exported_layers:
        src = delivery_root / layer["export_path"]
        dst = asset_root / src.name
        shutil.copy2(src, dst)
        copied_assets[layer["export_path"]] = "res://" + str(dst.relative_to(project_root)).replace("\\", "/")

    ext_ids: dict[str, str] = {}
    for index, layer in enumerate(exported_layers, 1):
        ext_ids[layer["export_path"]] = f"{index}_{layer['export_name'][:18]}"

    lines: list[str] = []
    lines.append(f'[gd_scene load_steps={len(exported_layers) + 1} format=3]')
    lines.append("")
    for layer in exported_layers:
        ext_id = ext_ids[layer["export_path"]]
        res_path = copied_assets[layer["export_path"]]
        lines.append(f'[ext_resource type="Texture2D" path="{res_path}" id="{ext_id}"]')
    lines.append("")
    lines.append(f'[node name="{pascal_case(screen_name)}Mockup" type="Control"]')
    lines.append("layout_mode = 3")
    lines.append("anchors_preset = 0")
    lines.append(f"offset_right = {float(canvas['width'])}")
    lines.append(f"offset_bottom = {float(canvas['height'])}")
    lines.append("")

    seen: Counter[str] = Counter()
    for layer in layout["layers"]:
        bbox = layer["bbox"]
        if not layer["visible"]:
            continue
        if layer.get("export_path"):
            base = layer.get("suggested_godot_node") or pascal_case(layer["export_name"])
            node_name = unique_node_name(base, seen)
            lines.append(f'[node name="{node_name}" type="TextureRect" parent="."]')
            lines.append("layout_mode = 0")
            lines.append(f"offset_left = {float(bbox['x'])}")
            lines.append(f"offset_top = {float(bbox['y'])}")
            lines.append(f"offset_right = {float(bbox['x2'])}")
            lines.append(f"offset_bottom = {float(bbox['y2'])}")
            lines.append(f'texture = ExtResource("{ext_ids[layer["export_path"]]}")')
            lines.append("stretch_mode = 0")
            lines.append("")
        elif layer["role"] == "godot_label":
            base = layer.get("suggested_godot_node") or pascal_case(layer["export_name"]) + "Label"
            node_name = unique_node_name(base, seen)
            text = escape_tscn_text(layer["source_name"])
            lines.append(f'[node name="{node_name}" type="Label" parent="."]')
            lines.append("layout_mode = 0")
            lines.append(f"offset_left = {float(bbox['x'])}")
            lines.append(f"offset_top = {float(bbox['y'])}")
            lines.append(f"offset_right = {float(bbox['x2'])}")
            lines.append(f"offset_bottom = {float(bbox['y2'])}")
            lines.append(f'text = "{text}"')
            lines.append("horizontal_alignment = 1")
            lines.append("vertical_alignment = 1")
            lines.append("")

    out_scene.write_text("\n".join(lines), encoding="utf-8")
    print(f"scene={out_scene}")
    print(f"assets={asset_root}")
    print(f"copied_assets={len(exported_layers)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("layout", type=Path)
    parser.add_argument("--project-root", type=Path, default=Path("."))
    parser.add_argument("--out-scene", type=Path, required=True)
    parser.add_argument("--asset-root", type=Path, required=True)
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    generate(
        args.layout.resolve(),
        project_root,
        (project_root / args.out_scene).resolve(),
        (project_root / args.asset_root).resolve(),
    )


if __name__ == "__main__":
    main()
