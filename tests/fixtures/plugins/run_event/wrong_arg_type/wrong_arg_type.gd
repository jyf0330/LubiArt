extends RefCounted

func plugin_id() -> String:
	return "fixture_run_event_wrong_arg_type"

func _validate_params(_params: Dictionary) -> Array[String]:
	return []

func execute(_port: Dictionary, _event: Dictionary, _context: Dictionary, _params: Dictionary) -> Dictionary:
	return {"ok": true, "code": "ok"}
