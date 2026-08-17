extends RefCounted

## Versioned adapter for mechanics triggered after element application.

const CONTRACT_ID := &"ysbzs.element-mechanic-port.v1"
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


func mechanic_param_string(unit: Dictionary, definition: Dictionary, key: String, fallback: String) -> String:
	return String(_authority.call("_mechanic_param_string", unit, definition, key, fallback))


func mechanic_param_element(unit: Dictionary, definition: Dictionary, key: String, fallback: String) -> String:
	return String(_authority.call("_mechanic_param_element", unit, definition, key, fallback))


func heal_unit(unit: Dictionary, amount: int) -> int:
	return int(_authority.call("_heal_unit", unit, amount))


func summon_unit(caster: Dictionary, definition: Dictionary, cell: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_summon_unit_on_cell", caster, definition, cell))


func summon_wall(caster: Dictionary, cell: Dictionary, hp: int, duration: int) -> Dictionary:
	return Dictionary(_authority.call("_summon_wall_on_cell", caster, cell, hp, duration))


func inside(x: int, y: int) -> bool:
	return bool(_authority.call("_inside", x, y))


func apply_element_to_cell(x: int, y: int, element: String, layers: int) -> void:
	_authority.call("_apply_element_to_cell", x, y, element, layers)


func set_board_trace(x: int, y: int, trace: Dictionary) -> bool:
	return bool(_authority.call("_set_board_trace", x, y, trace))


func cell_elements_at(x: int, y: int) -> Dictionary:
	return Dictionary(_authority.call("_cell_elements_at", x, y))


func clear_element_from_cell(x: int, y: int, element: String) -> void:
	_authority.call("_clear_element_from_cell", x, y, element)
