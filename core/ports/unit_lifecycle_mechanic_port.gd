extends RefCounted

## Versioned adapter for death, shield-break, kill, post-action and battle-end
## mechanics. Mutation remains write-through to the one YsbzsState authority.

const CONTRACT_ID := &"ysbzs.unit-lifecycle-mechanic-port.v1"
var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func mechanic_ids(unit: Dictionary) -> Array:
	return Array(_authority.call("_unit_mechanic_ids", unit))


func mechanism(mechanism_id: String) -> Dictionary:
	return Dictionary(_authority.call("_mechanism_by_id", mechanism_id))


func mechanic_param_int(unit: Dictionary, definition: Dictionary, key: String, fallback: int) -> int:
	return int(_authority.call("_mechanic_param_int", unit, definition, key, fallback))


func mechanic_param_float(unit: Dictionary, definition: Dictionary, key: String, fallback: float) -> float:
	return float(_authority.call("_mechanic_param_float", unit, definition, key, fallback))


func mechanic_param_string(unit: Dictionary, definition: Dictionary, key: String, fallback: String) -> String:
	return String(_authority.call("_mechanic_param_string", unit, definition, key, fallback))


func cross_damage(unit: Dictionary, source: Dictionary, damage: int, element: String, label: String, trace_context: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_apply_cross_damage_from_unit", unit, source, damage, element, label, trace_context))


func first_empty_near(unit: Dictionary, include_origin: bool) -> Dictionary:
	return Dictionary(_authority.call("_first_empty_cell_near_unit", unit, include_origin))


func first_adjacent_empty(unit: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_first_adjacent_empty_cell", unit))


func summon_unit(caster: Dictionary, definition: Dictionary, cell: Dictionary, summon_id: String, display_name: String, hp: int, atk: int) -> Dictionary:
	return Dictionary(_authority.call("_summon_unit_on_cell", caster, definition, cell, summon_id, display_name, hp, atk))


func summon_wall(caster: Dictionary, cell: Dictionary, hp: int, duration: int) -> Dictionary:
	return Dictionary(_authority.call("_summon_wall_on_cell", caster, cell, hp, duration))


func copy_weak_self(source: Dictionary, cell: Dictionary, hp_pct: float, atk_pct: float) -> Dictionary:
	return Dictionary(_authority.call("_copy_weak_self_on_cell", source, cell, hp_pct, atk_pct))


func all_units() -> Array:
	return Array(_authority.get("units"))


func battle_end_units() -> Array:
	var result := Array(_authority.get("units")).duplicate(true)
	result.append_array(Array(_authority.get("defeated_units")))
	return result


func battle_round() -> int:
	return int(_authority.get("battle_round"))


func shop_next_discount() -> int:
	return int(_authority.get("shop_next_discount"))


func set_shop_next_discount(value: int) -> void:
	_authority.set("shop_next_discount", value)


func enemy_side() -> String:
	return "enemy"
