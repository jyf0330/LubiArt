extends SceneTree

const Codec := preload("res://persistence/authoritative_state_codec.gd")
const State := preload("res://core/state/game_state.gd")

var failures := 0


func _initialize() -> void:
	var state = State.new()
	var shop_option := _route_option(state, "shop")
	var complex_option := _non_shop_route_option(state)
	var shop_action := {"type": "CHOOSE_ROUTE", "optionId": String(shop_option.get("id", ""))}
	var shop_plan := Dictionary(state.call("_command_checkpoint_plan", "CHOOSE_ROUTE", shop_action))
	_expect(String(shop_plan.get("mode", "")) == "narrow", "shop route uses a narrow rollback checkpoint")
	_expect(not Array(shop_plan.get("properties", [])).has("run_plan"), "shop route does not copy immutable run plan")
	_expect(not Array(shop_plan.get("properties", [])).has("route_options"), "shop route does not copy post-commit route projection")
	var battle_plan := Dictionary(state.call("_command_checkpoint_plan", "CHOOSE_ROUTE", {
		"type": "CHOOSE_ROUTE", "optionId": String(complex_option.get("id", "")),
	}))
	_expect(String(battle_plan.get("mode", "")) == "full", "complex battle route keeps full rollback fallback")

	var partial := Dictionary(Codec.capture_properties(state, ["coins", "log_lines"]))
	_expect(partial.keys().size() == 2 and partial.has("coins") and partial.has("log_lines"), "partial codec captures only requested canonical fields")
	var route_options_before := Array(state.get("route_options")).duplicate(true)
	state.set("coins", 999)
	Codec.restore_changed(state, partial)
	_expect(int(state.get("coins")) == int(partial.get("coins", -1)), "partial checkpoint restores requested field")
	_expect(Array(state.get("route_options")) == route_options_before, "partial checkpoint leaves unrelated field untouched")

	_expect(state.dispatch(shop_action), "fixture enters route shop")
	var pet_offer := _offer(state, true)
	var non_pet_offer := _offer(state, false)
	if not pet_offer.is_empty():
		var pet_plan := Dictionary(state.call("_command_checkpoint_plan", "BUY_OFFER", {
			"type": "BUY_OFFER", "offerId": String(pet_offer.get("id", "")),
		}))
		_expect(String(pet_plan.get("mode", "")) == "narrow", "pet purchase uses narrow rollback checkpoint")
	if not non_pet_offer.is_empty():
		var item_plan := Dictionary(state.call("_command_checkpoint_plan", "BUY_OFFER", {
			"type": "BUY_OFFER", "offerId": String(non_pet_offer.get("id", "")),
		}))
		_expect(String(item_plan.get("mode", "")) == "full", "effect item purchase keeps full rollback fallback")

	var roll_plan := Dictionary(state.call("_command_checkpoint_plan", "ROLL_SHOP", {"type": "ROLL_SHOP"}))
	var exit_plan := Dictionary(state.call("_command_checkpoint_plan", "EXIT_SHOP", {"type": "EXIT_SHOP"}))
	_expect(String(roll_plan.get("mode", "")) == "narrow", "shop refresh uses narrow rollback checkpoint")
	_expect(String(exit_plan.get("mode", "")) == "narrow", "shop exit uses narrow rollback checkpoint")
	var unrelated_plan := Dictionary(state.call("_command_checkpoint_plan", "START_BATTLE", {"type": "START_BATTLE"}))
	_expect(String(unrelated_plan.get("mode", "")) == "full", "unprofiled command keeps full rollback fallback")

	if failures > 0:
		push_error("SMOKE_COMMAND_CHECKPOINT_PROFILES_FAILED count=%d" % failures)
		quit(1)
		return
	print("SMOKE_COMMAND_CHECKPOINT_PROFILES_OK shop_route_fields=%d roll_fields=%d exit_fields=%d" % [
		Array(shop_plan.get("properties", [])).size(),
		Array(roll_plan.get("properties", [])).size(),
		Array(exit_plan.get("properties", [])).size(),
	])
	quit()


func _route_option(state: RefCounted, kind: String) -> Dictionary:
	for value in Array(state.get("route_options")):
		var option := Dictionary(value)
		if String(option.get("kind", "")) == kind:
			return option
	return {}


func _non_shop_route_option(state: RefCounted) -> Dictionary:
	for value in Array(state.get("route_options")):
		var option := Dictionary(value)
		if String(option.get("kind", "")) != "shop":
			return option
	return {}


func _offer(state: RefCounted, wants_pet: bool) -> Dictionary:
	for value in Array(state.get("shop_offers")):
		var offer := Dictionary(value)
		var is_pet := String(offer.get("item_type", "宠物" if String(offer.get("pet_id", "")) != "" else "")) == "宠物"
		if is_pet == wants_pet:
			return offer
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Smoke failed: %s" % message)
