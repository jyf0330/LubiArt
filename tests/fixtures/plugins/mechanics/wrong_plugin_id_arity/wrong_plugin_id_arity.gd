extends RefCounted


func plugin_id(_suffix: String) -> String:
	return "fixture_wrong_plugin_id_arity"


func project_threat_redirect(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
	return {}
