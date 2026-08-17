extends RefCounted

const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")


func plugin_id() -> String:
	return "mech_consume_layers_grow"


func after_element(port: RefCounted, caster: Dictionary, _target: Dictionary, _element: String, _layers: int, _cell: Dictionary, mechanism: Dictionary) -> Array:
	var caster_x := int(caster.get("x", -1))
	var caster_y := int(caster.get("y", -1))
	if not bool(port.inside(caster_x, caster_y)):
		return []
	var cell_layers := Dictionary(port.cell_elements_at(caster_x, caster_y))
	var wanted_element := String(port.mechanic_param_string(caster, mechanism, "element", "any"))
	var total_layers := 0
	for layer_element_value in ElementRulesScript.SETTLEMENT_ELEMENTS:
		var layer_element := String(layer_element_value)
		if wanted_element != "any" and wanted_element != layer_element:
			continue
		var layer_count := int(cell_layers.get(layer_element, 0))
		if layer_count <= 0:
			continue
		total_layers += layer_count
		port.clear_element_from_cell(caster_x, caster_y, layer_element)
	if total_layers <= 0:
		return []
	var atk_per_layer: int = max(0, int(port.mechanic_param_int(caster, mechanism, "atk_per_layer", 1)))
	var atk_gain := total_layers * atk_per_layer
	caster["atk"] = int(caster.get("atk", caster.get("attack", 0))) + atk_gain
	return ["%s 吸收元素，攻击提升%d。" % [String(caster.get("name", "单位")), atk_gain]]
