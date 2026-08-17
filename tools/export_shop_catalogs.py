"""Roster, offer, shop item, store, and mapping builders."""

from __future__ import annotations

from export_pet_catalogs import *

def build_pets() -> dict[str, dict[str, object]]:
    pets: dict[str, dict[str, object]] = {}
    for row in read_csv("01_pets.csv"):
        pet = pet_from_row(row)
        if pet["id"]:
            pets[str(pet["id"])] = pet
    return pets


def build_roster(pets: dict[str, dict[str, object]]) -> list[dict[str, object]]:
    roster: list[dict[str, object]] = []
    for row in read_csv("10_initial_roster.csv"):
        if not enabled(row.get("启用")):
            continue
        pet_id = row.get("宠物ID", "").strip()
        if pet_id not in pets:
            continue
        pet = dict(pets[pet_id])
        pet["quality"] = row.get("品质覆盖", "").strip() or pet.get("quality", "")
        pet["x"] = max(0, as_int(row.get("列(1-8)"), 1) - 1)
        pet["y"] = max(0, as_int(row.get("行(1-8)"), 1) - 1)
        roster.append(pet)
    if roster:
        return roster
    for index, pet_id in enumerate(list(pets.keys())[:3]):
        pet = dict(pets[pet_id])
        pet["x"] = index + 1
        pet["y"] = 6
        roster.append(pet)
    return roster


def build_shop_offers(pets: dict[str, dict[str, object]]) -> list[dict[str, object]]:
    return [
        offer_from_shop_item(item, index + 1, "night_base")
        for index, item in enumerate(shop_items_for_pool(build_shop_items(pets), "night_base", 1, 10))
    ]


def shop_item_from_row(row: dict[str, str], pets: dict[str, dict[str, object]]) -> dict[str, object]:
    pet_id = row.get("宠物ID", "").strip()
    pet = dict(pets.get(pet_id, {}))
    item = dict(pet)
    item.update(
        {
            "pet_id": pet_id,
            "name": row.get("名称(自动)", pet.get("name", pet_id)).strip() or pet_id,
            "element": row.get("元素(自动)", pet.get("element", "")).strip(),
            "quality": row.get("品质(自动)", pet.get("quality", "")).strip(),
            "role": row.get("定位(自动)", pet.get("role", "")).strip(),
            "tags": split_list(row.get("标签(自动)")),
            "item_type": row.get("商品类型", "").strip(),
            "status": row.get("商店状态", "").strip(),
            "unlock_day": as_int(row.get("解锁日"), 1),
            "pool_tier": row.get("池档", "").strip(),
            "default_price": as_int(row.get("默认价"), 2),
            "price": max(1, as_int(row.get("价格覆盖"), as_int(row.get("默认价"), 2))),
            "weights": {
                "night": as_int(row.get("夜市权重"), 0),
                "element": as_int(row.get("元素店权重"), 0),
                "role": as_int(row.get("定位店权重"), 0),
                "tier": as_int(row.get("品质店权重"), 0),
                "reward": as_int(row.get("奖励权重"), 0),
            },
            "shop_pools": split_list(row.get("商店池(自动)")),
            "reward_pools": split_list(row.get("奖励池(自动)")),
            "condition": row.get("出现条件", "").strip(),
            "note": row.get("备注", "").strip(),
        }
    )
    return item


def build_shop_items(pets: dict[str, dict[str, object]]) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    for row in read_csv("06_shop_rewards.csv"):
        if row.get("商品类型", "").strip() != "宠物":
            continue
        if not enabled(row.get("商店状态")):
            continue
        pet_id = row.get("宠物ID", "").strip()
        if pet_id not in pets:
            continue
        items.append(shop_item_from_row(row, pets))
    return items


def apply_bazaar_day1_route_nodes(node_pool: list[dict[str, object]]) -> None:
    if not BAZAAR_DAY1_CATALOG_PATH.exists():
        return
    supplement = json.loads(BAZAAR_DAY1_CATALOG_PATH.read_text(encoding="utf-8"))
    node_pool.extend(dict(row) for row in supplement.get("nodes", []))


