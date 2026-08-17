extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "shield_behind"


func before_attack(context: RefCounted, attacker: Dictionary, option: Dictionary, params: Dictionary) -> Array:
	var direction := String(option.get("direction", "right"))
	var delta := context.call(&"direction_delta", direction) as Vector2i
	var ally := Dictionary(context.call(
		&"unit_at",
		int(attacker.get("x", 0)) - delta.x,
		int(attacker.get("y", 0)) - delta.y
	))
	if ally.is_empty() \
			or String(ally.get("side", "")) != "player" \
			or String(ally.get("id", "")) == String(attacker.get("id", "")):
		return []
	var before := int(ally.get("shield", 0))
	ally["shield"] = before + int(params.get("amount", 0))
	return ["%s 覆盖背后 %s：护盾 %d→%d。" % [
		SupportScript.effect_name(attacker),
		String(ally.get("name", "我方")),
		before,
		int(ally.get("shield", 0)),
	]]


func profile(params: Dictionary) -> Dictionary:
	return {"before_attack_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "int"})
