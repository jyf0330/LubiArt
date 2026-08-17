extends RefCounted


func plugin_id() -> String:
	return "mech_rage_low_hp"


func after_damage(port: RefCounted, target: Dictionary, _source: Dictionary, _amount: int, _damage_props: Dictionary, mechanism: Dictionary) -> Array:
	var max_hp: int = max(1, int(target.get("max_hp", target.get("maxHp", target.get("hp", 1)))))
	var hp_now := int(target.get("hp", 0))
	var flags := Dictionary(target.get("flags", {}))
	if bool(flags.get("raged", false)) or hp_now > int(ceil(float(max_hp) * 0.5)):
		return []
	var atk_gain := int(port.mechanic_param_int(target, mechanism, "atk", 2))
	var atk_before := int(target.get("atk", target.get("attack", 0)))
	flags["raged"] = true
	target["flags"] = flags
	target["atk"] = atk_before + atk_gain
	return ["%s 低血狂怒：攻击 %d→%d。" % [String(target.get("name", "单位")), atk_before, int(target.get("atk", 0))]]
