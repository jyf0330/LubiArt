extends RefCounted


func plugin_id() -> String:
	return "mech_damage_reduce_pct"


func before_damage(port: RefCounted, target: Dictionary, _source: Dictionary, amount: int, _element: String, _damage_props: Dictionary, mechanism: Dictionary) -> Dictionary:
	var rate := float(port.mechanic_param_float(target, mechanism, "rate", 0.3))
	var min_damage := int(port.mechanic_param_int(target, mechanism, "min_damage", 1))
	var damage: int = max(min_damage, int(ceil(float(amount) * (1.0 - rate))))
	return {
		"damage": damage,
		"logs": ["%s 触发百分比免伤：伤害 %d→%d。" % [String(target.get("name", "单位")), amount, damage]],
	}
