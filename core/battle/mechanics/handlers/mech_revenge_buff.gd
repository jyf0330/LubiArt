extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_revenge_buff"


func after_ally_death(port: RefCounted, receiver: Dictionary, defeated: Dictionary, mechanism: Dictionary) -> Array:
	if not _accepts_lifecycle_port(port) or receiver.is_empty() or defeated.is_empty() or int(receiver.get("hp", 0)) <= 0:
		return []
	var atk_gain := int(port.mechanic_param_int(receiver, mechanism, "atk", 1))
	var shield_gain := int(port.mechanic_param_int(receiver, mechanism, "shield", 2))
	var atk_before := int(receiver.get("atk", receiver.get("attack", 0)))
	var shield_before := int(receiver.get("shield", 0))
	receiver["atk"] = atk_before + atk_gain
	receiver["shield"] = shield_before + shield_gain
	return ["%s 触发%s：因%s死亡获得复仇强化，攻击 %d→%d，护盾 %d→%d。" % [
		String(receiver.get("name", "单位")),
		String(mechanism.get("name", plugin_id())),
		String(defeated.get("name", "友方")),
		atk_before,
		int(receiver.get("atk", 0)),
		shield_before,
		int(receiver.get("shield", 0)),
	]]
