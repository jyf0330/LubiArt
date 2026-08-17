extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const SessionFactoryScript := preload("res://session/session_factory.gd")
const MAX_INCREMENTAL_MS := 100

var _failed := false


func _initialize() -> void:
	var state = StateScript.new()
	var session = SessionFactoryScript.wrap_local_authority(state)
	_expect(not bool(Dictionary(state.run_history_status()).get("enabled", true)), "normal local play does not persist a full checkpoint on every click")
	var initial := Dictionary(session.current_snapshot())
	_expect(not initial.is_empty() and String(initial.get("stateHash", "")) != "", "connect calibration returns a complete hashed Snapshot")

	var shop_option_id := _route_option_id(state, "shop")
	_expect(shop_option_id != "", "fixture exposes a shop route")
	var route_started := Time.get_ticks_msec()
	var route_response := Dictionary(session.submit_command({"type": "CHOOSE_ROUTE", "option_id": shop_option_id}))
	var route_ms := Time.get_ticks_msec() - route_started
	_assert_delta_response(route_response, "shop route")
	_expect(route_ms <= MAX_INCREMENTAL_MS, "shop route delta stays within %dms (actual %dms)" % [MAX_INCREMENTAL_MS, route_ms])
	var presented := Dictionary(session.current_presentation_snapshot())
	_expect(String(presented.get("phase", "")) == "shop", "presentation read model enters shop")
	_expect(int(presented.get("stateVersion", -1)) == int(state.get("state_version")), "presentation read model tracks authority version")
	var pet_offer_id := _pet_offer_id(state, int(state.get("coins")))
	_expect(pet_offer_id != "", "shop fixture exposes a pet offer")
	var buy_started := Time.get_ticks_msec()
	var buy_response := Dictionary(session.submit_command({"type": "BUY_OFFER", "offer_id": pet_offer_id}))
	var buy_ms := Time.get_ticks_msec() - buy_started
	_assert_delta_response(buy_response, "pet purchase")
	_expect(buy_ms <= MAX_INCREMENTAL_MS, "pet purchase delta stays within %dms (actual %dms)" % [MAX_INCREMENTAL_MS, buy_ms])

	var reject_offer_id := _pet_offer_id(state)
	_expect(reject_offer_id != "", "shop retains another pet offer for rejection coverage")
	var coins_after_buy := int(state.get("coins"))
	state.set("coins", 0)
	session.current_snapshot()
	var rejected_version := int(state.get("state_version"))
	var reject_started := Time.get_ticks_msec()
	var rejected_buy := Dictionary(session.submit_command({"type": "BUY_OFFER", "offer_id": reject_offer_id}))
	var reject_ms := Time.get_ticks_msec() - reject_started
	_expect(not bool(rejected_buy.get("accepted", true)), "unaffordable pet purchase is rejected")
	_expect(String(rejected_buy.get("snapshotMode", "")) == "delta", "purchase rejection remains a small response")
	_expect(not rejected_buy.has("snapshot") and String(rejected_buy.get("stateHash", "")) == "", "purchase rejection skips Snapshot and full hash")
	_expect(int(state.get("state_version")) == rejected_version, "purchase rejection preserves revision")
	_expect(reject_ms <= MAX_INCREMENTAL_MS, "purchase rejection stays within %dms (actual %dms)" % [MAX_INCREMENTAL_MS, reject_ms])
	# Restore the test-only affordability fixture before continuing; the rejected
	# command itself has already proven that authority/version stayed unchanged.
	state.set("coins", coins_after_buy)
	session.current_snapshot()

	var roll_started := Time.get_ticks_msec()
	var roll_response := Dictionary(session.submit_command({"type": "ROLL_SHOP"}))
	var roll_ms := Time.get_ticks_msec() - roll_started
	_assert_delta_response(roll_response, "shop roll")
	_expect(roll_ms <= MAX_INCREMENTAL_MS, "shop roll delta stays within %dms (actual %dms)" % [MAX_INCREMENTAL_MS, roll_ms])

	var before_stale_version := int(state.get("state_version"))
	var stale := Dictionary(state.run_incremental_command({
		"type": "ROLL_SHOP",
		"commandId": "stale-version",
		"baseStateVersion": before_stale_version - 1,
	}))
	_expect(not bool(stale.get("accepted", true)), "stale incremental command is rejected")
	_expect(String(Dictionary(stale.get("error", {})).get("code", "")) == "STATE_VERSION_MISMATCH", "stale incremental rejection reports version mismatch")
	_expect(int(state.get("state_version")) == before_stale_version, "stale incremental rejection preserves version")

	var exit_started := Time.get_ticks_msec()
	var exit_response := Dictionary(session.submit_command({"type": "EXIT_SHOP"}))
	var exit_ms := Time.get_ticks_msec() - exit_started
	_assert_delta_response(exit_response, "shop exit")
	_expect(exit_ms <= MAX_INCREMENTAL_MS, "shop exit delta stays within %dms (actual %dms)" % [MAX_INCREMENTAL_MS, exit_ms])
	_expect(String(session.current_presentation_snapshot().get("phase", "")) == "route", "presentation read model returns to route")

	var complete := Dictionary(session.current_snapshot())
	_expect(String(complete.get("stateHash", "")) != "", "explicit calibration restores a complete state hash")
	_expect(int(complete.get("stateVersion", -1)) == int(state.get("state_version")), "complete calibration keeps the current revision")
	var replay := Dictionary(state.replay_document())
	_expect(String(Dictionary(replay.get("final", {})).get("stateHash", "")) != "", "replay export carries a complete final hash")
	var replay_verification := Dictionary(state.verify_replay_document(replay))
	_expect(bool(replay_verification.get("ok", false)), "replay with version-only intermediate checkpoints verifies deterministically")
	var document := Dictionary(state.save_document())
	var restored = StateScript.new()
	_expect(restored.load_document(document), "state after delta commands restores from save")
	_expect(String(restored.call("_state_hash")) == String(state.call("_state_hash")), "save/load preserves the final authoritative hash")
	state.enable_run_history(true)
	_expect(not state.can_run_incremental_command({"type": "ENTER_SHOP"}), "explicit per-command history mode keeps the complete hashed command path")

	if _failed:
		quit(1)
		return
	print("SMOKE_INCREMENTAL_COMMAND_RESPONSE_OK route_ms=%d buy_ms=%d reject_ms=%d roll_ms=%d exit_ms=%d" % [route_ms, buy_ms, reject_ms, roll_ms, exit_ms])
	quit()


func _assert_delta_response(response: Dictionary, label: String) -> void:
	_expect(bool(response.get("accepted", false)), "%s is accepted" % label)
	_expect(String(response.get("snapshotMode", "")) == "delta", "%s uses delta mode" % label)
	_expect(not Dictionary(response.get("delta", {})).is_empty(), "%s includes domain changes" % label)
	_expect(not response.has("snapshot"), "%s does not construct a full Snapshot" % label)
	_expect(String(response.get("stateHash", "")) == "", "%s does not compute a full state hash" % label)


func _route_option_id(state, kind: String) -> String:
	for value in Array(state.get("route_options")):
		var option := Dictionary(value)
		if String(option.get("kind", "")) == kind:
			return String(option.get("id", option.get("optionId", "")))
	return ""


func _pet_offer_id(state, max_price: int = 2_147_483_647) -> String:
	for value in Array(state.get("shop_offers")):
		var offer := Dictionary(value)
		if String(offer.get("pet_id", "")) != "" and int(offer.get("price", 0)) <= max_price:
			return String(offer.get("id", offer.get("offer_id", "")))
	return ""


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_INCREMENTAL_COMMAND_RESPONSE_FAIL: %s" % message)
