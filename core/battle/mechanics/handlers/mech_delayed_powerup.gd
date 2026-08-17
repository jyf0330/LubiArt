extends "res://core/battle/mechanics/handlers/bases/round_handler_base.gd"


func plugin_id() -> String:
	return "mech_delayed_powerup"


func round_start(port: RefCounted, unit: Dictionary, _side: String, mechanism: Dictionary) -> Array:
	if not _accepts_round_port(port):
		return []
	var trigger_round: int = int(port.mechanic_param_int(unit, mechanism, "round", 3))
	if int(port.battle_round()) < trigger_round:
		return []
	return _attack_gain(port, unit, mechanism)
