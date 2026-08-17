extends RefCounted


func plugin_id() -> String:
	return "mech_damage_cap_per_round"


func before_damage(port: RefCounted, target: Dictionary, _source: Dictionary, amount: int, _element: String, _damage_props: Dictionary, mechanism: Dictionary) -> Dictionary:
	var cap := int(port.mechanic_param_int(target, mechanism, "cap", 8))
	var used: int = max(0, int(target.get("roundDamageTaken", target.get("round_damage_taken", 0))))
	var allowed: int = max(0, cap - used)
	if amount <= allowed:
		return {"damage": amount, "logs": []}
	return {
		"damage": allowed,
		"logs": ["%s 触发损血上限：伤害 %d→%d。" % [String(target.get("name", "单位")), amount, allowed]],
	}
