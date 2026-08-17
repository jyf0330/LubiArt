extends RefCounted


func plugin_id(_ignored: String) -> String:
	return "fixture_quality_wrong_id_arity"


func profile(_params: Dictionary) -> Dictionary:
	return {}
