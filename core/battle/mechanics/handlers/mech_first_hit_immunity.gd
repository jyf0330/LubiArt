extends RefCounted


func plugin_id() -> String:
	return "mech_first_hit_immunity"


func before_damage(_port: RefCounted, target: Dictionary, _source: Dictionary, amount: int, _element: String, _damage_props: Dictionary, _mechanism: Dictionary) -> Dictionary:
	var flags := Dictionary(target.get("flags", {}))
	if bool(flags.get("firstHitImmunityUsed", false)):
		return {"damage": amount, "logs": []}
	flags["firstHitImmunityUsed"] = true
	target["flags"] = flags
	return {
		"damage": 0,
		"logs": ["%s 触发首次免疫：伤害 %d→0。" % [String(target.get("name", "单位")), amount]],
	}
