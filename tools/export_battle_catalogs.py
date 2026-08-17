"""Monster template and wave construction."""

from __future__ import annotations

from export_pet_catalogs import *

def build_monster_templates(pets: dict[str, dict[str, object]]) -> dict[str, dict[str, object]]:
    monsters: dict[str, dict[str, object]] = {}
    for row in read_csv("02_monster_templates.csv"):
        pet_id = row.get("宠物ID", "").strip()
        if not pet_id:
            continue
        base = pet_from_row(row)
        base.update(
            {
                "source_pet_id": pet_id,
                "name": row.get("名称(自动)", base.get("name", pet_id)).strip() or pet_id,
                "element": row.get("元素(自动)", base.get("element", "")).strip(),
                "role": row.get("敌方定位", base.get("role", "敌方")).strip() or "敌方",
                "max_hp": max(1, as_int(row.get("HP"), int(base.get("max_hp", 1)))),
                "atk": max(0, as_int(row.get("攻"), int(base.get("atk", 0)))),
                "def": max(0, as_int(row.get("防"), int(base.get("def", 0)))),
                "shield": max(0, as_int(row.get("盾"), int(base.get("shield", 0)))),
                "ap": max(1, as_int(row.get("行动"), int(base.get("ap", 3)))),
                "move_range": max(0, as_int(row.get("移动力"), int(base.get("ap", 3)))),
                "attack_count": max(0, as_int(row.get("攻击次数"), int(base.get("ap", 3)))),
                "mechanism_id": row.get("机制ID", "").strip(),
                "mechanism_params": row.get("机制参数", "").strip(),
                "effect_score": as_int(row.get("面板分"), int(base.get("effect_score", 0))),
            }
        )
        monsters[pet_id] = base
    return monsters


def wave_from_row(row: dict[str, str], wave_count: int) -> dict[str, object]:
    pool, count = parse_wave_pool_count(row.get("宠物池-数量") or row.get("宠物ID"), as_int(row.get("数量"), 1))
    weights = parse_quality_weights(row.get("品质权重"))
    return {
        "id": row.get("波次ID", "wave_fallback"),
        "day": as_int(row.get("天数"), 1),
        "period": row.get("时段", "上午").strip() or "上午",
        "round": as_int(row.get("回合"), 1),
        "pool_expression": row.get("宠物池-数量", "").strip(),
        "monster_pool": pool,
        "spawn_count": count,
        "quality_weights": weights,
        "selected_quality": dominant_quality(weights),
        "wave_count": wave_count,
    }


def build_waves() -> list[dict[str, object]]:
    rows = read_csv("03_monster_waves.csv")
    return [wave_from_row(row, len(rows)) for row in rows]


def build_node_schedule() -> list[dict[str, object]]:
    schedule: list[dict[str, object]] = []
    for row in read_csv("24_node_schedule.csv"):
        schedule_id = row.get("schedule_id", "").strip()
        if not schedule_id:
            continue
        schedule.append(
            {
                "id": schedule_id,
                "day": as_int(row.get("day"), 1),
                "step": as_int(row.get("step"), 1),
                "kind": row.get("kind", "").strip(),
                "label": row.get("label", "").strip(),
                "poolId": row.get("pool_id", "").strip(),
                "choiceCount": max(1, as_int(row.get("choice_count"), 1)),
                "encounterPoolId": row.get("encounter_pool_id", "").strip(),
                "encounterId": row.get("encounter_id", "").strip(),
                "phaseLabel": row.get("phase_label", "").strip(),
                "status": row.get("status", "").strip(),
                "note": row.get("note", "").strip(),
            }
        )
    return schedule
