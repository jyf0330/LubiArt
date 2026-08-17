extends "res://core/battle/mechanics/handlers/bases/round_handler_base.gd"


func plugin_id() -> String:
	return "mech_grow_shield_each_round"


func round_start(port: RefCounted, unit: Dictionary, _side: String, mechanism: Dictionary) -> Array:
	return _shield_gain(port, unit, mechanism, 2)
