extends SceneTree

const CommandContractScript := preload("res://core/commands/command_contract.gd")
const LocalGameSessionScript := preload("res://session/local_game_session.gd")
const SessionAuthorityHostScript := preload("res://session/session_authority_host.gd")
const SessionProtocolScript := preload("res://session/session_protocol.gd")
const YsbzsStateScript := preload("res://core/state/game_state.gd")

var _failed := false


func _initialize() -> void:
	_test_intent_field_contract()
	_test_local_session_enrichment()
	_test_host_baseline_and_scope()
	_test_core_derived_rules()
	_test_selection_is_authoritative()
	_test_ui_command_sources()
	if _failed:
		quit(1)
		return
	print("SMOKE_COMMAND_INTENT_BOUNDARY_OK")
	quit(0)


func _test_intent_field_contract() -> void:
	var canonical_move := {"type": "MOVE_HERO", "unitId": "pet_001", "x": 3, "y": 4}
	_expect(CommandContractScript.validate_intent(canonical_move).is_empty(), "canonical move intent is accepted")
	_expect(
		CommandContractScript.validate_intent({"type": "REWIND_TO_PREVIOUS_ROUND_START"}).is_empty(),
		"round rewind accepts one parameter-free player intent"
	)
	for forbidden_key in [
		"commandId", "command_id", "baseStateVersion", "base_state_version",
		"baseStateHash", "base_state_hash", "protocolVersion", "actorId", "clientTick",
		"sessionId", "accepted", "stateVersion", "stateHash", "snapshot", "events", "error",
		"label", "kind", "cell", "source_type", "source_index", "free", "slots", "day", "index"
	]:
		var command := canonical_move.duplicate(true)
		command[forbidden_key] = 1
		var error := CommandContractScript.validate_intent(command)
		_expect(String(error.get("code", "")) == "COMMAND_FIELD_NOT_ALLOWED", "UI field %s is rejected" % forbidden_key)
	_expect(
		CommandContractScript.validate_intent({
			"type": "DROP_ITEM_ON_TARGET",
			"offer_id": "offer_001",
			"target_type": "party",
			"target_index": 0,
		}).is_empty(),
		"shop drop intent identifies only the offer and target"
	)
	var ambiguous_drop := CommandContractScript.validate_intent({
		"type": "DROP_ITEM_ON_TARGET",
		"offer_id": "offer_001",
		"unitId": "pet_001",
		"target_type": "party",
	})
	_expect(String(ambiguous_drop.get("code", "")) == "COMMAND_SOURCE_ID_INVALID", "drop source identity is unambiguous")


func _test_local_session_enrichment() -> void:
	var authority = YsbzsStateScript.new()
	var session = LocalGameSessionScript.new(authority)
	var before := session.current_snapshot()
	var response: Dictionary = session.submit_command({"type": "GET_CELL_DETAIL", "x": 0, "y": 0})
	var envelope := Dictionary(response.get("commandEnvelope", {}))
	_expect(bool(response.get("accepted", false)), "local Session accepts canonical intent")
	_expect(String(envelope.get("commandId", "")).begins_with("local:"), "local Session generates commandId")
	_expect(int(envelope.get("baseStateVersion", -1)) == int(before.get("stateVersion", -2)), "local Session injects confirmed stateVersion")
	_expect(String(envelope.get("baseStateHash", "")) == String(before.get("stateHash", "missing")), "local Session injects confirmed stateHash")
	var spoofed: Dictionary = session.submit_command({
		"type": "NEW_RUN",
		"baseStateVersion": int(before.get("stateVersion", 0)),
	})
	_expect(String(Dictionary(spoofed.get("error", {})).get("code", "")) == "COMMAND_FIELD_NOT_ALLOWED", "local UI cannot supply Session metadata")
	var internal: Dictionary = session.submit_command({"type": "START_BATTLE"})
	_expect(String(Dictionary(internal.get("error", {})).get("code", "")) == "COMMAND_SCOPE_FORBIDDEN", "player Session cannot execute internal lifecycle commands")
	var debug_internal: Dictionary = session.submit_command({"type": "GET_DEBUG_PET_CATALOG"})
	_expect(String(Dictionary(debug_internal.get("error", {})).get("code", "")) == "COMMAND_SCOPE_FORBIDDEN", "player Session cannot execute developer catalog commands")


