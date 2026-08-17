extends RefCounted

const ParamSchemaScript := preload("res://core/run/events/run_event_operation_param_schema.gd")


func plugin_id() -> String:
	return "refill_shop_pool"


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_refill_shop_pool(params)


func execute(port: RefCounted, event: Dictionary, context: Dictionary, params: Dictionary) -> Dictionary:
	var refill_context := context.duplicate(true)
	refill_context["event_name"] = String(event.get("name", params["pool_id"]))
	return Dictionary(port.refill_shop_pool(
		String(params["pool_id"]),
		int(params["minimum_slots"]),
		refill_context
	))
