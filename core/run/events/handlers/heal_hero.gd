extends RefCounted

const ParamSchemaScript := preload("res://core/run/events/run_event_operation_param_schema.gd")


func plugin_id() -> String:
	return "heal_hero"


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_nonnegative_amount(params)


func execute(port: RefCounted, _event: Dictionary, _context: Dictionary, params: Dictionary) -> Dictionary:
	return Dictionary(port.heal_hero(int(params["amount"])))
