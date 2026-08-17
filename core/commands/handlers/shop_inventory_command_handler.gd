extends RefCounted

const ACTION_TYPES: Array[String] = [
	"ENTER_SHOP", "BACK_TO_ROUTE", "EXIT_SHOP", "BUY_OFFER", "DROP_ITEM_ON_TARGET",
	"ROLL_SHOP", "APPLY_SHOP_EVENT", "FREEZE_OFFER", "UNFREEZE_OFFER",
	"SELL_UNIT", "TOGGLE_UNIT_ACTIVE"
]
const PORT_CONTRACT_ID := &"ysbzs.shop-inventory-command-port.v1"


func action_types() -> Array[String]:
	return ACTION_TYPES.duplicate()


func execute(port: RefCounted, action_type: String, action: Dictionary) -> bool:
	if not _accepts(port):
		return false
	match action_type:
		"ENTER_SHOP":
			return port.enter_shop(action)
		"BACK_TO_ROUTE", "EXIT_SHOP":
			port.back_to_route()
			return true
		"BUY_OFFER":
			return port.buy_offer(_offer_id(action))
		"DROP_ITEM_ON_TARGET":
			return port.drop_item_on_target(action)
		"ROLL_SHOP":
			return port.roll_shop()
		"APPLY_SHOP_EVENT":
			return port.apply_shop_event(String(action.get("eventId", action.get("event_id", action.get("id", "")))))
		"FREEZE_OFFER":
			return port.set_offer_frozen(_offer_id(action), true)
		"UNFREEZE_OFFER":
			return port.set_offer_frozen(_offer_id(action), false)
		"SELL_UNIT":
			return port.sell_unit(_unit_id(action))
		"TOGGLE_UNIT_ACTIVE":
			return port.toggle_unit_active(_unit_id(action))
		_:
			return false


func _unit_id(action: Dictionary) -> String:
	return String(action.get("petId", action.get("pet_id", action.get("instanceId", action.get("instance_id", action.get("unitId", action.get("id", "")))))))


func _offer_id(action: Dictionary) -> String:
	return String(action.get("offer_id", action.get("offerId", action.get("id", ""))))


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
