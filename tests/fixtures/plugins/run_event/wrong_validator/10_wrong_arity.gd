extends RefCounted

func plugin_id() -> String:
	return "fixture_run_event_wrong_validator_arity"

func _validate_params() -> Array[String]:
	return []

func execute(_port: RefCounted, _event: Dictionary, _context: Dictionary, _params: Dictionary) -> Dictionary:
	return {"ok": true, "code": "ok"}
