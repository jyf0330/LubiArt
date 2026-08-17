extends RefCounted

func plugin_id() -> String:
	return "fixture_run_event_wrong_return_type"

func _validate_params(_params: Dictionary) -> Array[String]:
	return []

func execute(_port: RefCounted, _event: Dictionary, _context: Dictionary, _params: Dictionary) -> Array:
	return []
