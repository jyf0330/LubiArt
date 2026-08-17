extends "res://core/battle/mechanics/handlers/bases/round_handler_base.gd"


func plugin_id() -> String:
	return "mech_grow_atk_each_round"


func round_start(port: RefCounted, unit: Dictionary, _side: String, mechanism: Dictionary) -> Array:
	return _attack_gain(port, unit, mechanism)
