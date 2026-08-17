extends RefCounted

func plugin_id() -> String:
	return "fixture_run_event_zero_execute"

func _validate_params(_params: Dictionary) -> Array[String]:
	return []
