extends RefCounted


func plugin_id() -> String:
	return "mech_armor_flat"


func before_damage(port: RefCounted, target: Dictionary, _source: Dictionary, amount: int, _element: String, _damage_props: Dictionary, mechanism: Dictionary) -> Dictionary:
	var armor := int(port.mechanic_param_int(target, mechanism, "armor", 2))
	var damage: int = max(0, amount - armor)
	return {
		"damage": damage,
		"logs": ["%s 触发护甲减伤：伤害 %d→%d。" % [String(target.get("name", "单位")), amount, damage]],
	}
