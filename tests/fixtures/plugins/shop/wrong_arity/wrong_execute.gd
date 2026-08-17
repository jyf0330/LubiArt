extends RefCounted


func plugin_id() -> String:
	return "fixture_wrong_arity"


func execute(_port: RefCounted, _effect: Dictionary) -> Dictionary:
	return {}
