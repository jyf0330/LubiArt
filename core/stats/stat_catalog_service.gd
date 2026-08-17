extends RefCounted

## Typed stat Type Object lookup. Definitions are planner-owned data; this
## service supplies stable defaults and aliases without owning runtime state.

const StatIdsScript := preload("res://core/stats/stat_ids.gd")

const UNIT_ALIASES := {
	StatIdsScript.STARTING_SHIELD: ["base_shield", StatIdsScript.STARTING_SHIELD],
	StatIdsScript.ACTION_POINTS: ["ap", StatIdsScript.ACTION_POINTS],
	StatIdsScript.MOVE_RANGE: [StatIdsScript.MOVE_RANGE, "moveRange", "moveAp", "move_ap", "ap"],
	StatIdsScript.ATTACK_COUNT: [StatIdsScript.ATTACK_COUNT, "attackCount", "attack_times", "attackTimes", "ap"],
}


func definition(catalog: Dictionary, stat_id: String) -> Dictionary:
	var value := Dictionary(catalog.get(stat_id, {}))
	if not value.is_empty():
		return value.duplicate(true)
	return {
		"id": stat_id,
		"name": stat_id,
		"category": "custom",
		"value_type": "integer",
		"default_value": 0,
		"min_value": -2147483648,
		"max_value": 2147483647,
		"display_unit": "",
		"stacking_rule": "flat_percent_multiplier_override_clamp",
	}


func base_value(unit: Dictionary, stat_id: String, catalog: Dictionary) -> int:
	if unit.has(stat_id):
		return int(unit.get(stat_id, 0))
	for alias_value in Array(UNIT_ALIASES.get(stat_id, [])):
		var alias := String(alias_value)
		if unit.has(alias):
			return int(unit.get(alias, 0))
	var base_stats := Dictionary(unit.get("base_stats", {}))
	if base_stats.has(stat_id):
		return int(base_stats.get(stat_id, 0))
	return int(definition(catalog, stat_id).get("default_value", 0))


func ordered_ids(catalog: Dictionary) -> Array[String]:
	var rows: Array = []
	for stat_id_value in catalog.keys():
		var stat_id := String(stat_id_value)
		var row := Dictionary(catalog.get(stat_id, {}))
		rows.append({"id": stat_id, "order_index": int(row.get("order_index", 0))})
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_order := int(left.get("order_index", 0))
		var right_order := int(right.get("order_index", 0))
		if left_order != right_order:
			return left_order < right_order
		return String(left.get("id", "")) < String(right.get("id", ""))
	)
	var result: Array[String] = []
	for row_value in rows:
		result.append(String(Dictionary(row_value).get("id", "")))
	return result
