extends RefCounted

const ParamSchemaScript := preload("res://core/run/events/run_event_operation_param_schema.gd")


func plugin_id() -> String:
	return "set_next_discount"


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_discount(params)


func execute(port: RefCounted, _event: Dictionary, _context: Dictionary, params: Dictionary) -> Dictionary:
	return Dictionary(port.set_next_discount(int(params["percent"])))
