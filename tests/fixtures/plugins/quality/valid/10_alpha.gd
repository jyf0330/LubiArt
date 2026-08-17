extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_alpha"


func round_start(_context: RefCounted, unit: Dictionary, params: Dictionary) -> Array:
	unit["fixture_quality_round"] = int(params.get("round", 0))
	return [_label()]


func profile(params: Dictionary) -> Dictionary:
	return {"fixture": String(params.get("fixture", "alpha"))}


func _validate_params(_params: Dictionary) -> Array:
	return []


func _label() -> String:
	return "fixture quality alpha"
