extends RefCounted

func plugin_id() -> String:
	return "fixture_run_event_alpha"

func _validate_params(params: Dictionary) -> Array[String]:
	return [] if params.is_empty() else ["unknown params"]

func execute(_port: RefCounted, _event: Dictionary, _context: Dictionary, _params: Dictionary) -> Dictionary:
	return {"ok": true, "code": "fixture_alpha"}
