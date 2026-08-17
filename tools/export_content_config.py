"""Stable paths and non-mechanism export constants."""

from pathlib import Path

YSBZS_ROOT = Path("/Users/ywh/Documents/ysbzs")
GODOT_ROOT = Path(__file__).resolve().parents[1]
CSV_ROOT = YSBZS_ROOT / "data" / "csv"
RUNTIME_DATABASE_PATH = YSBZS_ROOT / "data" / "runtime" / "database.json"
CONTENT_ROOT = GODOT_ROOT / "data" / "content"
BAZAAR_DAY1_CATALOG_PATH = GODOT_ROOT / "data" / "bazaar_day1_shop_catalog.json"
PAL_ELEMENTS = ["无", "火", "水", "草", "雷", "冰", "地", "暗", "龙"]
RELIC_TRIGGER_TYPES = {
    "战斗开始": "BATTLE_STARTED",
    "攻击后": "SKILL_USED",
    "受击后": "DAMAGE_APPLIED",
    "死亡时": "UNIT_DEFEATED",
    "战斗结算": "BATTLE_ENDED",
    "商店刷新": "SHOP_REFRESHED",
}
