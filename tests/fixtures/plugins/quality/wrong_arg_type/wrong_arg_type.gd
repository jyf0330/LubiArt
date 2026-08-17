extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_wrong_arg_type"


func modify_hit_damage(_hit_context: Array, _current: int, _params: Dictionary) -> int:
	return 0
