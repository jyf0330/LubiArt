extends RefCounted


func plugin_id() -> String:
	return "mech_last_stand_shield"


func after_damage(port: RefCounted, target: Dictionary, _source: Dictionary, _amount: int, _damage_props: Dictionary, mechanism: Dictionary) -> Array:
	var max_hp: int = max(1, int(target.get("max_hp", target.get("maxHp", target.get("hp", 1)))))
	var hp_now := int(target.get("hp", 0))
	var flags := Dictionary(target.get("flags", {}))
	if bool(flags.get("lastStand", false)) or hp_now > int(ceil(float(max_hp) * 0.3)):
		return []
	var shield_gain := int(port.mechanic_param_int(target, mechanism, "shield", 8))
	var shield_before := int(target.get("shield", 0))
	flags["lastStand"] = true
	target["flags"] = flags
	target["shield"] = shield_before + shield_gain
	return ["%s 残血触发护盾：护盾 %d→%d。" % [String(target.get("name", "单位")), shield_before, int(target.get("shield", 0))]]
