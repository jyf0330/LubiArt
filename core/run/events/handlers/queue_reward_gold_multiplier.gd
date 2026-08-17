extends RefCounted

const ParamSchemaScript := preload("res://core/run/events/run_event_operation_param_schema.gd")


func plugin_id() -> String:
	return "queue_reward_gold_multiplier"


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_reward_multiplier(params)


func execute(port: RefCounted, event: Dictionary, context: Dictionary, params: Dictionary) -> Dictionary:
	return Dictionary(port.queue_outer_run(event, context, "reward_gold_multiplier", int(params["percent"])))
