extends RefCounted

const PORT_CONTRACT_ID := &"ysbzs.shop-effect-port.v2"


func plugin_id() -> String:
	return "next_discount"


func execute(port: RefCounted, _offer: Dictionary, effect: Dictionary) -> Dictionary:
	if not _accepts(port) or String(effect.get("type", "")) != plugin_id():
		return {}
	var value: int = max(1, int(effect.get("value", 1)))
	var discount: int = int(port.set_next_discount(value))
	return {"type": plugin_id(), "text": "下一次生成商品享受%d%%折扣" % discount}


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
