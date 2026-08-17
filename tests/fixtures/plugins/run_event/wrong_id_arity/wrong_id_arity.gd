extends RefCounted

func plugin_id(_value: String) -> String:
	return "fixture_run_event_wrong_id_arity"

func _validate_params(_params: Dictionary) -> Array[String]:
	return []

func execute(_port: RefCounted, _event: Dictionary, _context: Dictionary, _params: Dictionary) -> Dictionary:
	return {"ok": true, "code": "ok"}
