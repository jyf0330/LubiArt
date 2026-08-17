extends RefCounted


func plugin_id() -> String:
	return "fixture_duplicate"


func round_start(_port: RefCounted, _unit: Dictionary, _side: String, _mechanism: Dictionary) -> Array:
	return []
