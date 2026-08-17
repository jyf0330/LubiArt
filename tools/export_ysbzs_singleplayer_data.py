#!/usr/bin/env python3
"""Export ysbzs source data directly into modular Godot content packages."""

from __future__ import annotations

from content_pack_exporter import export_content_pack
from export_battle_catalogs import *
from export_economy_catalogs import *
from export_route_catalogs import *
from export_rule_catalogs import *

def main() -> None:
    pets = build_pets()
    action_shapes = build_action_shapes()
    attach_action_shapes(pets, action_shapes)
    shop_items = build_shop_items(pets)
    shop_stores = build_shop_stores()
    shop_mapping = build_shop_mapping()
    bazaar_objects = build_bazaar_objects()
    events = build_events()
    relics = build_relics()
    monsters = build_monster_templates(pets)
    waves = attach_wave_enemies(build_waves(), pets, monsters)
    route_schedule = build_node_schedule()
    node_pool = build_node_pool()
    apply_bazaar_day1_route_nodes(node_pool)
    encounter_pool = build_encounter_pool()
    shape_catalog = build_shape_catalog()
    skill_catalog = build_skill_catalog()
    trait_catalog = build_trait_catalog()
    skill_combo_catalog = build_skill_combo_catalog()
    stat_catalog = build_stat_catalog()
    status_catalog = build_status_catalog()
    quality_growth = build_quality_growth()
    quality_upgrades = build_quality_upgrades()
    mechanisms = build_mechanisms()
    mechanism_status = build_mechanism_status(mechanisms)
    battle_rules = build_battle_rules()
    runtime_database = read_runtime_database()
    wave = next((row for row in waves if int(row["day"]) == 1 and row["period"] == "上午" and int(row["round"]) == 1), waves[0] if waves else {})
    enemies = list(wave.get("enemies", []))
    if not enemies:
        enemies = build_enemies(pets)
    payload = {
        "source": {
            "repo": str(YSBZS_ROOT),
            "files": [
                "data/csv/01_pets.csv",
                "data/csv/10_initial_roster.csv",
                "data/csv/05_events.csv",
                "data/csv/06_shop_rewards.csv",
                "data/csv/07_relic_blessings.csv",
                "data/csv/02_monster_templates.csv",
                "data/csv/03_monster_waves.csv",
                "data/csv/04_mechanisms.csv",
                "data/csv/08_action_shapes.csv",
                "data/csv/24_node_schedule.csv",
                "data/csv/25_node_pool.csv",
                "data/csv/26_encounter_pool.csv",
                "data/csv/27_shape_catalog.csv",
                "data/csv/28_quality_growth.csv",
                "data/csv/29_quality_upgrades.csv",
                "data/csv/30_shop_stores.csv",
                "data/csv/34_bazaar_objects.csv",
                "data/csv/35_bazaar_shop_mapping.csv",
                "data/csv/36_skill_catalog.csv",
                "data/csv/37_trait_catalog.csv",
                "data/csv/38_skill_combo_catalog.csv",
                "data/csv/39_stat_catalog.csv",
                "data/csv/40_status_catalog.csv",
                "data/csv/31_battle_rules.csv",
                "data/runtime/database.json",
                str(BAZAAR_DAY1_CATALOG_PATH.relative_to(GODOT_ROOT)),
            ],
            "runtime_database": str(RUNTIME_DATABASE_PATH),
        },
        "route_options": [
            {"id": "route_shop", "title": "宠物商店", "desc": "10 格宠物货架，购买后进入背包。", "kind": "shop"},
            {"id": "route_battle", "title": "遭遇战", "desc": "进入 8x8 棋盘，部署后击败敌人。", "kind": "battle"},
            {"id": "route_rest", "title": "整备", "desc": "恢复英雄 4 点生命并获得 2 金币。", "kind": "rest"},
        ],
        "player": {"coins": 16, "hero_hp": 80, "heroMaxHp": 80, "ap": 3},
        "roster": build_roster(pets),
        "shop_offers": [offer_from_shop_item(item, index + 1, "night_base") for index, item in enumerate(shop_items_for_pool(shop_items, "night_base", 1, 10))],
        "economy": {
            "shop_items": shop_items,
            "shop_stores": shop_stores,
            "shop_mapping": shop_mapping,
            "bazaar_objects": bazaar_objects,
            "events": events,
            "relics": relics,
        },
        "battle": {
            "rules": battle_rules,
            "wave": wave,
            "waves": waves,
            "enemies": enemies,
            "shape_catalog": shape_catalog,
            "action_shapes": list(action_shapes.values()),
            "mechanisms": mechanisms,
        },
        "skill_catalog": skill_catalog,
        "trait_catalog": trait_catalog,
        "skill_combo_catalog": skill_combo_catalog,
        "stat_catalog": stat_catalog,
        "status_catalog": status_catalog,
        "route": {"schedule": route_schedule, "node_pool": node_pool, "encounters": encounter_pool},
        "quality": {"growth": quality_growth, "upgrades": quality_upgrades},
        "mechanism_status": mechanism_status,
        "runtime_database": runtime_database,
    }
    package_count, operation_count = export_content_pack(
        payload, CONTENT_ROOT / "generated", CONTENT_ROOT / "extensions"
    )
    print(f"exported {CONTENT_ROOT} packages={package_count} operations={operation_count}")
    print(
        f"roster={len(payload['roster'])} shop_offers={len(payload['shop_offers'])} "
        f"waves={len(waves)} schedule={len(route_schedule)} node_pool={len(node_pool)} "
        f"encounters={len(encounter_pool)} shop_items={len(shop_items)} shop_stores={len(shop_stores)} "
        f"shop_mapping={len(shop_mapping)} bazaar_objects={len(bazaar_objects)} "
        f"events={len(events)} relics={len(relics)} shapes={len(shape_catalog)} skills={len(skill_catalog)} traits={len(trait_catalog)} "
        f"skill_combos={len(skill_combo_catalog)} stats={len(stat_catalog)} statuses={len(status_catalog)} action_shapes={len(action_shapes)} "
        f"mechanisms={len(mechanisms)} quality_growth={len(quality_growth)} quality_upgrades={len(quality_upgrades)} "
        f"battle_rules={len(battle_rules)} "
        f"runtime_db_tables={len(runtime_database.get('tables', {}))} "
        f"wave={wave.get('id', 'none')} enemies={len(payload['battle']['enemies'])}"
    )


if __name__ == "__main__":
    main()
