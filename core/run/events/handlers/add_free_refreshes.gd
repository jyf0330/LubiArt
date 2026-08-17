extends RefCounted

const ParamSchemaScript := preload("res://core/run/events/run_event_operation_param_schema.gd")


func plugin_id() -> String:
	return "add_free_refreshes"


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_positive_amount(params)


func execute(port: RefCounted, _event: Dictionary, _context: Dictionary, params: Dictionary) -> Dictionary:
	return Dictionary(port.add_free_refreshes(int(params["amount"])))
