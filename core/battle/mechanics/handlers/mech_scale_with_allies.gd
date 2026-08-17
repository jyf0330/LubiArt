extends "res://core/battle/mechanics/handlers/bases/round_handler_base.gd"


func plugin_id() -> String:
	return "mech_scale_with_allies"


func round_start(port: RefCounted, unit: Dictionary, _side: String, mechanism: Dictionary) -> Array:
	if not _accepts_round_port(port) or unit.is_empty():
		return []
	var ally_count := 0
	var unit_side := String(unit.get("side", ""))
	var unit_id := String(unit.get("id", ""))
	for other_value in port.units_for_side(unit_side, true):
		var other := Dictionary(other_value)
		if String(other.get("id", "")) != unit_id:
			ally_count += 1
	if ally_count <= 0:
		return []
	var atk_per_ally: int = int(port.mechanic_param_int(unit, mechanism, "atk_per_ally", 1))
	var shield_per_ally: int = int(port.mechanic_param_int(unit, mechanism, "shield_per_ally", 1))
	var atk_gain: int = ally_count * atk_per_ally
	var shield_gain: int = ally_count * shield_per_ally
	var atk_before: int = int(unit.get("atk", unit.get("attack", 0)))
	var shield_before: int = int(unit.get("shield", 0))
	unit["atk"] = atk_before + atk_gain
	unit["shield"] = shield_before + shield_gain
	return ["%s 因%d名同阵营单位获得攻击+%d、护盾+%d。" % [
		String(unit.get("name", "单位")), ally_count, atk_gain, shield_gain
	]]
