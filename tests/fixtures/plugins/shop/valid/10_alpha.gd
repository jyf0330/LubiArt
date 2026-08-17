extends RefCounted


func plugin_id() -> String:
	return "fixture_alpha"


func execute(_port: RefCounted, _offer: Dictionary, _effect: Dictionary) -> Dictionary:
	return {"type": plugin_id(), "text": "fixture:alpha"}
