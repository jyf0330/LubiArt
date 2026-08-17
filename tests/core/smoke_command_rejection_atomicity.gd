extends SceneTree

const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")
const StateScript := preload("res://core/state/game_state.gd")

var failures := 0


func _initialize() -> void:
	_test_requested_unit_preselection_rolls_back()
	_test_select_cell_ap_choice_rolls_back()
	_test_closed_shop_entry_rolls_back()
	_test_invalid_new_run_rolls_back()
	if failures > 0:
		push_error("SMOKE_COMMAND_REJECTION_ATOMICITY_FAILED count=%d" % failures)
		quit(1)
		return
	print("SMOKE_COMMAND_REJECTION_ATOMICITY_OK battle_preselection=true ap_choice=true shop=true new_run=true response_snapshot=true")
	quit(0)


func _test_requested_unit_preselection_rolls_back() -> void:
	var state := StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture enters battle")
	var unit := _first_player_unit(state)
	_expect(not unit.is_empty(), "battle fixture has one player unit")
	if unit.is_empty():
		return
	_expect(String(state.get("selected_unit_id")) == "", "battle starts without a selected unit")
	var before := _rollback_capture(state)
	var response := Dictionary(state.run_command({
		"type": "SET_ACTION_DIRECTION",
		"unitId": String(unit.get("id", "")),
		"slotId": 99,
		"direction": "left",
	}))
	_expect(not bool(response.get("accepted", true)), "missing action slot is rejected")
	_expect(_rollback_capture(state) == before, "rejected direction restores every canonical authority field")
	_expect(String(state.get("selected_unit_id")) == "", "rejected direction does not retain handler preselection")
	unit["rejection_identity_probe"] = true
	_expect(bool(Dictionary(state.unit_by_id(String(unit.get("id", "")))).get("rejection_identity_probe", false)), "rollback preserves unchanged unit dictionary identity")
	unit.erase("rejection_identity_probe")
	_expect(_has_log(state, "权威状态未改变"), "rejected direction explains the rollback")
	_expect(_response_matches_authority(response, state), "rejected direction response and authority agree")


func _test_select_cell_ap_choice_rolls_back() -> void:
	var state := StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "AP fixture enters battle")
	var unit := _first_player_unit(state)
	if unit.is_empty():
		_expect(false, "AP fixture has one player unit")
		return
	var unit_id := String(unit.get("id", ""))
	_expect(state.dispatch({"type": "SELECT_UNIT", "unitId": unit_id}), "AP fixture selects the player unit")
	var before := _rollback_capture(state)
	var response := Dictionary(state.run_command({
		"type": "SELECT_CELL",
		"x": -1,
		"y": -1,
		"ap": 2,
	}))
	_expect(not bool(response.get("accepted", true)), "out-of-board cell is rejected after AP preparation")
	_expect(_rollback_capture(state) == before, "rejected cell restores AP choice and every canonical authority field")
	_expect(_response_matches_authority(response, state), "rejected cell response and authority agree")


func _test_closed_shop_entry_rolls_back() -> void:
	var state := StateScript.new()
	var before := _rollback_capture(state)
	var response := Dictionary(state.run_command({
		"type": "ENTER_SHOP",
		"poolId": "night_base",
		"stallId": "merchant_herma",
		"seedContext": "rejection-atomicity",
	}))
	_expect(not bool(response.get("accepted", true)), "day-one closed stall is rejected")
	_expect(_rollback_capture(state) == before, "closed stall restores shop context, offers, counters, audits and phase")
	_expect(_has_log(state, "没有开放摊位"), "closed stall keeps its specific failure explanation")
	_expect(_response_matches_authority(response, state), "closed-stall response and authority agree")


func _test_invalid_new_run_rolls_back() -> void:
	var state := StateScript.new()
	state.set("coins", 73)
	state.set("difficulty", "easy")
	var before := _rollback_capture(state)
	var response := Dictionary(state.run_command({
		"type": "NEW_RUN",
		"seed": "must-not-commit",
		"difficulty": "normal",
		"boardWidth": 99,
		"boardHeight": 99,
	}))
	_expect(not bool(response.get("accepted", true)), "invalid new-run dimensions are rejected after reset preparation")
	_expect(_rollback_capture(state) == before, "invalid new run restores the complete pre-reset authority")
	_expect(int(state.get("coins")) == 73 and String(state.get("difficulty")) == "easy", "invalid new run preserves visible pre-command values")
	_expect(_has_log(state, "棋盘尺寸不合法"), "invalid new run keeps its validation explanation")
	_expect(_response_matches_authority(response, state), "invalid new-run response and authority agree")


func _response_matches_authority(response: Dictionary, state: RefCounted) -> bool:
	var live_snapshot := Dictionary(state.snapshot())
	var response_snapshot := Dictionary(response.get("snapshot", {}))
	return (
		int(response.get("stateVersion", -1)) == int(live_snapshot.get("stateVersion", -2))
		and String(response.get("stateHash", "")) == String(live_snapshot.get("stateHash", "missing"))
		and int(response_snapshot.get("stateVersion", -1)) == int(live_snapshot.get("stateVersion", -2))
		and String(response_snapshot.get("stateHash", "")) == String(live_snapshot.get("stateHash", "missing"))
	)


func _rollback_capture(state: RefCounted) -> Dictionary:
	var capture := AuthoritativeStateCodecScript.capture(state, false)
	# These two projections intentionally gain rejection diagnostics after the
	# gameplay state has been restored.
	capture.erase("log_lines")
	capture.erase("replay_debug_timeline")
	return capture


func _first_player_unit(state: RefCounted) -> Dictionary:
	for value in Array(state.get("units")):
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == "player" and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _has_log(state: RefCounted, needle: String) -> bool:
	for value in Array(state.get("log_lines")):
		if String(value).contains(needle):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Smoke failed: %s" % message)
