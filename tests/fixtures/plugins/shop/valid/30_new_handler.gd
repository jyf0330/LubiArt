extends RefCounted


func plugin_id() -> String:
	return "fixture_new_handler"


func execute(_port: RefCounted, _offer: Dictionary, effect: Dictionary) -> Dictionary:
	return {"type": plugin_id(), "text": "fixture:%d" % int(effect.get("value", 0))}
