extends RefCounted


func plugin_id() -> String:
	return "fixture_untyped_hook_return"


func project_death_preview(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary):
	return {}
