extends RefCounted


func plugin_id() -> String:
	return "fixture_shared_before_damage"


func before_damage(
	_port: RefCounted,
	_target: Dictionary,
	_source: Dictionary,
	amount: int,
	_element: String,
	_damage_props: Dictionary,
	_mechanism: Dictionary
) -> Dictionary:
	return {"damage": max(0, amount - 2), "logs": ["fixture shared"]}
