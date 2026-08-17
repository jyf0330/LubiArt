extends RefCounted

const CONTRACT_ID := &"ysbzs.shop-inventory-command-port.v1"
const DEFAULT_MAX_SHOP_OFFERS := 10

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func enter_shop(action: Dictionary) -> bool:
	var active_shop_pool := String(action.get("poolId", action.get("pool_id", _authority.get("active_shop_pool"))))
	_authority.set("active_shop_pool", active_shop_pool)
	_authority.set("active_shop_seed_context", String(action.get("seedContext", action.get("seed_context", ""))))
	_authority.set("shop_context_roll_count", 0)
	var active_stall := Dictionary(_authority.call("_stall_for_node", {
		"shopPoolId": active_shop_pool,
		"stallId": String(action.get("stallId", action.get("stall_id", ""))),
		"slots": int(action.get("slots", DEFAULT_MAX_SHOP_OFFERS)),
		"name": String(action.get("name", active_shop_pool)),
	}))
	_authority.set("active_stall", active_stall)
	if not bool(active_stall.get("available", true)):
		_authority.call("_log", "进入商店失败：%s 在第%d天没有开放摊位。" % [
			String(active_stall.get("location_name", active_shop_pool)),
			int(_authority.get("day")),
		])
		return false
	active_shop_pool = String(active_stall.get("pool_id", active_shop_pool))
	_authority.set("active_shop_pool", active_shop_pool)
	_authority.set("shop_free_rolls", int(active_stall.get("free_rerolls", 0)))
	_authority.set("shop_paid_refreshes", 0)
	_authority.set("shop_offers", _authority.call(
		"_shop_offers_for_pool",
		active_shop_pool,
		int(active_stall.get("slots", DEFAULT_MAX_SHOP_OFFERS))
	))
	if not bool(_authority.call("_transition_phase", "shop")):
		return false
	_authority.set("selected_unit_id", "")
	_authority.call("_log", "进入商店 %s。" % active_shop_pool)
	return true


func back_to_route() -> void:
	_authority.call("back_to_route")


func buy_offer(offer_id: String) -> bool:
	return bool(_authority.call("buy_offer", offer_id))


func drop_item_on_target(action: Dictionary) -> bool:
	return bool(_authority.call("drop_item_on_target", action))


func roll_shop() -> bool:
	return bool(_authority.call("roll_shop"))


func apply_shop_event(event_id: String) -> bool:
	return bool(_authority.call("apply_shop_event", event_id))


func set_offer_frozen(offer_id: String, frozen: bool) -> bool:
	return bool(_authority.call("set_offer_frozen", offer_id, frozen))


func sell_unit(unit_id: String) -> bool:
	return bool(_authority.call("sell_unit", unit_id))


func toggle_unit_active(unit_id: String) -> bool:
	return bool(_authority.call("toggle_unit_active", unit_id))
