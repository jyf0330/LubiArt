extends RefCounted


func plugin_id() -> String:
	return "fixture_wrong_arg_class"


func on_battle_start(_port: Node, _unit: Dictionary, _mechanism: Dictionary) -> Array:
	return []