def shop_weight(item: dict[str, object], pool_id: str) -> int:
    weights = dict(item.get("weights", {}))
    if pool_id == "night_base":
        return int(weights.get("night", 0))
    if pool_id.startswith("elem_"):
        return int(weights.get("element", 0))
    if pool_id.startswith("role_"):
        return int(weights.get("role", 0))
    if pool_id.startswith("tier_"):
        return int(weights.get("tier", 0))
    return int(weights.get("night", 0))


def shop_items_for_pool(items: list[dict[str, object]], pool_id: str, day: int, slots: int) -> list[dict[str, object]]:
    filtered = [
        item
        for item in items
        if int(item.get("unlock_day", 1)) <= day
        and pool_id in list(item.get("shop_pools", []))
        and shop_weight(item, pool_id) > 0
    ]
    filtered.sort(key=lambda item: (-shop_weight(item, pool_id), str(item.get("pet_id", ""))))
    return filtered[: max(0, slots)]


def offer_from_shop_item(item: dict[str, object], index: int, pool_id: str) -> dict[str, object]:
    offer = dict(item)
    offer["id"] = "shop_%03d" % index
    offer["offer_id"] = offer["id"]
    offer["pet_id"] = item.get("pet_id", item.get("id", ""))
    offer["pool_id"] = pool_id
    offer["price"] = max(1, int(item.get("price", item.get("default_price", 2))))
    offer["sold"] = False
    return offer


def build_shop_stores() -> list[dict[str, object]]:
    stores: list[dict[str, object]] = []
    for row in read_csv("30_shop_stores.csv"):
        store_id = row.get("shop_store_id", "").strip()
        if not store_id:
            continue
        stores.append(
            {
                "id": store_id,
                "name": row.get("name", "").strip(),
                "store_type": row.get("store_type", "").strip(),
                "tags": split_list(row.get("tags")),
                "default_slots": max(1, as_int(row.get("default_slots"), 10)),
                "unlock_day": as_int(row.get("unlock_day"), 1),
                "stall_count": max(1, as_int(row.get("stall_count"), 1)),
                "day1_stalls": max(0, as_int(row.get("day1_stalls"), 0)),
                "day2_stalls": max(0, as_int(row.get("day2_stalls"), 0)),
                "day3_stalls": max(0, as_int(row.get("day3_stalls"), 0)),
                "price_rule": row.get("price_rule", "").strip(),
                "status": row.get("status", "").strip(),
                "note": row.get("note", "").strip(),
            }
        )
    return stores


def build_shop_mapping() -> list[dict[str, object]]:
    mappings: list[dict[str, object]] = []
    for row in read_csv("35_bazaar_shop_mapping.csv"):
        stall_id = row.get("stall_id", "").strip()
        if not stall_id:
            continue
        mappings.append(
            {
                "id": stall_id,
                "source_node_type": row.get("source_node_type", "").strip(),
                "source_slug": row.get("source_slug", "").strip(),
                "source_name": row.get("source_name", "").strip(),
                "source_rule": row.get("source_rule", "").strip(),
                "source_object_count": max(0, as_int(row.get("source_object_count"), 0)),
                "unlock_day": max(1, as_int(row.get("unlock_day"), 1)),
                "close_day": max(0, as_int(row.get("close_day"), 0)),
                "day1_status": row.get("day1_status", "").strip(),
                "day2_status": row.get("day2_status", "").strip(),
                "day3_status": row.get("day3_status", "").strip(),
                "offer_slots": max(1, as_int(row.get("offer_slots"), 3)),
                "free_rerolls": max(0, as_int(row.get("free_rerolls"), 0)),
                "local_shop_id": row.get("local_shop_id", "").strip(),
                "local_shop_name": row.get("local_shop_name", "").strip(),
                "mapping_rule": row.get("mapping_rule", "").strip(),
            }
        )
    return mappings
