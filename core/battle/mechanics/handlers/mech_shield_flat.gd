extends RefCounted


func plugin_id() -> String:
	return "mech_shield_flat"


func on_battle_start(port: RefCounted, unit: Dictionary, mechanism: Dictionary) -> Array:
	var shield_gain := int(port.mechanic_param_int(unit, mechanism, "shield", 6))
	var before := int(unit.get("shield", 0))
	unit["shield"] = before + shield_gain
	return ["%s 触发开场护盾：护盾 %d→%d。" % [String(unit.get("name", "单位")), before, int(unit.get("shield", 0))]]
