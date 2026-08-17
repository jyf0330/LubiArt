extends RefCounted

const PORT_CONTRACT_ID := &"ysbzs.shop-effect-port.v2"


func plugin_id() -> String:
	return "duplicate_pet"


func execute(port: RefCounted, offer: Dictionary, effect: Dictionary) -> Dictionary:
	if not _accepts(port) or String(effect.get("type", "")) != plugin_id() or not port.has_roster():
		return {}
	var duplicated: Dictionary = port.duplicate_pet(String(offer.get("id", "shop_duplicate")))
	if duplicated.is_empty():
		return {}
	var merge_text := "并合成到%s" % String(duplicated.get("quality", "")) if bool(duplicated.get("merged", false)) else ""
	return {"type": plugin_id(), "text": "复制%s%s" % [String(duplicated.get("name", "宠物")), merge_text]}


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
