extends RefCounted


func plugin_id() -> String:
	return "mech_water_heal_on_layer"


func after_element(port: RefCounted, caster: Dictionary, _target: Dictionary, element: String, layers: int, _cell: Dictionary, _mechanism: Dictionary) -> Array:
	if element != "水":
		return []
	port.heal_unit(caster, layers)
	return ["%s 施加水层后回复%d。" % [String(caster.get("name", "单位")), layers]]
