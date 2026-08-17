extends RefCounted


func plugin_id() -> String:
	return "fixture_duplicate"


func execute(_port: RefCounted, _offer: Dictionary, _effect: Dictionary) -> Dictionary:
	return {}
