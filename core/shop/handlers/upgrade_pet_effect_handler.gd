extends RefCounted

const PORT_CONTRACT_ID := &"ysbzs.shop-effect-port.v2"


func plugin_id() -> String:
	return "upgrade_pet"


func execute(port: RefCounted, offer: Dictionary, effect: Dictionary) -> Dictionary:
	if not _accepts(port) or String(effect.get("type", "")) != plugin_id():
		return {}
	var upgraded: Dictionary = port.upgrade_pet(String(offer.get("id", "shop_upgrade")))
	if upgraded.is_empty():
		return {}
	return {
		"type": plugin_id(),
		"text": "%s %s→%s" % [
			String(upgraded.get("name", "宠物")),
			String(upgraded.get("quality_from", "")),
			String(upgraded.get("quality_to", "")),
		],
	}


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
