extends RefCounted

const PORT_CONTRACT_ID := &"ysbzs.shop-effect-port.v2"


func plugin_id() -> String:
	return "free_refresh"


func execute(port: RefCounted, _offer: Dictionary, effect: Dictionary) -> Dictionary:
	if not _accepts(port) or String(effect.get("type", "")) != plugin_id():
		return {}
	var value: int = max(1, int(effect.get("value", 1)))
	port.add_free_refreshes(value)
	return {"type": plugin_id(), "text": "获得%d次免费刷新" % value}


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
