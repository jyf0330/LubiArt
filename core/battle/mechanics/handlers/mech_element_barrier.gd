extends RefCounted


func plugin_id() -> String:
	return "mech_element_barrier"


func before_damage(port: RefCounted, target: Dictionary, _source: Dictionary, amount: int, element: String, _damage_props: Dictionary, mechanism: Dictionary) -> Dictionary:
	if element == String(target.get("element", "")):
		return {"damage": amount, "logs": []}
	var reduce := int(port.mechanic_param_int(target, mechanism, "reduce", 3))
	var damage: int = max(0, amount - reduce)
	return {
		"damage": damage,
		"logs": ["%s 触发元素屏障：伤害 %d→%d。" % [String(target.get("name", "单位")), amount, damage]],
	}
