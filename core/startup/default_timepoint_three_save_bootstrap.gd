extends RefCounted

## Builds the fixed test-play startup save entirely through the public
## GameSession contract, then reloads it through the existing persistence port.
## It owns no gameplay state and never mutates YsbzsState fields directly.

const TARGET_DAY := 1
const TARGET_TIMEPOINT := 3
const TARGET_BATTLE_ROUND := 1
const PURCHASE_COUNT := 4
const DEFAULT_SAVE_SLOT := 3


static func prepare_and_load(
	session: RefCounted,
	run_seed: String,
	slot: int = DEFAULT_SAVE_SLOT
) -> Dictionary:
	var session_error := _session_contract_error(session)
	if not session_error.is_empty():
		return session_error
	var generated := _generate_save(session, run_seed, slot)
	if not bool(generated.get("ok", false)):
		return generated
	if not bool(session.call("load_from_slot", slot)):
		return _failure("STARTUP_SAVE_LOAD_FAILED", {"slot": slot})
	var snapshot := Dictionary(session.call("current_snapshot"))
	var validation := validate_snapshot(snapshot, run_seed)
	if not bool(validation.get("ok", false)):
		validation["slot"] = slot
		return validation
	return {
		"ok": true,
		"slot": slot,
		"run_seed": run_seed,
		"purchased_offer_ids": Array(generated.get("purchased_offer_ids", [])).duplicate(),
		"snapshot": snapshot.duplicate(true),
		"state_hash": String(snapshot.get("stateHash", "")),
	}


static func validate_snapshot(snapshot: Dictionary, run_seed: String) -> Dictionary:
	var facts := {
		"phase": String(snapshot.get("phase", "")),
		"day": int(snapshot.get("day", 0)),
		"timepoint": int(snapshot.get("node_index", 0)),
		"battle_round": int(snapshot.get("battle_round", snapshot.get("round", 0))),
		"run_seed": String(snapshot.get("run_seed", "")),
		"purchase_count": _command_count(snapshot, "BUY_OFFER"),
		"roster_count": Array(snapshot.get("roster", [])).size(),
		"active_player_pet_count": _active_player_pet_count(snapshot),
	}
	if String(facts.get("run_seed", "")) != run_seed:
		return _failure("STARTUP_SAVE_SEED_MISMATCH", facts)
	if String(facts.get("phase", "")) != "battle" \
			or int(facts.get("day", 0)) != TARGET_DAY \
			or int(facts.get("timepoint", 0)) != TARGET_TIMEPOINT \
			or int(facts.get("battle_round", 0)) != TARGET_BATTLE_ROUND:
		return _failure("STARTUP_SAVE_TIMEPOINT_MISMATCH", facts)
	if int(facts.get("purchase_count", 0)) != PURCHASE_COUNT:
		return _failure("STARTUP_SAVE_PURCHASE_COUNT_MISMATCH", facts)
	if int(facts.get("active_player_pet_count", 0)) != 4:
		return _failure("STARTUP_SAVE_ACTIVE_PARTY_MISMATCH", facts)
	return {"ok": true, "facts": facts}


static func _generate_save(session: RefCounted, run_seed: String, slot: int) -> Dictionary:
	var reset_error := _submit(session, {"type": "NEW_RUN", "seed": run_seed})
	if not reset_error.is_empty():
		return reset_error

	var first_shop := _route_option(
		Dictionary(session.call("current_snapshot")),
		"shop",
		"node_shop_basic"
	)
	if first_shop.is_empty():
		return _failure("STARTUP_SAVE_FIRST_SHOP_MISSING")
	var first_shop_error := _submit(session, {
		"type": "CHOOSE_ROUTE",
		"option_id": _option_id(first_shop),
	})
	if not first_shop_error.is_empty():
		return first_shop_error

	var purchased_offer_ids: Array[String] = []
	var first_purchase_result := _buy_available_pets(
		session,
		purchased_offer_ids,
		PURCHASE_COUNT
	)
	if not bool(first_purchase_result.get("ok", false)):
		return first_purchase_result

	var exit_first_shop_error := _submit(session, {"type": "EXIT_SHOP"})
	if not exit_first_shop_error.is_empty():
		return exit_first_shop_error

	var second_shop := _route_option(
		Dictionary(session.call("current_snapshot")),
		"shop",
		"node_shop_fire"
	)
	if second_shop.is_empty():
		return _failure("STARTUP_SAVE_SECOND_TIMEPOINT_MISSING")
	var second_shop_error := _submit(session, {
		"type": "CHOOSE_ROUTE",
		"option_id": _option_id(second_shop),
	})
	if not second_shop_error.is_empty():
		return second_shop_error
	var second_purchase_result := _buy_available_pets(
		session,
		purchased_offer_ids,
		PURCHASE_COUNT
	)
	if not bool(second_purchase_result.get("ok", false)):
		return second_purchase_result
	if purchased_offer_ids.size() != PURCHASE_COUNT:
		var purchase_snapshot := Dictionary(session.call("current_snapshot"))
		return _failure("STARTUP_SAVE_BUYABLE_PET_MISSING", {
			"purchase_count": purchased_offer_ids.size(),
			"coins": int(purchase_snapshot.get("coins", 0)),
		})
	var exit_second_shop_error := _submit(session, {"type": "EXIT_SHOP"})
	if not exit_second_shop_error.is_empty():
		return exit_second_shop_error

	var battle_option := _route_option(
		Dictionary(session.call("current_snapshot")),
		"battle"
	)
	if battle_option.is_empty():
		return _failure("STARTUP_SAVE_THIRD_TIMEPOINT_BATTLE_MISSING")
	var battle_error := _submit(session, {
		"type": "CHOOSE_ROUTE",
		"option_id": _option_id(battle_option),
	})
	if not battle_error.is_empty():
		return battle_error

	var snapshot := Dictionary(session.call("current_snapshot"))
	var validation := validate_snapshot(snapshot, run_seed)
	if not bool(validation.get("ok", false)):
		return validation
	if not bool(session.call("save_to_slot", slot)):
		return _failure("STARTUP_SAVE_WRITE_FAILED", {"slot": slot})
	return {
		"ok": true,
		"slot": slot,
		"purchased_offer_ids": purchased_offer_ids,
		"snapshot": snapshot.duplicate(true),
	}


