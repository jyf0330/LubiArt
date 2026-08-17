"""Pet, skill, trait, stat, and status catalog builders."""

from __future__ import annotations

from export_common import *
from export_parsers import *

def required_pet_stat(row: dict[str, str], field: str, pet_id: str, minimum: int) -> int:
    raw = str(row.get(field, "")).strip()
    if not raw:
        raise ValueError(f"pet {pet_id} missing required base stat {field}")
    try:
        numeric = float(raw)
    except ValueError as exc:
        raise ValueError(f"pet {pet_id} has non-numeric base stat {field}: {raw}") from exc
    value = int(numeric)
    if numeric != value or value < minimum:
        raise ValueError(f"pet {pet_id} has invalid base stat {field}: {raw}")
    return value


def pet_from_row(row: dict[str, str]) -> dict[str, object]:
    pet_id = row.get("宠物ID", "").strip()
    tags = [item.strip() for item in row.get("标签", "").replace("，", "、").split("、") if item.strip()]
    role = row.get("定位", "").strip()
    if not role and tags:
        role = tags[1] if len(tags) > 1 else tags[0]
    elements = pet_elements(row)
    max_hp = required_pet_stat(row, "HP", pet_id, 1)
    atk = required_pet_stat(row, "攻", pet_id, 0)
    defense = required_pet_stat(row, "防", pet_id, 0)
    starting_shield = required_pet_stat(row, "盾", pet_id, 0)
    action_points = required_pet_stat(row, "行动", pet_id, 1)
    return {
        "id": pet_id,
        "name": row.get("名称", row.get("名称(自动)", pet_id)).strip() or pet_id,
        "element": elements[0],
        "element_types": elements,
        "secondary_elements": elements[1:],
        "quality": row.get("品质", row.get("品质(自动)", "")).strip(),
        "role": role,
        "tags": tags,
        "max_hp": max_hp,
        "atk": atk,
        "def": defense,
        "shield": starting_shield,
        "ap": action_points,
        "base_stats": {
            "max_hp": max_hp,
            "atk": atk,
            "def": defense,
            "starting_shield": starting_shield,
            "action_points": action_points,
        },
        "skill": row.get("技能", "").strip(),
        "skills": split_list(row.get("技能序列", "")),
        "traits": split_list(row.get("特性序列", "")),
        "shape": row.get("形状", "").strip(),
        "range": row.get("范围", "").strip(),
        "effect_score": as_int(row.get("效果分"), as_int(row.get("面板分"), 0)),
    }


def build_shape_catalog() -> list[dict[str, object]]:
    shapes: list[dict[str, object]] = []
    for row in read_csv("27_shape_catalog.csv"):
        shape_id = row.get("shape_id", "").strip()
        if not shape_id:
            continue
        shapes.append(
            {
                "shape_id": shape_id,
                "group": row.get("group", "").strip(),
                "label": row.get("label", shape_id).strip() or shape_id,
                "cell_count": max(1, as_int(row.get("cell_count"), 1)),
                "settle_count": max(1, as_int(row.get("settle_count"), 1)),
                "offsets": parse_offsets(row.get("offsets")),
                "grid": row.get("grid", "").strip(),
                "note": row.get("note", "").strip(),
            }
        )
    return shapes


def build_skill_catalog() -> dict[str, dict[str, object]]:
    catalog: dict[str, dict[str, object]] = {}
    for order_index, row in enumerate(read_csv("36_skill_catalog.csv")):
        skill_id = row.get("skill_id", "").strip()
        enabled = row.get("enabled", "true").strip().lower()
        if not skill_id or enabled not in {"1", "true", "yes", "是"}:
            continue
        try:
            effects = json.loads(row.get("effects_json", "[]"))
        except json.JSONDecodeError as exc:
            raise ValueError(f"invalid effects_json for skill {skill_id}: {exc}") from exc
        if not isinstance(effects, list):
            raise ValueError(f"effects_json must be an array for skill {skill_id}")
        catalog[skill_id] = {
            "id": skill_id,
            "name": row.get("name", skill_id).strip() or skill_id,
            "order_index": order_index,
            "effects": effects,
            "shape_slot": max(0, as_int(row.get("shape_slot"), 0)),
            "element_source": row.get("element_source", "primary").strip() or "primary",
            "duration_ticks": max(0, as_int(first_value(row, "duration_ticks", "逻辑耗时"), 0)),
            "tags": split_list(row.get("tags", "").replace("|", ",")),
            "note": row.get("note", "").strip(),
        }
    return catalog


