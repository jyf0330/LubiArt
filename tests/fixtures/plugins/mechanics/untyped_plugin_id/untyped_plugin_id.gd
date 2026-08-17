extends RefCounted


func plugin_id():
	return "fixture_untyped_plugin_id"


func project_threat_redirect(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
	return {}
