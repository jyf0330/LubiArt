extends RefCounted


func plugin_id() -> String:
	return "mech_wind_slow_ap"


func attacker_after_hit(port: RefCounted, attacker: Dictionary, target: Dictionary, _amount: int, element: String, _direction: String, mechanism: Dictionary) -> Array:
	var ap_delta := int(port.mechanic_param_int(attacker, mechanism, "ap_delta", -1))
	if ap_delta == 0:
		return []
	var before: int = int(target.get("ap", 0))
	var after: int = max(0, before + ap_delta)
	target["ap"] = after
	return ["%s 触发%s：%s元素降低%s行动力，AP %d→%d。" % [
		String(attacker.get("name", "单位")), String(mechanism.get("name", plugin_id())), element,
		String(target.get("name", "目标")), before, after,
	]]
