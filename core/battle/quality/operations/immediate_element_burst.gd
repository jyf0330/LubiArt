extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "immediate_element_burst"


func before_hit(context: RefCounted, attacker: Dictionary, target: Dictionary, slot_element: String, params: Dictionary) -> Array:
	if target.is_empty() or slot_element == "":
		return []
	var layers := int(Dictionary(context.call(
		&"cell_elements_at",
		int(target.get("x", -1)),
		int(target.get("y", -1))
	)).get(slot_element, 0))
	if layers < int(params.get("minimum_layers", 3)):
		return []
	var damage := int((layers * (layers + 1)) / 2)
	context.call(
		&"deal_damage",
		attacker,
		target,
		damage,
		slot_element,
		false,
		{"sourceType": "quality_element_burst"},
		DamagePropsScript.non_move_unpowered()
	)
	return ["%s：%s%d层提前结算，造成%d伤害。" % [
		SupportScript.effect_name(attacker),
		slot_element,
		layers,
		damage,
	]]


func profile(_params: Dictionary) -> Dictionary:
	return {"immediate_element_burst": true}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"minimum_layers": "nonnegative_int"})
