extends RefCounted


func plugin_id() -> String:
	return "mech_trap_stack_trigger"


func project_trap_entry(
	_unit: Dictionary,
	_mechanism: Dictionary,
	_facts: Dictionary
) -> Dictionary:
	return {"allow": true}
