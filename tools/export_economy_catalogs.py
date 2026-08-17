"""Bazaar object, event, and relic catalog builders."""

from __future__ import annotations

from export_shop_catalogs import *

def build_bazaar_objects() -> list[dict[str, object]]:
    objects: list[dict[str, object]] = []
    for row in read_csv("34_bazaar_objects.csv"):
        object_id = row.get("object_id", "").strip()
        if not object_id:
            continue
        objects.append(
            {
                "id": object_id,
                "object_no": max(1, as_int(row.get("object_no"), 1)),
                "source_type": row.get("source_type", "").strip(),
                "source_status": row.get("source_status", "").strip(),
                "source_slug": row.get("source_slug", "").strip(),
                "source_name": row.get("source_name", "").strip(),
                "source_tier": row.get("source_tier", "").strip(),
                "source_size": row.get("source_size", "").strip(),
                "source_tags": split_list(row.get("source_tags")),
                "source_relation_count": max(0, as_int(row.get("source_relation_count"), 0)),
                "source_stall_ids": split_list(row.get("source_stall_ids")),
                "local_shop_count": max(0, as_int(row.get("local_shop_count"), 0)),
                "local_shop_ids": split_list(row.get("local_shop_ids")),
                "primary_enchant": row.get("primary_enchant", "").strip(),
                "pet_id": row.get("pet_id", "").strip(),
                "pet_name": row.get("pet_name", "").strip(),
                "source_url": row.get("source_url", "").strip(),
                "source_effect": row.get("source_effect", "").strip(),
                "design_note": row.get("design_note", "").strip(),
            }
        )
    return objects


def build_events() -> list[dict[str, object]]:
    events: list[dict[str, object]] = []
    for row in read_csv("05_events.csv"):
        event_id = row.get("事件ID", "").strip()
        if not event_id:
            continue
        if not formal(row.get("状态", "")):
            continue
        temporary_text = " ".join(
            row.get(key, "").strip()
            for key in ["事件名", "选项文案", "收益", "备注"]
        )
        if "临时构筑补强" in temporary_text:
            continue
        events.append(
            {
                "id": event_id,
                "group": row.get("事件组", "").strip(),
                "name": row.get("事件名", event_id).strip() or event_id,
                "node": row.get("节点", "").strip(),
                "day_expr": row.get("天数", "").strip(),
                "option_id": row.get("选项ID", "").strip(),
                "option_text": row.get("选项文案", "").strip(),
                "pet_id": row.get("宠物ID", "").strip(),
                "pet_name": row.get("名称(自动)", "").strip(),
                "element": row.get("元素(自动)", "").strip(),
                "role": row.get("定位(自动)", "").strip(),
                "mechanism_id": row.get("机制ID", "").strip(),
                "mechanism_name": row.get("机制名(自动)", "").strip(),
                "shop_pool_id": row.get("商店池ID", "").strip(),
                "reward_pool_id": row.get("奖励池ID", "").strip(),
                "cost": row.get("代价", "").strip(),
                "gain": row.get("收益", "").strip(),
                "value": as_int(row.get("数值"), 0),
                "layer": row.get("接入层级", "").strip(),
                "status": row.get("状态", "").strip(),
                "note": row.get("备注", "").strip(),
            }
        )
    return events


def build_relics() -> list[dict[str, object]]:
    relics: list[dict[str, object]] = []
    for order_index, row in enumerate(read_csv("07_relic_blessings.csv")):
        relic_id = row.get("遗物ID", "").strip()
        if not relic_id:
            continue
        trigger = row.get("触发", "").strip()
        effects = parse_json_list(first_value(row, "effects_json", "效果JSON"), "effects_json", relic_id)
        charges = parse_json_list(first_value(row, "charges_json", "充能JSON"), "charges_json", relic_id)
        emit_events = parse_json_list(first_value(row, "emit_events_json", "触发事件JSON"), "emit_events_json", relic_id)
        cooldown_ticks = max(0, as_int(first_value(row, "cooldown_ticks", "冷却时间单位"), 0))
        relics.append(
            {
                "id": relic_id,
                "name": row.get("遗物名", relic_id).strip() or relic_id,
                "order_index": order_index,
                "relic_type": row.get("类型", "遗物").strip() or "遗物",
                "quality": row.get("品质", "").strip(),
                "trigger": trigger,
                "trigger_type": RELIC_TRIGGER_TYPES.get(trigger, trigger.upper()),
                "mechanism_id": row.get("机制ID", "").strip(),
                "mechanism_name": row.get("机制名(自动)", "").strip(),
                "parameters_raw": row.get("参数", "").strip(),
                "source_unit_id": row.get("关联宠物ID", "").strip(),
                "source_unit_name": row.get("名称(自动)", "").strip(),
                "shop_pools": split_list(row.get("关联商店池")),
                "reward_pools": split_list(row.get("关联奖励池")),
                "unlock_day": max(1, as_int(row.get("解锁日"), 1)),
                "weight": max(0, as_int(row.get("权重"), 0)),
                "status": row.get("状态", "").strip(),
                "note": row.get("备注", "").strip(),
                "cooldown_ticks": cooldown_ticks,
                "duration_ticks": max(0, as_int(first_value(row, "duration_ticks", "逻辑耗时"), 0)),
                "internal_cooldown_ticks": max(0, as_int(first_value(row, "internal_cooldown_ticks", "内部冷却时间单位"), 0)),
                "priority": as_int(first_value(row, "priority", "事件优先级"), 0),
                "max_triggers_per_tick": max(0, as_int(first_value(row, "max_triggers_per_tick", "单时刻触发上限"), 0)),
                "timer_enabled": enabled(first_value(row, "timer_enabled", "启用定时")) or cooldown_ticks > 0,
                "effects": effects,
                "charges": charges,
                "emit_events": emit_events,
            }
        )
    return relics
