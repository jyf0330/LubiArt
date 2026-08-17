extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "narrow_to_target_mode"


func attack_option_for_target(attacker: Dictionary, target: Dictionary, option: Dictionary, params: Dictionary) -> Dictionary:
	var runtime := Dictionary(attacker.get("quality_runtime", {}))
	if String(runtime.get("mode", "")) != String(params.get("mode", "")):
		return option
	var narrowed := option.duplicate(true)
	narrowed["cells"] = [{
		"x": int(target.get("x", -1)),
		"y": int(target.get("y", -1)),
	}]
	return narrowed


func profile(params: Dictionary) -> Dictionary:
	return {"narrow_to_target_mode": String(params.get("mode", ""))}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"mode": "nonempty_string"})
