"""Pure parsers for exported source cell values."""

from __future__ import annotations

import json
import re
from typing import Any

from export_common import *

def parse_json_list(raw: str | None, field_name: str, record_id: str) -> list[object]:
    text = str(raw or "").strip()
    if not text:
        return []
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid {field_name} for {record_id}: {exc}") from exc
    if not isinstance(parsed, list):
        raise ValueError(f"{field_name} must be an array for {record_id}")
    return parsed


def parse_offsets(raw: str | None) -> list[dict[str, int]]:
    text = str(raw or "").strip()
    if not text:
        return []
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return []
    offsets: list[dict[str, int]] = []
    if not isinstance(parsed, list):
        return offsets
    for item in parsed:
        if not isinstance(item, dict):
            continue
        offsets.append({"dr": as_int(str(item.get("dr", 0)), 0), "dc": as_int(str(item.get("dc", 0)), 0)})
    return offsets


def normalize_pet_id_token(token: str | None) -> str:
    raw = str(token or "").strip()
    if not raw:
        return ""
    lowered = raw.lower().replace("-", "_")
    if lowered.startswith("pal_"):
        number = lowered.removeprefix("pal_")
        if number.isdigit():
            return "pal_%03d" % int(number)
        return raw
    if raw.lower().startswith("no."):
        raw = raw[3:].strip()
    if raw.isdigit():
        return "pal_%03d" % int(raw)
    return raw


def parse_pool_count(expression: str | None, fallback_count: int = 1) -> tuple[list[str], int]:
    raw = str(expression or "").strip()
    if not raw:
        return [], max(0, fallback_count)
    pool_part = raw
    count = fallback_count
    if "-" in raw:
        maybe_pool, maybe_count = raw.rsplit("-", 1)
        if maybe_pool.strip() and maybe_count.strip().isdigit():
            pool_part = maybe_pool.strip()
            count = int(maybe_count.strip())
    pet_ids: list[str] = []
    for token in pool_part.replace("，", ",").replace("、", ",").replace("；", ",").replace(";", ",").split(","):
        pet_id = normalize_pet_id_token(token)
        if pet_id and pet_id not in pet_ids:
            pet_ids.append(pet_id)
    return pet_ids, max(0, count)


def parse_wave_pool_count(expression: str | None, fallback_count: int = 1) -> tuple[list[str], int]:
    raw = str(expression or "").strip()
    if not raw:
        return [], max(0, fallback_count)
    pool_part = raw
    count = fallback_count
    if "-" in raw:
        maybe_pool, maybe_count = raw.rsplit("-", 1)
        if maybe_pool.strip() and maybe_count.strip().isdigit():
            pool_part = maybe_pool.strip()
            count = int(maybe_count.strip())
    tokens: list[str] = []
    for token in pool_part.replace("，", ",").replace("、", ",").replace("；", ",").replace(";", ",").split(","):
        item = token.strip()
        if item and item not in tokens:
            tokens.append(item)
    return tokens, max(0, count)


def parse_quality_weights(raw: str | None) -> dict[str, int]:
    qualities = ["青铜", "白银", "黄金", "钻石"]
    parts = [part.strip() for part in str(raw or "").replace("，", ",").replace("、", ",").split(",")]
    weights: dict[str, int] = {}
    for index, quality in enumerate(qualities):
        weights[quality] = as_int(parts[index], 0) if index < len(parts) else 0
    if sum(weights.values()) <= 0:
        weights["青铜"] = 1
    return weights


def dominant_quality(weights: dict[str, int]) -> str:
    return max(weights.items(), key=lambda item: item[1])[0] if weights else "青铜"