static func _session_contract_error(session: RefCounted) -> Dictionary:
	if session == null:
		return _failure("STARTUP_SAVE_SESSION_MISSING")
	for method_name in ["submit_command", "current_snapshot", "supports_persistence", "save_to_slot", "load_from_slot"]:
		if not session.has_method(method_name):
			return _failure("STARTUP_SAVE_SESSION_METHOD_MISSING", {"method": method_name})
	if not bool(session.call("supports_persistence")):
		return _failure("STARTUP_SAVE_PERSISTENCE_UNAVAILABLE")
	return {}


static func _submit(session: RefCounted, command: Dictionary) -> Dictionary:
	var response_value: Variant = session.call("submit_command", command.duplicate(true))
	if typeof(response_value) != TYPE_DICTIONARY:
		return _failure("STARTUP_SAVE_COMMAND_RESPONSE_INVALID", {"command": command})
	var response := Dictionary(response_value)
	if bool(response.get("accepted", false)):
		return {}
	return _failure("STARTUP_SAVE_COMMAND_REJECTED", {
		"command": command.duplicate(true),
		"response": {
			"command": String(response.get("command", "")),
			"error": Dictionary(response.get("error", {})).duplicate(true),
			"status": String(response.get("status", "")),
		},
	})


static func _route_option(
	snapshot: Dictionary,
	kind: String,
	preferred_id: String = ""
) -> Dictionary:
	var fallback := {}
	for option_value in Array(snapshot.get("route_options", [])):
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option := Dictionary(option_value)
		if String(option.get("kind", "")) != kind:
			continue
		if fallback.is_empty():
			fallback = option
		if preferred_id != "" and _matches_option_id(option, preferred_id):
			return option
	return fallback


static func _option_id(option: Dictionary) -> String:
	return String(option.get("option_id", option.get("optionId", option.get("id", option.get("nodeId", "")))))


static func _matches_option_id(option: Dictionary, expected: String) -> bool:
	for key in ["option_id", "optionId", "id", "nodeId"]:
		if String(option.get(key, "")) == expected:
			return true
	return false


static func _first_buyable_pet_offer(snapshot: Dictionary) -> Dictionary:
	var coins := int(snapshot.get("coins", 0))
	for offer_value in Array(snapshot.get("shop_offers", [])):
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer := Dictionary(offer_value)
		if bool(offer.get("sold", false)):
			continue
		if String(offer.get("pet_id", "")) == "":
			continue
		if int(offer.get("price", 0)) > coins:
			continue
		if String(offer.get("offer_id", offer.get("id", ""))) == "":
			continue
		return offer
	return {}


static func _buy_available_pets(
	session: RefCounted,
	purchased_offer_ids: Array[String],
	target_count: int
) -> Dictionary:
	while purchased_offer_ids.size() < target_count:
		var snapshot := Dictionary(session.call("current_snapshot"))
		var offer := _first_buyable_pet_offer(snapshot)
		if offer.is_empty():
			break
		var offer_id := String(offer.get("offer_id", offer.get("id", "")))
		var purchase_error := _submit(session, {
			"type": "BUY_OFFER",
			"offer_id": offer_id,
		})
		if not purchase_error.is_empty():
			return purchase_error
		purchased_offer_ids.append(offer_id)
	return {"ok": true}


static func _command_count(snapshot: Dictionary, command_type: String) -> int:
	var count := 0
	for command_value in Array(snapshot.get("command_log", [])):
		if typeof(command_value) == TYPE_DICTIONARY \
				and String(Dictionary(command_value).get("type", "")) == command_type:
			count += 1
	return count


static func _active_player_pet_count(snapshot: Dictionary) -> int:
	var count := 0
	for unit_value in Array(snapshot.get("units", [])):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == "player" and int(unit.get("hp", 0)) > 0:
			count += 1
	return count


static func _failure(code: String, details: Dictionary = {}) -> Dictionary:
	var result := details.duplicate(true)
	result["ok"] = false
	result["code"] = code
	return result
