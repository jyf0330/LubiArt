extends RefCounted

## Versioned adapter between DamageMechanicService and the legacy authority.
## Dynamic calls are confined here while mechanics are migrated out of the
## inheritance trunk one event family at a time.

const CONTRACT_ID := &"ysbzs.damage-mechanic-port.v2"
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


func battle_round() -> int:
	return int(_authority.get("battle_round"))


func all_units() -> Array:
	return Array(_authority.get("units"))


func deal_damage(
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String,
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> Dictionary:
	return Dictionary(_authority.call("_deal_damage", source, target, amount, element, false, trace_context, damage_props))


func resolve_damage_deaths(candidates: Array) -> Array:
	return Array(_authority.call("_resolve_damage_deaths", candidates))


func resolved_stat_value(unit: Dictionary, stat_id: String, context: Dictionary) -> int:
	return int(_authority.call("_resolved_stat_value", unit, stat_id, context))


func first_adjacent_empty_cell(unit: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_first_adjacent_empty_cell", unit))


func summon_unit_on_cell(
	caster: Dictionary,
	mechanism_definition: Dictionary,
	cell: Dictionary,
	default_summon_id: String,
	display_name: String,
	default_hp: int,
	default_atk: int
) -> Dictionary:
	return Dictionary(_authority.call(
		"_summon_unit_on_cell",
		caster,
		mechanism_definition,
		cell,
		default_summon_id,
		display_name,
		default_hp,
		default_atk
	))


func direction_delta(direction: String) -> Vector2i:
	return Vector2i(_authority.call("_direction_delta", direction))


func inside(x: int, y: int) -> bool:
	return bool(_authority.call("_inside", x, y))


func unit_at(x: int, y: int) -> Dictionary:
	return Dictionary(_authority.call("unit_at", x, y))
