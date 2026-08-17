extends RefCounted


func plugin_id() -> String:
	return "mech_earth_shield_on_layer"


func after_element(_port: RefCounted, caster: Dictionary, _target: Dictionary, element: String, layers: int, _cell: Dictionary, _mechanism: Dictionary) -> Array:
	caster["shield"] = int(caster.get("shield", 0)) + layers
	return ["%s 施加%s层后护盾+%d。" % [String(caster.get("name", "单位")), element, layers]]
