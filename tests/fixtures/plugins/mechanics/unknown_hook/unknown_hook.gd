extends RefCounted


func plugin_id() -> String:
	return "fixture_unknown_hook"


func on_battle_start(_port: RefCounted, _unit: Dictionary, _mechanism: Dictionary) -> Array:
	return []


func during_round(_port: RefCounted, _unit: Dictionary) -> Array:
	return []
