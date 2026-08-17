extends RefCounted


func plugin_id() -> String:
	return "fixture_quality_zero_hook"


func _helper() -> String:
	return "private helpers are allowed"
