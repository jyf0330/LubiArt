extends RefCounted

const ParamSchemaScript := preload("res://core/run/events/run_event_operation_param_schema.gd")


func plugin_id() -> String:
	return "noop"


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_empty(params)


func execute(_port: RefCounted, _event: Dictionary, _context: Dictionary, _params: Dictionary) -> Dictionary:
	return {"ok": true, "code": "noop"}
