extends "res://core/battle/mechanics/handlers/bases/round_handler_base.gd"


func plugin_id() -> String:
	return "mech_water_cleanse_debuff"


func round_start(port: RefCounted, unit: Dictionary, _side: String, mechanism: Dictionary) -> Array:
	if not _accepts_round_port(port) or unit.is_empty():
		return []
	var limit: int = max(1, int(port.mechanic_param_int(unit, mechanism, "cleanse", 1)))
	var cleansed := 0
	for unit_value in port.units_for_side(String(unit.get("side", "")), true):
		if cleansed >= limit:
			break
		var target := Dictionary(unit_value)
		if int(target.get("incoming_damage_bonus", 0)) > 0:
			target["incoming_damage_bonus"] = 0
			cleansed += 1
	return ["水流净化了 %d 个负面状态。" % cleansed] if cleansed > 0 else []
