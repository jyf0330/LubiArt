extends RefCounted

const ParamSchemaScript := preload("res://core/run/events/run_event_operation_param_schema.gd")


func plugin_id() -> String:
	return "select_reward_pool"


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_reward_pool(params)


func execute(port: RefCounted, _event: Dictionary, _context: Dictionary, params: Dictionary) -> Dictionary:
	return Dictionary(port.select_reward_pool(String(params["pool_id"])))
