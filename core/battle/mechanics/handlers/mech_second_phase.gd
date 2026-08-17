extends RefCounted


func plugin_id() -> String:
	return "mech_second_phase"


func after_damage(_port: RefCounted, target: Dictionary, _source: Dictionary, _amount: int, _damage_props: Dictionary, _mechanism: Dictionary) -> Array:
	var max_hp: int = max(1, int(target.get("max_hp", target.get("maxHp", target.get("hp", 1)))))
	var hp_now := int(target.get("hp", 0))
	var flags := Dictionary(target.get("flags", {}))
	if bool(flags.get("phase2", false)) or hp_now > int(ceil(float(max_hp) * 0.5)):
		return []
	var atk_before := int(target.get("atk", target.get("attack", 0)))
	var shield_before := int(target.get("shield", 0))
	flags["phase2"] = true
	target["flags"] = flags
	target["atk"] = atk_before + 1
	target["shield"] = shield_before + 3
	return ["%s 进入第二阶段：攻击 %d→%d，护盾 %d→%d。" % [
		String(target.get("name", "单位")), atk_before, int(target.get("atk", 0)),
		shield_before, int(target.get("shield", 0)),
	]]
