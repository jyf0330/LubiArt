extends RefCounted

func plugin_id() -> String:
	return "fixture_run_event_missing_validator"

func execute(_port: RefCounted, _event: Dictionary, _context: Dictionary, _params: Dictionary) -> Dictionary:
	return {"ok": true, "code": "ok"}
