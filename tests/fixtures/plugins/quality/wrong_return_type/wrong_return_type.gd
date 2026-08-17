extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_wrong_return_type"


func modify_hit_damage(_hit_context: Dictionary, _current: int, _params: Dictionary) -> String:
	return "invalid"
