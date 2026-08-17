extends RefCounted


func plugin_id() -> String:
	return "mech_soften_when_hit"


func after_hit(_port: RefCounted, target: Dictionary, _source: Dictionary, _amount: int, _damage_props: Dictionary, _mechanism: Dictionary) -> Array:
	var defense_before := int(target.get("def", 0))
	target["def"] = max(0, defense_before - 1)
	return ["%s 受击后防御-1：防御 %d→%d。" % [String(target.get("name", "单位")), defense_before, int(target.get("def", 0))]]
