extends RefCounted

const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")

## Pure catalog projection shared by roster normalization, action-slot
## projection and battle geometry.


static func shape_catalog(game_data: Dictionary) -> Array:
	return Array(Dictionary(game_data.get("battle", {})).get("shape_catalog", []))


static func shape_id_for_unit(unit: Dictionary, game_data: Dictionary) -> String:
	var explicit_id := String(unit.get("shape_id", "")).strip_edges()
	if explicit_id != "":
		return explicit_id
	var text := String(unit.get("shape", "")).strip_edges()
	for shape_value in shape_catalog(game_data):
		if typeof(shape_value) != TYPE_DICTIONARY:
			continue
		var shape := Dictionary(shape_value)
		var shape_id := String(shape.get("shape_id", "")).strip_edges()
		var label := String(shape.get("label", "")).strip_edges()
		if shape_id != "" and (text == shape_id or text.begins_with(shape_id) or text.contains("形状%s" % shape_id) or text == label):
			return shape_id
	return "01"


static func shape_definition(unit: Dictionary, game_data: Dictionary) -> Dictionary:
	var wanted_id := shape_id_for_unit(unit, game_data)
	for shape_value in shape_catalog(game_data):
		if typeof(shape_value) != TYPE_DICTIONARY:
			continue
		var shape := Dictionary(shape_value)
		if String(shape.get("shape_id", "")) == wanted_id:
			return shape
	return {"shape_id": "01", "label": "形状01", "offsets": [{"dr": 0, "dc": 1}]}


static func slot_elements(unit: Dictionary) -> Array:
	var elements: Array = []
	for raw in Array(unit.get("slot_elements", [])):
		var element := ElementRulesScript.canonical(String(raw))
		if element != "":
			elements.append(element)
	var slot_count: int = max(1, int(unit.get("slot_count", 3)))
	var fallback := ElementRulesScript.canonical(String(unit.get("element", "")))
	if fallback == "":
		fallback = "无"
	while elements.size() < slot_count:
		elements.append(fallback)
	return elements.slice(0, slot_count)
