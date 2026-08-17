extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_unknown_hook"


func profile(_params: Dictionary) -> Dictionary:
	return {}


func during_attack(_context: RefCounted, _unit: Dictionary) -> Array:
	return []
