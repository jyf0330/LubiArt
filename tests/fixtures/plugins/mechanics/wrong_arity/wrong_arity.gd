extends RefCounted


func plugin_id() -> String:
	return "fixture_wrong_arity"


func before_damage(
	_port: RefCounted,
	_target: Dictionary,
	_source: Dictionary,
	_amount: int,
	_damage_props: Dictionary,
	_mechanism: Dictionary
) -> Dictionary:
	return {}
