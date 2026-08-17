extends RefCounted

const ParamSchemaScript := preload("res://core/run/events/run_event_operation_param_schema.gd")


func plugin_id() -> String:
	return "upgrade_first_eligible_pet"


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_empty(params)


func execute(port: RefCounted, event: Dictionary, _context: Dictionary, _params: Dictionary) -> Dictionary:
	return Dictionary(port.upgrade_first_eligible_pet(event))
