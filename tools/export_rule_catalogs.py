"""Combo, shape, quality, and mechanism catalog builders."""

from __future__ import annotations

from export_common import *
from export_parsers import *

def build_action_shapes() -> dict[str, dict[str, object]]:
    action_shapes: dict[str, dict[str, object]] = {}
    for row in read_csv("08_action_shapes.csv"):
        pet_id = row.get("宠物ID", "").strip()
        if not pet_id:
            continue
        slot_elements = [
            row.get("槽1元素", "").strip(),
            row.get("槽2元素", "").strip(),
            row.get("槽3元素", "").strip(),
        ]
        slot_elements = [element for element in slot_elements if element]
        action_shapes[pet_id] = {
            "pet_id": pet_id,
            "name": row.get("名称(自动)", pet_id).strip() or pet_id,
            "element": row.get("元素(自动)", "").strip(),
            "role": row.get("定位(自动)", "").strip(),
            "shape_id": row.get("形状ID", "").strip(),
            "shape_name": row.get("形状名", "").strip(),
            "shape_class": row.get("形状分类", "").strip(),
            "hit_cells": max(1, as_int(row.get("命中格数"), 1)),
            "direction": row.get("方向", "").strip(),
            "slot_count": max(1, as_int(row.get("槽数"), 3)),
            "slot_elements": slot_elements,
            "base_layers": max(1, as_int(row.get("基础层数"), 1)),
            "action_type": row.get("行动类型", "").strip(),
            "skill": row.get("技能", "").strip(),
            "mechanism_id": row.get("机制ID", "").strip(),
            "mechanism_name": row.get("机制名(自动)", "").strip(),
            "status": row.get("接入状态", "").strip(),
            "note": row.get("备注", "").strip(),
        }
    return action_shapes


def build_quality_growth() -> list[dict[str, object]]:
    growth: list[dict[str, object]] = []
    for row in read_csv("28_quality_growth.csv"):
        quality = row.get("quality", "").strip()
        if not quality:
            continue
        growth.append(
            {
                "quality": quality,
                "label": row.get("label", quality).strip() or quality,
                "shape_size": max(1, as_int(row.get("shape_size"), 1)),
                "hp_bonus": as_int(row.get("hp_bonus"), 0),
                "atk_bonus": as_int(row.get("atk_bonus"), 0),
                "mechanic": row.get("mechanic", "").strip(),
                "description": row.get("description", "").strip(),
            }
        )
    return growth


def build_quality_upgrades() -> list[dict[str, object]]:
    upgrades: list[dict[str, object]] = []
    for row in read_csv("29_quality_upgrades.csv"):
        upgrade_id = row.get("upgrade_id", "").strip()
        if not upgrade_id:
            continue
        upgrades.append(
            {
                "id": upgrade_id,
                "name": row.get("name", upgrade_id).strip() or upgrade_id,
                "quality": row.get("quality", "").strip(),
                "category": row.get("category", "").strip(),
                "operation_level": row.get("operation_level", "").strip(),
                "allowed_shape_sizes": split_int_list(row.get("allowed_shape_sizes")),
                "effect": row.get("effect", "").strip(),
                "design_note": row.get("design_note", "").strip(),
                "runtime_status": row.get("runtime_status", "").strip(),
            }
        )
    return upgrades


def build_mechanisms() -> list[dict[str, object]]:
    mechanisms: list[dict[str, object]] = []
    for row in read_csv("04_mechanisms.csv"):
        mechanism_id = row.get("机制ID", "").strip()
        if not mechanism_id or not formal(row.get("状态")):
            continue
        web_runtime_status = WEB_MECHANIC_STATUS.get(mechanism_id, "unknown")
        godot_behavior_status = godot_mechanism_behavior_status(mechanism_id)
        godot_followup_group = godot_mechanism_followup_group(mechanism_id)
        mechanisms.append(
            {
                "id": mechanism_id,
                "number": row.get("机制编号", "").strip(),
                "name": row.get("机制名", mechanism_id).strip() or mechanism_id,
                "category": row.get("分类", "").strip(),
                "targets": row.get("适用对象", "").strip(),
                "trigger": row.get("触发", "").strip(),
                "condition": row.get("条件", "").strip(),
                "default_params": row.get("参数默认", "").strip(),
                "effect": row.get("效果", "").strip(),
                "log_template": row.get("日志模板", "").strip(),
                "score": as_int(row.get("机制分"), 0),
                "strength": row.get("强度", "").strip(),
                "status": row.get("状态", "").strip(),
                "runtime_status": row.get("接入状态", "").strip(),
                "web_runtime_status": web_runtime_status,
                "godot_behavior_status": godot_behavior_status,
                "godot_followup_group": godot_followup_group,
                "pet_enabled": enabled(row.get("宠物用")),
                "monster_enabled": enabled(row.get("怪物用")),
                "event_enabled": enabled(row.get("事件用")),
                "wave_enabled": enabled(row.get("波次用")),
                "note": row.get("备注", "").strip(),
            }
        )
    return mechanisms


def build_mechanism_status(mechanisms: list[dict[str, object]]) -> dict[str, object]:
    formal_by_id = {str(row.get("id", "")): row for row in mechanisms}
    by_id: dict[str, dict[str, object]] = {}
    for mechanism_id in sorted(set(WEB_MECHANIC_STATUS) | set(formal_by_id)):
        formal_row = formal_by_id.get(mechanism_id, {})
        by_id[mechanism_id] = {
            "id": mechanism_id,
            "formal_exported": bool(formal_row),
            "runtime_status": str(formal_row.get("runtime_status", "")),
            "web_runtime_status": WEB_MECHANIC_STATUS.get(mechanism_id, "unknown"),
            "godot_behavior_status": godot_mechanism_behavior_status(mechanism_id),
            "godot_followup_group": godot_mechanism_followup_group(mechanism_id),
        }
    return {
        "by_id": by_id,
        "web_runtime": count_values(list(by_id.values()), "web_runtime_status"),
        "godot_behavior": count_values(list(by_id.values()), "godot_behavior_status"),
        "godot_followup_group": count_values(list(by_id.values()), "godot_followup_group"),
    }


def attach_action_shapes(
    pets: dict[str, dict[str, object]],
    action_shapes: dict[str, dict[str, object]],
) -> None:
    for pet_id, pet in pets.items():
        shape = action_shapes.get(pet_id)
        if not shape:
            continue
        pet["shape_id"] = shape.get("shape_id", "")
        pet["shape_name"] = shape.get("shape_name", "")
        pet["shape_class"] = shape.get("shape_class", "")
        pet["hit_cells"] = shape.get("hit_cells", 1)
        pet["slot_count"] = shape.get("slot_count", 3)
        pet["slot_elements"] = list(shape.get("slot_elements", []))
        pet["base_layers"] = shape.get("base_layers", 1)
        pet["action_type"] = shape.get("action_type", "")
        pet["mechanism_id"] = shape.get("mechanism_id", "")
        if shape.get("shape_name"):
            pet["shape"] = shape["shape_name"]
        if shape.get("skill"):
            pet["skill"] = shape["skill"]
