extends RefCounted


func plugin_id() -> String:
	return "fixture_untyped_hook"


func project_element_settlement(_unit, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
	return {}
