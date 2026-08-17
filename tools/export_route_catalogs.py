"""Route node, encounter, and wave-enemy builders."""

from __future__ import annotations

from export_battle_catalogs import *
from export_shop_catalogs import *

def build_node_pool() -> list[dict[str, object]]:
    nodes: list[dict[str, object]] = []
    for row in read_csv("25_node_pool.csv"):
        node_id = row.get("node_id", "").strip()
        if not node_id:
            continue
        nodes.append(
            {
                "nodeId": node_id,
                "nodePoolId": row.get("node_pool_id", "").strip(),
                "name": row.get("name", "").strip(),
                "nodeType": row.get("node_type", "").strip(),
                "weight": as_int(row.get("weight"), 0),
                "unlockDay": as_int(row.get("unlock_day"), 1),
                "shopPoolId": row.get("shop_pool_id", "").strip(),
                "rewardPoolId": row.get("reward_pool_id", "").strip(),
                "eventId": row.get("event_id", "").strip(),
                "slots": as_int(row.get("slots"), 0),
                "value": as_int(row.get("value"), 0),
                "status": row.get("status", "").strip(),
                "note": row.get("note", "").strip(),
            }
        )
    return nodes


def build_encounter_pool() -> list[dict[str, object]]:
    encounters: list[dict[str, object]] = []
    for row in read_csv("26_encounter_pool.csv"):
        encounter_id = row.get("encounter_id", "").strip()
        if not encounter_id:
            continue
        encounters.append(
            {
                "encounterId": encounter_id,
                "encounterPoolId": row.get("encounter_pool_id", "").strip(),
                "name": row.get("name", "").strip(),
                "weight": as_int(row.get("weight"), 0),
                "unlockDay": as_int(row.get("unlock_day"), 1),
                "wavePeriod": row.get("wave_period", "").strip(),
                "battleIndex": as_int(row.get("battle_index"), 1),
                "phaseLabel": row.get("phase_label", "").strip(),
                "status": row.get("status", "").strip(),
                "note": row.get("note", "").strip(),
            }
        )
    return encounters


def monster_key_for_wave_token(token: str, monsters: dict[str, dict[str, object]], monster_keys: list[str]) -> str:
    raw = str(token or "").strip()
    if not raw:
        return ""
    if raw in monsters:
        return raw
    if raw.isdigit():
        index = int(raw) - 1
        if 0 <= index < len(monster_keys):
            return monster_keys[index]
    normalized = normalize_pet_id_token(raw)
    if normalized in monsters:
        return normalized
    return ""


def build_wave_enemies(pets: dict[str, dict[str, object]], monsters: dict[str, dict[str, object]], wave: dict[str, object]) -> list[dict[str, object]]:
    pool = list(wave.get("monster_pool", []))
    monster_keys = list(monsters.keys())
    count = max(0, int(wave.get("spawn_count", 0)))
    quality = str(wave.get("selected_quality", "青铜"))
    positions = [(5, 1), (6, 2), (7, 1), (5, 3), (7, 3), (6, 0)]
    enemies: list[dict[str, object]] = []
    for index in range(count):
        token = pool[index % len(pool)] if pool else ""
        monster_id = monster_key_for_wave_token(str(token), monsters, monster_keys)
        base = dict(monsters.get(monster_id, {}))
        if not base:
            continue
        x, y = positions[index % len(positions)]
        base.update(
            {
                "id": "enemy_r%02d_%03d" % (int(wave.get("round", 1)), len(enemies) + 1),
                "source_monster_template_id": monster_id,
                "quality": quality,
                "x": x,
                "y": y,
            }
        )
        enemies.append(base)
    return enemies


def attach_wave_enemies(
    waves: list[dict[str, object]],
    pets: dict[str, dict[str, object]],
    monsters: dict[str, dict[str, object]],
) -> list[dict[str, object]]:
    expanded: list[dict[str, object]] = []
    for wave in waves:
        item = dict(wave)
        item["enemies"] = build_wave_enemies(pets, monsters, item)
        expanded.append(item)
    return expanded


def build_enemies(pets: dict[str, dict[str, object]]) -> list[dict[str, object]]:
    enemies: list[dict[str, object]] = []
    for row in read_csv("02_monster_templates.csv"):
        pet_id = row.get("宠物ID", "").strip()
        if not pet_id:
            continue
        base = dict(pets.get(pet_id, {}))
        if not base:
            base = pet_from_row(row)
        base.update(
            {
                "id": "enemy_%03d" % (len(enemies) + 1),
                "source_pet_id": pet_id,
                "name": row.get("名称(自动)", base.get("name", pet_id)).strip() or pet_id,
                "role": row.get("敌方定位", base.get("role", "敌方")).strip() or "敌方",
                "max_hp": max(1, as_int(row.get("HP"), int(base.get("max_hp", 1)))),
                "atk": max(0, as_int(row.get("攻"), int(base.get("atk", 0)))),
                "move_range": max(0, as_int(row.get("移动力"), int(base.get("ap", 3)))),
                "attack_count": max(0, as_int(row.get("攻击次数"), int(base.get("ap", 3)))),
                "x": 5 + (len(enemies) % 3),
                "y": 1 + (len(enemies) % 3),
            }
        )
        enemies.append(base)
        if len(enemies) >= 3:
            break
    return enemies
