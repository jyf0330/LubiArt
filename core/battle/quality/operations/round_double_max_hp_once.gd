extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "round_double_max_hp_once"


func round_start(_context: RefCounted, unit: Dictionary, params: Dictionary) -> Array:
	var runtime := Dictionary(unit.get("quality_runtime", {}))
	var flags := Dictionary(runtime.get("flags", {}))
	var flag := String(params.get("flag", "applied"))
	if bool(flags.get(flag, false)):
		return []
	var before_max := int(unit.get("max_hp", unit.get("hp", 1)))
	var before_hp := int(unit.get("hp", before_max))
	var after_max: int = min(int(params.get("cap", before_max * 2)), before_max * int(params.get("factor", 2)))
	var delta: int = max(0, after_max - before_max)
	unit["max_hp"] = after_max
	unit["hp"] = min(after_max, before_hp + delta)
	flags[flag] = true
	runtime["flags"] = flags
	unit["quality_runtime"] = runtime
	return ["%s 触发%s：最大生命 %d→%d。" % [
		String(unit.get("name", "我方")),
		SupportScript.effect_name(unit),
		before_max,
		after_max,
	]]


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {
		"factor": "positive_int",
		"cap": "positive_int",
		"flag": "nonempty_string",
	})
