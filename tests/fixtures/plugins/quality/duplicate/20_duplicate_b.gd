extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_duplicate"


func after_attack(
	_context: RefCounted,
	_attacker: Dictionary,
	_option: Dictionary,
	_targets: Array,
	_params: Dictionary
) -> Array:
	return []
