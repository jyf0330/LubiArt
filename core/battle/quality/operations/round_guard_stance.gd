extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "round_guard_stance"


func round_start(_context: RefCounted, unit: Dictionary, params: Dictionary) -> Array:
	var runtime := Dictionary(unit.get("quality_runtime", {}))
	var max_hp: int = max(1, int(unit.get("max_hp", unit.get("hp", 1))))
	var hp := int(unit.get("hp", max_hp))
	var mode: String = String(runtime.get("mode", "")) if bool(runtime.get("mode_explicit", false)) else ""
	var guard_mode := String(params.get("guard_mode", "守"))
	if mode == "":
		mode = guard_mode if hp <= max_hp / 2 else String(params.get("attack_mode", "攻"))
	runtime["mode"] = mode
	unit["quality_runtime"] = runtime
	if mode != guard_mode:
		return []
	var before := int(unit.get("shield", 0))
	unit["shield"] = before + int(params.get("amount", 0))
	return ["%s 触发%s·%s：护盾 %d→%d。" % [
		String(unit.get("name", "我方")),
		SupportScript.effect_name(unit),
		guard_mode,
		before,
		int(unit.get("shield", 0)),
	]]


func _validate_params(params: Dictionary) -> Array[String]:
	var errors := ParamSchemaScript.validate(params, {
		"attack_mode": "nonempty_string",
		"guard_mode": "nonempty_string",
		"amount": "int",
	})
	if errors.is_empty() and String(params.get("attack_mode", "")) == String(params.get("guard_mode", "")):
		errors.append("parameters 'attack_mode' and 'guard_mode' must differ.")
	return errors
