extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_wrong_validator_arity"


func profile(_params: Dictionary) -> Dictionary:
	return {}


func _validate_params() -> Array:
	return []
