extends RefCounted

const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")

## Versioned write-through adapter for deterministic summoned-unit creation.

const CONTRACT_ID := &"ysbzs.summon-port.v1"
var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func inside(x: int, y: int) -> bool:
	return bool(_authority.call("_inside", x, y))


func unit_at(x: int, y: int) -> Dictionary:
	return Dictionary(_authority.call("unit_at", x, y))


func mechanic_param_int(unit: Dictionary, definition: Dictionary, key: String, fallback: int) -> int:
	return int(_authority.call("_mechanic_param_int", unit, definition, key, fallback))


func mechanic_param_string(unit: Dictionary, definition: Dictionary, key: String, fallback: String) -> String:
	return String(_authority.call("_mechanic_param_string", unit, definition, key, fallback))


func apply_summon_semantics(unit: Dictionary, values: Dictionary) -> Dictionary:
	var payload := values.duplicate(true)
	payload["unit"] = unit
	return Dictionary(_authority.call("_apply_stat_semantics", EffectHookIdsScript.SUMMON, payload))


func player_side() -> String:
	return "player"


func unit_count() -> int:
	return Array(_authority.get("units")).size()


func append_unit(unit: Dictionary) -> void:
	var authority_units := Array(_authority.get("units"))
	authority_units.append(unit)
	_authority.set("units", authority_units)
