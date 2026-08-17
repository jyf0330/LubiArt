extends RefCounted


func plugin_id() -> String:
	return "fixture_wrong_return"


func project_death_preview(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Array:
	return []
