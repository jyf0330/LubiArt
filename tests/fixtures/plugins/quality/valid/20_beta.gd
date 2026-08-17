extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_beta"


func modify_hit_damage(_hit_context: Dictionary, current: int, params: Dictionary) -> int:
	return current + int(params.get("amount", 0))


func _validate_params(_params: Dictionary) -> Array:
	return []
