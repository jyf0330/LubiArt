extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_wrong_validator_types"


func profile(_params: Dictionary) -> Dictionary:
	return {}


func _validate_params(_params: Array) -> Dictionary:
	return {}
