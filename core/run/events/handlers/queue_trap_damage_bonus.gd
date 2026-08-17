extends RefCounted

const ParamSchemaScript := preload("res://core/run/events/run_event_operation_param_schema.gd")


func plugin_id() -> String:
	return "queue_trap_damage_bonus"


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_nonnegative_amount(params)


func execute(port: RefCounted, event: Dictionary, context: Dictionary, params: Dictionary) -> Dictionary:
	return Dictionary(port.queue_battle_prep(event, context, "trap_damage_bonus", int(params["amount"])))
