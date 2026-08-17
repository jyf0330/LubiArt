extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_wrong_arity"


func modify_hit_damage(_current: int, _params: Dictionary) -> int:
	return 0
