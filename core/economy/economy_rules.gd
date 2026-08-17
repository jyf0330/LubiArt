extends RefCounted


static func paid_refresh_cost(completed_paid_refreshes: int) -> int:
	return mini(8, (completed_paid_refreshes + 1) * 2)


static func shop_weight(item: Dictionary, pool_id: String) -> int:
	var weights := Dictionary(item.get("weights", {}))
	if pool_id == "night_base":
		return int(weights.get("night", 0))
	if pool_id.begins_with("elem_"):
		return int(weights.get("element", 0))
	if pool_id.begins_with("role_"):
		return int(weights.get("role", 0))
	if pool_id.begins_with("tier_"):
		return int(weights.get("tier", 0))
	return int(weights.get("night", 0))


static func reward_pool_for_battle(code: String, current_day: int) -> String:
	if code == "LOSE":
		return "reward_none"
	if code == "WIN_FAST":
		return "reward_fast_clear"
	return tier_reward_pool_for_day(current_day)


static func tier_reward_pool_for_day(current_day: int) -> String:
	return "reward_pT2" if current_day >= 3 else "reward_pT1"


static func reward_multiplier_from_event(event: Dictionary) -> int:
	var regex := RegEx.new()
	regex.compile("奖励\\s*-\\s*(\\d+)%")
	var matched := regex.search(String(event.get("cost", "")) + String(event.get("option_text", "")))
	return max(0, 100 - int(matched.get_string(1))) if matched else 100


static func apply_reward_gold_multiplier(base_delta: int, multiplier: int) -> int:
	return max(0, int(floor(float(max(0, base_delta)) * float(multiplier) / 100.0)))


static func event_text(event: Dictionary) -> String:
	return "%s%s%s" % [
		String(event.get("gain", "")),
		String(event.get("option_text", "")),
		String(event.get("cost", ""))
	]
