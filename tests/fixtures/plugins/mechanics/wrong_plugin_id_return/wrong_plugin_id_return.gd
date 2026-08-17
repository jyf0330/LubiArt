extends RefCounted


func plugin_id() -> StringName:
	return &"fixture_wrong_plugin_id_return"


func project_threat_redirect(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
	return {}
