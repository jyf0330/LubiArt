extends RefCounted

const TRIGGER_ALIASES := {
	"战斗开始": "BATTLE_STARTED",
	"攻击后": "SKILL_USED",
	"受击后": "DAMAGE_APPLIED",
	"死亡时": "UNIT_DEFEATED",
	"战斗结算": "BATTLE_ENDED",
	"商店刷新": "SHOP_REFRESHED",
}


func catalog(game_data: Dictionary) -> Dictionary:
	var raw: Variant = Dictionary(game_data.get("economy", {})).get("relics", [])
	var result := {}
	if raw is Dictionary:
		for relic_id_value in Dictionary(raw).keys():
			var definition := _normalize_definition(Dictionary(Dictionary(raw)[relic_id_value]), String(relic_id_value))
			if String(definition.get("id", "")) != "":
				result[String(definition["id"])] = definition
	elif raw is Array:
		for row_value in Array(raw):
			var definition := _normalize_definition(Dictionary(row_value))
			if String(definition.get("id", "")) != "":
				result[String(definition["id"])] = definition
	return result


func inventory_entries(inventory: Array, game_data: Dictionary) -> Array:
	var definitions := catalog(game_data)
	var entries: Array = []
	for index in range(inventory.size()):
		var raw: Variant = inventory[index]
		var entry := {"relic_id": String(raw)} if raw is String else Dictionary(raw).duplicate(true)
		var relic_id := String(entry.get("relic_id", entry.get("id", "")))
		if relic_id == "" or not definitions.has(relic_id):
			continue
		var side := String(entry.get("side", "player"))
		entry["relic_id"] = relic_id
		entry["side"] = side
		entry["instance_id"] = String(entry.get("instance_id", "%s:%s:%d" % [side, relic_id, index]))
		entry["definition"] = Dictionary(definitions[relic_id]).duplicate(true)
		entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("instance_id", "")) < String(b.get("instance_id", ""))
	)
	return entries


func trigger_type(value: String) -> String:
	var normalized := value.strip_edges()
	return String(TRIGGER_ALIASES.get(normalized, normalized.to_upper()))


func _normalize_definition(raw: Dictionary, fallback_id: String = "") -> Dictionary:
	var definition := raw.duplicate(true)
	definition["id"] = String(definition.get("id", definition.get("relic_id", fallback_id)))
	definition["name"] = String(definition.get("name", definition.get("relic_name", definition["id"])))
	definition["trigger_type"] = trigger_type(String(definition.get("trigger_type", definition.get("trigger", ""))))
	definition["cooldown_ticks"] = max(0, int(definition.get("cooldown_ticks", 0)))
	definition["duration_ticks"] = max(0, int(definition.get("duration_ticks", 0)))
	definition["internal_cooldown_ticks"] = max(0, int(definition.get("internal_cooldown_ticks", 0)))
	definition["priority"] = int(definition.get("priority", 0))
	definition["max_triggers_per_tick"] = max(0, int(definition.get("max_triggers_per_tick", 0)))
	definition["effects"] = _array_value(definition.get("effects", []))
	definition["charges"] = _array_value(definition.get("charges", []))
	definition["emit_events"] = _array_value(definition.get("emit_events", []))
	definition["event_filter"] = Dictionary(definition.get("event_filter", {})).duplicate(true)
	definition["timer_enabled"] = bool(definition.get("timer_enabled", false)) or int(definition["cooldown_ticks"]) > 0
	return definition


func _array_value(value: Variant) -> Array:
	return Array(value).duplicate(true) if value is Array else []
