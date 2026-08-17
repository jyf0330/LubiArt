extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var _failed := false


func _init() -> void:
	var source: RefCounted = _test_state()
	_expect(source.dispatch({"type": "NEW_RUN", "seed": "codec-complete-state"}), "fixture starts a seeded run")
	_expect(source.dispatch({"type": "START_BATTLE"}), "fixture enters battle")
	var source_bar := Array(Dictionary(source.call("snapshot")).get("skillControlBar", []))
	var source_order: Array = []
	for entry_value in source_bar:
		source_order.push_front(String(Dictionary(entry_value).get("entryId", "")))
	_expect(source.call("set_skill_control_order", source_order), "fixture stores a non-default shared skill order")

	source.set("defeated_units", [{
		"id": "defeated_elite",
		"side": "enemy",
		"hp": 0,
		"max_hp": 9,
		"x": 2,
		"y": 2,
		"mechanics": ["mech_elite_reward_bonus"]
	}])
	source.set("player_elements_settled_this_round", true)
	source.set("auto_position_action_plan", [{"unitId": "fixture", "x": 1, "y": 1}])
	source.set("auto_position_applied_result", {"stateSignature": "fixture"})
	source.set("placement_damage_by_unit", {"fixture": {"damage": 3}})
	source.set("battle_trace", [{"eventId": "bt_000777", "type": "FIXTURE"}])
	source.set("replay_debug_timeline", [{"index": 777, "accepted": true}])
	source.set("relic_inventory", [{"relic_id": "codec_relic", "side": "player"}])
	source.set("relic_combat_state", {"schema": "ysbzs.relic-combat.v1", "current_tick": 777, "queue": [{"due_tick": 999}]})

	var source_data := Dictionary(source.get("game_data")).duplicate(true)
	source_data["history_codec_marker"] = {"version": 7}
	_expect(source.call("replace_game_data_for_test", source_data, &"current_assembly"), "fixture content binds through the test-only authority helper")
	var source_hash := String(Dictionary(source.call("snapshot")).get("stateHash", ""))
	var document := Dictionary(source.call("save_document", "codec-smoke"))

	_expect(int(document.get("schemaVersion", 0)) == 2, "save document uses schema v2")
	var determinism := Dictionary(document.get("determinism", {}))
	_expect(String(determinism.get("contentHash", "")).length() == 64, "save pins a SHA-256 content hash")
	_expect(String(determinism.get("rulesVersion", "")) != "", "save pins a rules version")
	_expect(String(determinism.get("rngVersion", "")) != "", "save pins an RNG algorithm version")
	_expect(Dictionary(determinism.get("contentPack", {})).has("history_codec_marker"), "portable save embeds its immutable content pack")

	var restored: RefCounted = _test_state()
	var drifted_data := Dictionary(restored.get("game_data")).duplicate(true)
	drifted_data["future_added_content"] = true
	_expect(restored.call("replace_game_data_for_test", drifted_data, &"current_assembly"), "future content drift binds through the test-only authority helper")
	_expect(restored.call("load_document", document), "save loads even after current content drifts because it carries the pinned pack")
	_expect(String(Dictionary(restored.call("snapshot")).get("stateHash", "")) == source_hash, "complete authoritative state hash survives save/load")
	_expect(Array(restored.get("defeated_units")).size() == 1, "defeated units survive save/load")
	_expect(bool(restored.get("player_elements_settled_this_round")), "per-round element settlement guard survives save/load")
	_expect(Array(restored.get("auto_position_action_plan")).size() == 1, "auto-position plan survives save/load")
	_expect(not Dictionary(restored.get("auto_position_applied_result")).is_empty(), "auto-position applied result survives save/load")
	_expect(not Dictionary(restored.get("placement_damage_by_unit")).is_empty(), "placement projection state survives save/load")
	_expect(String(Dictionary(Array(restored.get("battle_trace"))[0]).get("eventId", "")) == "bt_000777", "battle trace survives save/load")
	_expect(Array(restored.get("replay_debug_timeline")).size() == 1, "replay debug timeline survives save/load")
	_expect(String(Dictionary(Array(restored.get("relic_inventory"))[0]).get("relic_id", "")) == "codec_relic", "off-board relic inventory survives save/load")
	_expect(int(Dictionary(restored.get("relic_combat_state")).get("current_tick", -1)) == 777, "relic timeline survives save/load")
	_expect(Array(Dictionary(restored.get("skill_control_orders")).get(StateScript.PLAYER, [])) == source_order, "shared skill-control order survives save/load")
	_expect(Dictionary(restored.get("game_data")).has("history_codec_marker"), "load restores the pinned content pack")
	_expect(not Dictionary(restored.get("game_data")).has("future_added_content"), "future content does not leak into an old save")

	var missing_skill_order := document.duplicate(true)
	missing_skill_order["state"].erase("skill_control_orders")
	missing_skill_order["state"].erase("skillControlOrders")
	missing_skill_order["checksum"] = source.call("_save_checksum", missing_skill_order)
	var normalized_old_save: RefCounted = _test_state()
	_expect(normalized_old_save.call("load_document", missing_skill_order), "save without the new optional field loads at the explicit restore boundary")
	_expect(Array(Dictionary(normalized_old_save.get("skill_control_orders")).get(StateScript.PLAYER, [])).size() == source_bar.size(), "missing shared order is normalized from the saved battle roster")

	var tampered := document.duplicate(true)
	tampered["determinism"]["contentPack"]["history_codec_marker"]["version"] = 8
	tampered["checksum"] = source.call("_save_checksum", tampered)
	var rejected: RefCounted = StateScript.new()
	_expect(not rejected.call("load_document", tampered), "content-pack hash mismatch is rejected")

	var future_rules := document.duplicate(true)
	future_rules["determinism"]["rulesVersion"] = "future-rules"
	future_rules["checksum"] = source.call("_save_checksum", future_rules)
	_expect(not StateScript.new().call("load_document", future_rules), "save rejects a rules version the runtime cannot reproduce")

	var future_rng := document.duplicate(true)
	future_rng["determinism"]["rngVersion"] = "future-rng"
	future_rng["checksum"] = source.call("_save_checksum", future_rng)
	_expect(not StateScript.new().call("load_document", future_rng), "save rejects an RNG version the runtime cannot reproduce")

	if _failed:
		print("SMOKE_AUTHORITATIVE_STATE_CODEC_FAIL")
		quit(1)
		return
	print("SMOKE_AUTHORITATIVE_STATE_CODEC_OK schema=2 content_pack=pinned fields=complete")
	quit()


func _test_state() -> RefCounted:
	var production: RefCounted = StateScript.new()
	return StateScript.new({
		"mode": "test",
		"content_pack": Dictionary(production.get("game_data")).duplicate(true),
		"content_source_kind": production.call("content_source_kind"),
	})


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_AUTHORITATIVE_STATE_CODEC_FAIL: %s" % message)
