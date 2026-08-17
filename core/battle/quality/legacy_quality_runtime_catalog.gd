extends RefCounted

## Frozen Q0 bootstrap. This is the only production quality source that may
## name the migrated S/G/D content ids. Q1 will decide when persisted snapshots
## may use it; current content must never silently fall back here.


static func upgrades() -> Array:
	var rows: Array = []
	rows.append(_upgrade("S01", [_op("S01", "round", "round_start", "round_grant_shield", {"amount": 15})]))
	rows.append(_upgrade("S02", [_op("S02", "round", "round_start", "round_heal", {"amount": 20})]))
	rows.append(_upgrade("S03", [_op("S03", "round", "round_start", "round_double_max_hp_once", {"factor": 2, "cap": 30, "flag": "s03_applied"})]))
	rows.append(_upgrade("S04", [_op("S04", "element_count", "element_application_count", "element_apply_count_add", {"amount": 1})]))
	rows.append(_upgrade("S05", [_op("S05", "damage", "modify_hit_damage", "damage_multiply_when", {"when": {"last_hit": true}, "value": 2})]))
	rows.append(_upgrade("S06", [_op("S06", "damage", "modify_hit_damage", "damage_chain_double", {"when": {}})]))
	rows.append(_upgrade("S07", [_op("S07", "growth", "after_attack", "permanent_attack_per_kills", {"threshold": 5, "amount": 1})]))
	rows.append(_upgrade("S08", [_op("S08", "element_layers", "element_layers", "element_layers_multiply_matching", {"factor": 2})]))

	rows.append(_upgrade("G01", [
		_op("G01", "mode", "profile", "mode_profile", {"options": ["攻", "守"], "aliases": {"攻": ["攻击", "attack"], "守": ["防守", "guard"]}}),
		_op("G01", "round", "round_start", "round_guard_stance", {"attack_mode": "攻", "guard_mode": "守", "amount": 8}),
		_op("G01", "damage", "modify_hit_damage", "damage_add_when", {"when": {"mode_is_guard": false}, "value": 2}),
		_op("G01", "flags", "profile", "boolean_profile", {"preview_damage": true}),
	]))
	rows.append(_upgrade("G02", [
		_op("G02", "mode", "profile", "mode_profile", {"options": ["稳", "爆"], "aliases": {"稳": ["稳定", "stable"], "爆": ["爆发", "burst"]}}),
		_op("G02", "stable", "modify_hit_damage", "damage_add_when", {"when": {"mode": "稳"}, "value": 1}),
		_op("G02", "burst", "modify_hit_damage", "damage_add_when", {"when": {"mode": "爆", "first_hit": true}, "value": 4}),
		_op("G02", "default_first", "modify_hit_damage", "damage_add_when", {"when": {"mode": "", "first_hit": true}, "value": 4}),
		_op("G02", "default_follow", "modify_hit_damage", "damage_add_when", {"when": {"mode": "", "first_hit": false}, "value": 1}),
		_op("G02", "flags", "profile", "boolean_profile", {"preview_damage": true}),
	]))
	rows.append(_upgrade("G03", [_damage_add("G03", "core", {"core_cell": true}, 3), _preview("G03")]))
	rows.append(_upgrade("G04", [_op("G04", "shield", "after_attack", "shield_core_ally", {"amount": 8})]))
	rows.append(_upgrade("G05", [_op("G05", "heal", "after_attack", "heal_core_ally", {"amount": 6})]))
	rows.append(_upgrade("G06", [_damage_add("G06", "core", {"core_cell": true}, 2)]))
	rows.append(_upgrade("G07", [_damage_add("G07", "farthest", {"farthest_cell": true}, 3)]))
	rows.append(_upgrade("G08", [_op("G08", "shield_behind", "before_attack", "shield_behind", {"amount": 10})]))
	rows.append(_upgrade("G09", [_damage_add("G09", "off_axis", {"off_axis": true}, 1)]))
	rows.append(_upgrade("G10", [_damage_add("G10", "farthest", {"farthest_cell": true}, 4)]))
	rows.append(_upgrade("G11", [_damage_add("G11", "single", {"target_count": 1}, 5)]))
	rows.append(_upgrade("G12", [_op("G12", "incoming", "after_attack", "incoming_bonus_all_targets", {"amount": 3})]))
	rows.append(_upgrade("G13", [_damage_add("G13", "distance", {"distance_min": 2}, 4)]))
	rows.append(_upgrade("G14", [
		_op("G14", "mode", "profile", "mode_profile", {"options": ["稳", "重"], "aliases": {"稳": ["稳定", "稳击", "stable"], "重": ["重击", "heavy"]}}),
		_damage_add("G14", "stable", {"mode": "稳"}, 2),
		_damage_add("G14", "heavy", {"mode_is_stable": false}, 6),
		_op("G14", "narrow", "attack_option_for_target", "narrow_to_target_mode", {"mode": "重"}),
		_preview("G14"),
	]))
	rows.append(_upgrade("G15", [_damage_add("G15", "low_hp", {"target_hp_max": 8}, 8)]))
	rows.append(_upgrade("G16", [_op("G16", "chase", "after_hit", "kill_chase", {"amount": 3, "verb": "追击"})]))
	rows.append(_upgrade("G17", [
		_damage_add("G17", "marked", {"has_mark": true, "marked_match": true}, 5),
		_damage_add("G17", "fallback", {"has_mark": false, "core_or_single": true}, 5),
		_op("G17", "flags", "profile", "boolean_profile", {"preview_damage": true, "supports_mark": true}),
	]))
	rows.append(_upgrade("G18", [_damage_add("G18", "second", {"target_count_min": 2, "hit_index": 1}, 4)]))
	rows.append(_upgrade("G19", [_damage_add("G19", "multi", {"target_count_min": 2}, 2)]))
	rows.append(_upgrade("G20", [_damage_add("G20", "farthest", {"farthest_cell": true}, 4)]))
	rows.append(_upgrade("G21", [
		_damage_add("G21", "first", {"first_cell": true}, 2),
		_op("G21", "shield_behind", "before_attack", "shield_behind", {"amount": 8}),
	]))
	rows.append(_upgrade("G22", [
		_damage_add("G22", "marked", {"has_mark": true, "marked_match": true}, 4),
		_damage_add("G22", "fallback", {"has_mark": false, "core_or_first": true}, 4),
		_op("G22", "shield", "after_attack", "shield_marked_ally", {"amount": 8}),
		_op("G22", "flags", "profile", "boolean_profile", {"preview_damage": true, "supports_mark": true}),
	]))
	rows.append(_upgrade("G23", [
		_damage_add("G23", "second", {"target_count_min": 2, "hit_index": 1}, 3),
		_op("G23", "incoming", "after_attack", "incoming_bonus_first_target", {"amount": 3}),
	]))
	rows.append(_upgrade("G24", [
		_op("G24", "mode", "profile", "mode_profile", {"options": ["同", "主副"], "aliases": {"同": ["同伤", "same", "sameDamage"], "主副": ["主", "main", "mainSub", "main-sub"]}}),
		_damage_add("G24", "same", {"mode": "同"}, 1),
		_damage_add("G24", "main", {"mode_is_same": false, "first_hit": true}, 4),
		_preview("G24"),
	]))
	rows.append(_upgrade("G25", [_damage_add("G25", "core", {"core_cell": true}, 3), _preview("G25")]))
	rows.append(_upgrade("G26", [_damage_add("G26", "multi", {"target_count_min": 2}, 1), _preview("G26")]))
	rows.append(_upgrade("G27", [_damage_add("G27", "farthest", {"farthest_cell": true}, 3)]))
	rows.append(_upgrade("G28", [
		_damage_add("G28", "formation", {"g28_active": true}, 2),
		_op("G28", "shield", "before_attack", "formation_shield", {"amount": 5}),
	]))
	rows.append(_upgrade("G29", [_damage_add("G29", "farthest", {"farthest_positive": true, "farthest_cell": true, "first_target_exists": true}, 4)]))
	rows.append(_upgrade("G30", [
		_damage_add("G30", "marked", {"has_mark": true, "marked_match": true}, 3),
		_damage_add("G30", "fallback", {"has_mark": false, "core_cell": true}, 3),
		_op("G30", "flags", "profile", "boolean_profile", {"preview_damage": true, "supports_mark": true}),
	]))

	rows.append(_upgrade("D01", [_shape("D01", "extend", "shape_extend_end")]))
	rows.append(_upgrade("D02", [_shape("D02", "back_sweep", "shape_back_sweep")]))
	rows.append(_upgrade("D03", [_shape("D03", "mirror", "shape_mirror")]))
	rows.append(_upgrade("D04", [_shape("D04", "diagonal", "shape_diagonal_copy")]))
	rows.append(_upgrade("D05", [_op("D05", "splash", "after_hit", "adjacent_splash", {"amount": 1})]))
	rows.append(_upgrade("D06", [_shape("D06", "double_ends", "shape_double_ends")]))
	rows.append(_upgrade("D07", [_damage_add("D07", "single", {"target_count": 1}, 6)]))
	rows.append(_upgrade("D08", [_damage_add("D08", "multi", {"target_count_min": 2}, 2)]))
	rows.append(_upgrade("D09", [_shape("D09", "corner", "shape_fill_corner")]))
	rows.append(_upgrade("D10", [_shape("D10", "pierce", "shape_pierce_end")]))
	rows.append(_upgrade("D11", [_op("D11", "order", "profile", "actor_order_profile", {"order": -1})]))
	rows.append(_upgrade("D12", [
		_damage_add("D12", "last", {"last_hit": true}, 5),
		_op("D12", "order", "profile", "actor_order_profile", {"order": 1}),
	]))
	rows.append(_upgrade("D13", [_op("D13", "chase", "after_attack", "chase_low_hp", {"amount": 5})]))
	rows.append(_upgrade("D14", [_op("D14", "chain", "after_hit", "kill_chase", {"amount": 4, "verb": "连锁"})]))
	rows.append(_upgrade("D15", [_op("D15", "repeat", "after_attack", "repeat_core_if_covered", {"minimum_units": 3})]))
	rows.append(_upgrade("D16", [_op("D16", "single", "modify_hit_damage", "damage_multiply_when", {"when": {"target_count": 1}, "value": 2})]))
	rows.append(_upgrade("D17", [_op("D17", "scale", "modify_hit_damage", "damage_scale_ceil_when", {"when": {}, "numerator": 3, "denominator": 2})]))
	rows.append(_upgrade("D18", [_op("D18", "burst", "before_hit", "immediate_element_burst", {"minimum_layers": 3})]))
	rows.append(_upgrade("D19", [_op("D19", "sort", "sort_targets", "sort_lowest_hp", {})]))
	rows.append(_upgrade("D20", [_shape("D20", "reverse", "shape_reverse")]))
	rows.append(_upgrade("D21", [_trace("D21", "fire_trace", 1)]))
	rows.append(_upgrade("D22", [_trace("D22", "water_trace", 1)]))
	rows.append(_upgrade("D23", [_trace("D23", "wind_trace", 1)]))
	rows.append(_upgrade("D24", [_trace("D24", "earth_trace", 1)]))
	rows.append(_upgrade("D25", [_trace("D25", "metal_trace", 1)]))
	rows.append(_upgrade("D26", [_trace("D26", "wood_trace", 2)]))
	rows.append(_upgrade("D27", [_trace("D27", "buddha_trace", 1)]))
	rows.append(_upgrade("D28", [_trace("D28", "sand_trace", 1)]))
	rows.append(_upgrade("D29", [_trace("D29", "demon_trace", 1)]))
	rows.append(_upgrade("D30", [_trace("D30", "talisman_trace", 1, true)]))
	return rows


static func _upgrade(effect_id: String, operations: Array) -> Dictionary:
	return {"id": effect_id, "runtime_operations": operations}


static func _op(
	effect_id: String,
	suffix: String,
	hook: String,
	operation: String,
	params: Dictionary
) -> Dictionary:
	return {
		"id": "%s.%s" % [effect_id, suffix],
		"hook": hook,
		"operation": operation,
		"priority": 100,
		"params": params.duplicate(true),
	}


static func _damage_add(effect_id: String, suffix: String, when: Dictionary, value: int) -> Dictionary:
	return _op(effect_id, suffix, "modify_hit_damage", "damage_add_when", {"when": when, "value": value})


static func _preview(effect_id: String) -> Dictionary:
	return _op(effect_id, "preview", "profile", "boolean_profile", {"preview_damage": true})


static func _shape(effect_id: String, suffix: String, operation: String) -> Dictionary:
	return _op(effect_id, suffix, "mutate_shape", operation, {})


static func _trace(effect_id: String, operation: String, duration: int, persistent: bool = false) -> Dictionary:
	return _op(effect_id, "trace", "after_attack", operation, {
		"duration": duration,
		"persistent": persistent,
	})
