extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_shop_discount_after_clear"


func battle_end(port: RefCounted, unit: Dictionary, win: bool, reward_state: Dictionary, mechanism: Dictionary) -> Dictionary:
	var next := _reward_copy(reward_state)
	if not _accepts_lifecycle_port(port) or not win or int(unit.get("hp", 0)) <= 0:
		return next
	var before := int(next.get("discount_to", next.get("discount_from", 0)))
	var after: int = max(before, 50)
	next["discount_to"] = after
	next["discount_requested"] = true
	Array(next["logs"]).append("%s 让下一商店获得50%%折扣。" % String(unit.get("name", "单位")))
	Array(next["applied"]).append({
		"mechanic_id": plugin_id(),
		"unit_id": String(unit.get("id", "")),
		"name": String(mechanism.get("name", plugin_id())),
		"discount_from": before,
		"discount_to": after,
	})
	return next