def build_trait_catalog() -> dict[str, dict[str, object]]:
    catalog: dict[str, dict[str, object]] = {}
    for order_index, row in enumerate(read_csv("37_trait_catalog.csv")):
        trait_id = row.get("trait_id", "").strip()
        if not trait_id or not enabled(row.get("enabled", "true")):
            continue
        try:
            effects = json.loads(row.get("effects_json", "[]"))
        except json.JSONDecodeError as exc:
            raise ValueError(f"invalid effects_json for trait {trait_id}: {exc}") from exc
        if not isinstance(effects, list):
            raise ValueError(f"effects_json must be an array for trait {trait_id}")
        catalog[trait_id] = {
            "id": trait_id,
            "name": row.get("name", trait_id).strip() or trait_id,
            "order_index": order_index,
            "effects": effects,
            "description": row.get("description", "").strip(),
            "note": row.get("note", "").strip(),
        }
    return catalog


def build_stat_catalog() -> dict[str, dict[str, object]]:
    catalog: dict[str, dict[str, object]] = {}
    for order_index, row in enumerate(read_csv("39_stat_catalog.csv")):
        stat_id = row.get("stat_id", "").strip()
        if not stat_id:
            continue
        catalog[stat_id] = {
            "id": stat_id,
            "name": row.get("name", stat_id).strip() or stat_id,
            "order_index": order_index,
            "category": row.get("category", "custom").strip() or "custom",
            "value_type": row.get("value_type", "integer").strip() or "integer",
            "default_value": as_int(row.get("default_value"), 0),
            "min_value": as_int(row.get("min_value"), -2147483648),
            "max_value": as_int(row.get("max_value"), 2147483647),
            "display_unit": row.get("display_unit", "").strip(),
            "stacking_rule": row.get("stacking_rule", "flat_percent_multiplier_override_clamp").strip(),
            "description": row.get("description", "").strip(),
        }
    return catalog


def build_status_catalog() -> dict[str, dict[str, object]]:
    catalog: dict[str, dict[str, object]] = {}
    for order_index, row in enumerate(read_csv("40_status_catalog.csv")):
        status_id = row.get("status_id", "").strip()
        if not status_id:
            continue
        try:
            effects = json.loads(row.get("effects_json", "[]"))
        except json.JSONDecodeError as exc:
            raise ValueError(f"invalid effects_json for status {status_id}: {exc}") from exc
        if not isinstance(effects, list):
            raise ValueError(f"effects_json must be an array for status {status_id}")
        catalog[status_id] = {
            "id": status_id,
            "name": row.get("name", status_id).strip() or status_id,
            "order_index": order_index,
            "polarity": row.get("polarity", "neutral").strip() or "neutral",
            "max_stacks": max(1, as_int(row.get("max_stacks"), 1)),
            "duration_policy": row.get("duration_policy", "refresh").strip() or "refresh",
            "default_duration": max(1, as_int(row.get("default_duration"), 1)),
            "effects": effects,
            "description": row.get("description", "").strip(),
        }
    return catalog


def build_skill_combo_catalog() -> dict[str, dict[str, object]]:
    catalog: dict[str, dict[str, object]] = {}
    for order_index, row in enumerate(read_csv("38_skill_combo_catalog.csv")):
        combo_id = row.get("combo_id", "").strip()
        if not combo_id or not enabled(row.get("enabled", "true")):
            continue
        try:
            pattern = json.loads(row.get("pattern_json", "[]"))
            effects = json.loads(row.get("effects_json", "[]"))
        except json.JSONDecodeError as exc:
            raise ValueError(f"invalid combo JSON for {combo_id}: {exc}") from exc
        if not isinstance(pattern, list) or not isinstance(effects, list):
            raise ValueError(f"pattern_json and effects_json must be arrays for combo {combo_id}")
        catalog[combo_id] = {
            "id": combo_id,
            "name": row.get("name", combo_id).strip() or combo_id,
            "order_index": order_index,
            "match_type": row.get("match_type", "skill_ids").strip() or "skill_ids",
            "pattern": pattern,
            "effects": effects,
            "shape_slot": max(0, as_int(row.get("shape_slot"), 0)),
            "element_source": row.get("element_source", "primary").strip() or "primary",
            "note": row.get("note", "").strip(),
        }
    return catalog
