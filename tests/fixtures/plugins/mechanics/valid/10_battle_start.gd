extends RefCounted


func plugin_id() -> String:
	return "fixture_battle_start"


func on_battle_start(_port: RefCounted, unit: Dictionary, _mechanism: Dictionary) -> Array:
	unit["fixture_started"] = true
	return ["fixture battle start"]
