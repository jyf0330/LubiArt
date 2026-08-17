extends RefCounted
class_name BattlePetViewModel

## Pure projection from public battle/detail dictionaries to a stable visual model.
## It owns compatibility aliases so individual Controls do not reinterpret data.


static func from_record(record: Dictionary, side_override: String = "") -> Dictionary:
	var hp := _int_value(_first(record, ["hp", "current_hp", "currentHp"], 0))
	var maximum_hp := maxi(1, _int_value(_first(record, ["max_hp", "maxHp", "hp_max"], hp), hp))
	var shield := maxi(0, _int_value(_first(record, ["shield", "armor"], 0)))
	var maximum_shield := maxi(
		1,
		_int_value(_first(record, ["max_shield", "maxShield", "shield_max"], shield), shield)
	)
	var ap := maxi(0, _int_value(_first(record, ["available_ap", "availableAp", "current_ap", "ap"], 0)))
	var maximum_ap := maxi(ap, _int_value(_first(record, ["max_ap", "maxAp", "ap_max", "ap"], ap), ap))
	var side := side_override.strip_edges()
	if side == "":
		side = String(_first(record, ["side", "camp", "team"], "player"))
	var normalized_side := _normalized_side(side)
	return {
		"id": String(_first(record, ["id", "unitId", "unit_id", "pet_id", "petId"], "")),
		"name": String(_first(record, ["name", "displayName", "display_name", "unitName", "title"], "未知宠物")),
		"element": _element_value(record),
		"quality": String(_first(record, ["quality", "rarity", "tier"], "青铜")),
		"role": String(_first(record, ["role"], _side_label(normalized_side))),
		"side": normalized_side,
		"is_enemy": normalized_side == "enemy",
		"hp": clampi(hp, 0, maximum_hp),
		"max_hp": maximum_hp,
		"attack": _int_value(_first(record, ["attack", "atk", "power"], 0)),
		"defense": _int_value(_first(record, ["defense", "def", "resistance"], 0)),
		"shield": shield,
		"max_shield": maximum_shield,
		"regen": _int_value(_first(record, ["regen", "regeneration"], 0)),
		"ap": ap,
		"max_ap": maximum_ap,
		"damage_cap": _int_value(_first(record, ["damage_cap", "damageCap", "threat"], 0)),
		"attack_shape": _dictionary(record.get("attack_shape", record.get("attackShape", {}))).duplicate(true),
	}


static func _normalized_side(value: String) -> String:
	var side := value.strip_edges().to_lower()
	if side in ["enemy", "monster", "boss", "enemy_leader"]:
		return "enemy"
	return "player"


static func _side_label(side: String) -> String:
	return "敌方" if side == "enemy" else "我方"


static func _first(record: Dictionary, keys: Array[String], fallback: Variant) -> Variant:
	for key in keys:
		if record.has(key) and record.get(key) != null:
			return record.get(key)
	return fallback


static func _dictionary(value: Variant) -> Dictionary:
	return Dictionary(value) if value is Dictionary else {}


static func _element_value(record: Dictionary) -> String:
	var element_types := Array(record.get("element_types", []))
	if not element_types.is_empty():
		var labels: Array[String] = []
		for value in element_types:
			labels.append(String(value))
		return " / ".join(labels)
	return String(_first(record, ["element", "main_element", "element_name"], "wind"))


static func _int_value(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is bool:
		return 1 if value else 0
	if value is String or value is StringName:
		var text := String(value).strip_edges()
		return text.to_int() if text.is_valid_int() else fallback
	return fallback