func _test_host_baseline_and_scope() -> void:
	var authority = YsbzsStateScript.new()
	var host = SessionAuthorityHostScript.new(authority)
	_expect(host.register_actor("player", {"role": "player"}), "player actor registers")
	_expect(host.register_actor("dev", {"role": "developer"}), "developer actor registers")

	var missing_hash := SessionProtocolScript.make_command_request(
		{"type": "GET_CELL_DETAIL", "x": 0, "y": 0}, authority.snapshot(), "player", 1, "room", 1
	)
	missing_hash.erase("baseStateHash")
	var missing_response: Dictionary = host.handle_command(missing_hash)
	_expect(String(Dictionary(missing_response.get("error", {})).get("code", "")) == "BASE_STATE_HASH_REQUIRED", "Host requires Session-generated hash")

	var before := authority.snapshot()
	var wrong_hash := SessionProtocolScript.make_command_request(
		{"type": "NEW_RUN", "seed": "wrong-hash"}, before, "player", 2, "room", 2
	)
	wrong_hash["baseStateHash"] = "not-the-authoritative-hash"
	var wrong_hash_response: Dictionary = host.handle_command(wrong_hash)
	_expect(String(Dictionary(wrong_hash_response.get("error", {})).get("code", "")) == "STATE_HASH_MISMATCH", "core rejects same-version different-hash baseline")
	_expect(_same_snapshot_identity(before, authority.snapshot()), "hash mismatch performs zero authoritative writes")

	var player_internal := SessionProtocolScript.make_command_request(
		{"type": "START_BATTLE"}, authority.snapshot(), "player", 3, "room", 3
	)
	var player_internal_response: Dictionary = host.handle_command(player_internal)
	_expect(String(Dictionary(player_internal_response.get("error", {})).get("code", "")) == "COMMAND_SCOPE_FORBIDDEN", "Host denies internal command to player actor")

	var dev_internal := SessionProtocolScript.make_command_request(
		{"type": "START_BATTLE"}, authority.snapshot(), "dev", 1, "room", 1
	)
	var dev_internal_response: Dictionary = host.handle_command(dev_internal)
	_expect(bool(dev_internal_response.get("accepted", false)), "trusted developer actor can execute internal lifecycle command")

	var injected_free := SessionProtocolScript.make_command_request(
		{"type": "ROLL_SHOP"}, authority.snapshot(), "player", 4, "room", 4
	)
	injected_free["free"] = true
	var injected_free_response: Dictionary = host.handle_command(injected_free)
	_expect(String(Dictionary(injected_free_response.get("error", {})).get("code", "")) == "COMMAND_FIELD_NOT_ALLOWED", "Host rejects wire-injected rule outcome fields")


func _test_core_derived_rules() -> void:
	var authority = YsbzsStateScript.new()
	authority.set("phase", "shop")
	authority.set("coins", 100)
	authority.set("shop_free_rolls", 0)
	authority.set("active_shop_pool", "night_base")
	authority.set("active_stall", {"slots": 1})
	var before_coins := int(authority.get("coins"))
	_expect(authority.dispatch({"type": "ROLL_SHOP", "free": true}), "legacy direct caller can still dispatch roll command")
	_expect(int(authority.get("coins")) < before_coins, "core ignores injected free and derives paid refresh cost")

	var derived_drop := CommandContractScript.validate_intent({
		"type": "DROP_ITEM_ON_TARGET",
		"unitId": "pet_001",
		"target_type": "bag",
		"target_index": 0,
	})
	_expect(derived_drop.is_empty(), "roster drop source is derived rather than submitted")


func _test_selection_is_authoritative() -> void:
	var authority = YsbzsStateScript.new()
	var developer_session = LocalGameSessionScript.new(authority, "developer")
	var battle_start: Dictionary = developer_session.submit_command({"type": "START_BATTLE"})
	_expect(bool(battle_start.get("accepted", false)), "developer fixture starts battle through Session")
	var battle_snapshot := authority.snapshot()
	var player_id := ""
	for value in Array(battle_snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == "player":
			player_id = String(unit.get("id", ""))
			break
	_expect(player_id != "", "battle fixture exposes a selectable player unit")
	if player_id == "":
		return
	var player_session = LocalGameSessionScript.new(authority)
	var before := authority.snapshot()
	var before_log_size := Array(authority.get("command_log")).size()
	var selected: Dictionary = player_session.submit_command({"type": "SELECT_UNIT", "unitId": player_id})
	var after := authority.snapshot()
	_expect(bool(selected.get("accepted", false)), "selection intent is accepted")
	_expect(int(after.get("stateVersion", -1)) == int(before.get("stateVersion", -1)) + 1, "selection advances authoritative version")
	_expect(String(after.get("stateHash", "")) != String(before.get("stateHash", "")), "selection changes authoritative hash")
	_expect(Array(authority.get("command_log")).size() == before_log_size + 1, "selection enters replay command log")


func _test_ui_command_sources() -> void:
	var route_source := FileAccess.get_file_as_string("res://core_ui/scripts/route/controllers/route_controller.gd")
	var shop_source := FileAccess.get_file_as_string("res://core_ui/scripts/shop/controllers/bazaar_info_panel.gd")
	var settlement_source := FileAccess.get_file_as_string("res://core_ui/scripts/settlement/controllers/settlement_controller.gd")
	var drag_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd")
	var board_source := FileAccess.get_file_as_string("res://core_ui/scripts/battle/controllers/battle_board_drag_interaction.gd")
	_expect(not route_source.contains('"kind": kind'), "route command excludes presentation kind")
	_expect(not shop_source.contains('"type": "ROLL_SHOP",\n\t\t\t\t"slots"'), "shop roll excludes snapshot-derived slot count")
	_expect(not settlement_source.contains('"command": {"type": "START_NEXT_DAY", "day"'), "next-day command excludes derived day")
	_expect(not drag_source.contains('"source_type":') and not drag_source.contains('"source_index":'), "drag commands exclude UI-owned source claims")
	_expect(not board_source.contains('"cell": {'), "board commands use one canonical coordinate representation")


func _same_snapshot_identity(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("stateVersion", -1)) == int(right.get("stateVersion", -2)) \
		and String(left.get("stateHash", "")) == String(right.get("stateHash", "missing"))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_COMMAND_INTENT_BOUNDARY_FAIL: %s" % message)
