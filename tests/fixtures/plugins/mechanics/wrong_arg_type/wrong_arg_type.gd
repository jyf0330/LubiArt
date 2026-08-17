extends RefCounted


func plugin_id() -> String:
	return "fixture_wrong_arg_type"


func project_trap_entry(_unit: Array, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
	return {}
