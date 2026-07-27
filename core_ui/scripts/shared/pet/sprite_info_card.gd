extends "res://core_ui/scripts/shared/pet/sprite_info_panel_component.gd"

const SpriteInfoDataScript := preload("res://core_ui/scripts/shared/pet/sprite_info_data.gd")
const SpriteRankStatsScript := preload("res://core_ui/scripts/shared/pet/sprite_rank_stats.gd")

const SOURCE_COMPONENT := "per-west-travel-v-0.01/FloatingUI/Prefabs/SpriteInfoPanel.gd"
const ATTACK_COLUMNS := 7
const ATTACK_ROWS := 3
const ATTACK_ORIGIN_INDEX := 10

var _snapshot := {}


func set_info(record: Dictionary, texture: Texture2D = null) -> Dictionary:
	_snapshot = _normalize_record(record)
	var info := SpriteInfoDataScript.new()
	info.sprite_id = String(_snapshot.get("id", ""))
	info.display_name = String(_snapshot.get("name", "未知宠物"))
	info.sprite_texture = texture
	info.portrait_texture = texture
	info.element_name = String(_snapshot.get("element", "风"))
	info.attack_cell_count = ATTACK_COLUMNS * ATTACK_ROWS
	info.origin_cell_index = ATTACK_ORIGIN_INDEX
	info.hit_cell_indices = _hit_indices(Dictionary(_snapshot.get("attack_shape", {})))
	info.current_rank_index = 0

	var rank := SpriteRankStatsScript.new()
	rank.quality_name = _quality_name(String(_snapshot.get("quality", "青铜")))
	rank.hp_current = int(_snapshot.get("hp", 0))
	rank.hp_max = int(_snapshot.get("max_hp", rank.hp_current))
	rank.ap_current = int(_snapshot.get("ap", 0))
	rank.ap_max = int(_snapshot.get("max_ap", rank.ap_current))
	rank.attack = int(_snapshot.get("attack", 0))
	rank.defense = int(_snapshot.get("defense", 0))
	rank.shield = int(_snapshot.get("shield", 0))
	rank.regen = int(_snapshot.get("regen", 0))
	info.ranks.append(rank)

	display_info(info)
	return get_info_snapshot()


func get_info_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_attack_shape_cell_count() -> int:
	return ATTACK_COLUMNS * ATTACK_ROWS


func get_display_text() -> String:
	return "\n".join([
		String(_snapshot.get("name", "未知宠物")),
		"%s · %s" % [_snapshot.get("element", "未知元素"), _quality_name(String(_snapshot.get("quality", "青铜")))],
		"生命 %s/%s    攻击力 %s    防御 %s" % [_snapshot.get("hp", 0), _snapshot.get("max_hp", 0), _snapshot.get("attack", 0), _snapshot.get("defense", 0)],
		"护盾 %s    AP %s/%s    再生 %s" % [_snapshot.get("shield", 0), _snapshot.get("ap", 0), _snapshot.get("max_ap", 0), _snapshot.get("regen", 0)],
	])


func get_component_source() -> String:
	return SOURCE_COMPONENT


func _normalize_record(record: Dictionary) -> Dictionary:
	var hp: Variant = _first_value(record, ["hp", "current_hp", "currentHp"], 0)
	var max_hp: Variant = _first_value(record, ["max_hp", "maxHp", "hp_max"], hp)
	var ap: Variant = _first_value(record, ["ap", "current_ap", "currentAp", "action_points"], 0)
	var max_ap: Variant = _first_value(record, ["max_ap", "maxAp", "ap_max", "max_action_points"], ap)
	return {
		"id": _first_value(record, ["id", "pet_id", "unit_id"], ""),
		"name": _first_value(record, ["name", "display_name", "title"], "未知宠物"),
		"element": _first_value(record, ["element", "element_name"], "未知元素"),
		"quality": _first_value(record, ["quality", "rarity", "tier"], "青铜"),
		"hp": hp,
		"max_hp": max_hp,
		"ap": ap,
		"max_ap": max_ap,
		"attack": _first_value(record, ["attack", "atk", "power"], 0),
		"defense": _first_value(record, ["defense", "def", "resistance"], 0),
		"shield": _first_value(record, ["shield", "armor"], 0),
		"regen": _first_value(record, ["regen", "regeneration", "heal_per_round"], 0),
		"attack_shape": Dictionary(record.get("attack_shape", {})).duplicate(true),
	}


func _hit_indices(shape: Dictionary) -> Array[int]:
	var indices: Array[int] = []
	for value in Array(shape.get("offsets", [])):
		var offset := Dictionary(value)
		var row := int(offset.get("dr", 0)) + 1
		var column := int(offset.get("dc", 0)) + 3
		if row < 0 or row >= ATTACK_ROWS or column < 0 or column >= ATTACK_COLUMNS:
			continue
		var index := row * ATTACK_COLUMNS + column
		if index != ATTACK_ORIGIN_INDEX and not indices.has(index):
			indices.append(index)
	return indices


func _quality_name(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized.contains("diamond") or value.contains("钻石"):
		return "钻石"
	if normalized.contains("gold") or value.contains("黄金"):
		return "黄金"
	if normalized.contains("silver") or value.contains("白银"):
		return "白银"
	return "青铜"


func _first_value(record: Dictionary, keys: Array[String], fallback: Variant) -> Variant:
	for key in keys:
		if record.has(key) and record.get(key) != null:
			return record.get(key)
	return fallback
