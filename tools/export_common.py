"""CSV, runtime database, scalar and basic domain helpers."""

from __future__ import annotations

import csv
import json
from collections import Counter
from pathlib import Path
from typing import Any

from export_content_config import *
from export_mechanism_sets import *
from export_mechanism_status import *

def read_csv(name: str) -> list[dict[str, str]]:
    with (CSV_ROOT / name).open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def read_runtime_database() -> dict[str, object]:
    if not RUNTIME_DATABASE_PATH.exists():
        return {}
    with RUNTIME_DATABASE_PATH.open("r", encoding="utf-8") as handle:
        parsed = json.load(handle)
    if not isinstance(parsed, dict):
        return {}
    return parsed


def build_battle_rules() -> dict[str, int]:
    rules: dict[str, int] = {}
    for row in read_csv("31_battle_rules.csv"):
        rule_id = row.get("rule_id", "").strip()
        if not rule_id or row.get("status", "").strip() != "正式":
            continue
        rules[rule_id] = as_int(row.get("value"), 0)
    return rules


def as_int(value: str | None, default: int = 0) -> int:
    if value is None:
        return default
    text = str(value).strip()
    if not text or text in {"—", "-", "NA"}:
        return default
    try:
        return int(float(text))
    except ValueError:
        return default


def pet_elements(row: dict[str, str]) -> list[str]:
    primary = row.get("元素", row.get("元素(自动)", "")).strip()
    secondary = split_list(row.get("副属"))
    values = [primary, *secondary]
    return list(dict.fromkeys(value for value in values if value in PAL_ELEMENTS)) or ["无"]


def enabled(value: str | None) -> bool:
    return str(value or "").strip() in {"是", "启用", "true", "TRUE", "1"}


def formal(value: str | None) -> bool:
    return str(value or "").strip() in {"正式", "启用", "true", "TRUE", "1"}


def godot_mechanism_behavior_status(mechanism_id: str) -> str:
    if mechanism_id in TEMPORARY_TRIAL_MECHANISMS:
        return "excluded_temporary_trial"
    if mechanism_id in NON_FORMAL_PENDING_MECHANISMS:
        return "excluded_non_formal"
    if mechanism_id in GODOT_COVERED_MECHANISMS:
        return "covered"
    if mechanism_id in WEB_STATUS_ONLY_MECHANISMS:
        return "web_status_only"
    web_status = WEB_MECHANIC_STATUS.get(mechanism_id, "unknown")
    if web_status == "data_only":
        return "event_flow_or_data_only"
    if web_status == "pending":
        return "pending"
    return "not_covered"


def godot_mechanism_followup_group(mechanism_id: str) -> str:
    behavior_status = godot_mechanism_behavior_status(mechanism_id)
    if behavior_status == "excluded_temporary_trial":
        return "temporary_or_debug_leftover"
    if behavior_status == "excluded_non_formal":
        return "future_formal_candidate"
    if behavior_status == "covered":
        return "covered"
    return "needs_review"


def count_values(rows: list[dict[str, object]], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for row in rows:
        value = str(row.get(key, "")).strip() or "unknown"
        counts[value] = counts.get(value, 0) + 1
    return counts


def split_list(value: str | None) -> list[str]:
    items: list[str] = []
    for token in str(value or "").replace("，", ",").replace("、", ",").replace("；", ",").replace(";", ",").split(","):
        item = token.strip()
        if item and item not in items:
            items.append(item)
    return items


def split_int_list(value: str | None) -> list[int]:
    items: list[int] = []
    for token in str(value or "").replace("，", "|").replace("、", "|").replace(",", "|").split("|"):
        text = token.strip()
        if not text:
            continue
        item = as_int(text, 0)
        if item > 0 and item not in items:
            items.append(item)
    return items


def first_value(row: dict[str, str], *keys: str) -> str:
    for key in keys:
        value = str(row.get(key, "")).strip()
        if value:
            return value
    return ""
