extends "res://tests/helpers/singleplayer_smoke_suite.gd"


func _run() -> void:
	var auto_position_state := _new_legacy_state()
	_expect(auto_position_state.dispatch({"type": "START_BATTLE"}), "auto-position fixture can start battle")
	var auto_actor := auto_position_state.unit_by_id("pal_002")
	var auto_target_id := _place_first_enemy(auto_position_state, 4, 5, 20)
	var auto_target := auto_position_state.unit_by_id(auto_target_id)
	_expect(not auto_actor.is_empty() and not auto_target.is_empty(), "auto-position fixture has actor and target")
	for unit in auto_position_state.units:
		if String(unit.get("side", "")) == StateScript.PLAYER and String(unit.get("id", "")) != "pal_002":
			unit["hp"] = 0
		if String(unit.get("side", "")) == StateScript.ENEMY and String(unit.get("id", "")) != auto_target_id:
			unit["hp"] = 0
	auto_actor["x"] = 1
	auto_actor["y"] = 5
	auto_actor["shape_id"] = "01"
	auto_actor["shape_name"] = "形状01"
	auto_actor["move_range"] = 4
	auto_actor["moveRange"] = 4
	auto_actor["atk"] = 5
	auto_actor["has_attacked"] = false
	auto_actor["action_slots_used"] = {}
	auto_target["x"] = 4
	auto_target["y"] = 5
	auto_target["hp"] = 20
	auto_target["shield"] = 0
	auto_target["def"] = 0
	auto_position_state.action_dirs["pal_002:slot0"] = "right"
	var auto_ap_before := int(auto_position_state.snapshot().get("ap", 0))
	_expect(auto_position_state.dispatch({"type": "AUTO_POSITION_HEROES"}), "auto-position public command is accepted")
	_expect(not bool(auto_actor.get("has_attacked", true)), "auto-position does not mark the pet as acted")
	_expect(Dictionary(auto_actor.get("action_slots_used", {})).is_empty(), "auto-position does not consume action slots")
	_expect(int(auto_position_state.snapshot().get("ap", 0)) == auto_ap_before, "auto-position does not spend battle AP")
	_expect(String(auto_position_state.action_dirs.get("pal_002:slot0", "")) == "right", "auto-position keeps the best attack direction")
	_expect(_log_contains(auto_position_state.snapshot()["log_lines"], "智能调整站位："), "auto-position decision is visible in battle log")
	var approach_position_state := _new_legacy_state()
	_expect(approach_position_state.dispatch({"type": "START_BATTLE"}), "approach-position fixture can start battle")
	var approach_actor := approach_position_state.unit_by_id("pal_002")
	var approach_target_id := _place_first_enemy(approach_position_state, 6, 0, 50)
	var approach_target := approach_position_state.unit_by_id(approach_target_id)
	_expect(not approach_actor.is_empty() and not approach_target.is_empty(), "approach-position fixture has actor and distant target")
	for unit in approach_position_state.units:
		if String(unit.get("side", "")) == StateScript.PLAYER and String(unit.get("id", "")) != "pal_002":
			unit["hp"] = 0
		if String(unit.get("side", "")) == StateScript.ENEMY and String(unit.get("id", "")) != approach_target_id:
			unit["hp"] = 0
	approach_actor["x"] = 1
	approach_actor["y"] = 5
	approach_actor["shape_id"] = "01"
	approach_actor["shape_name"] = "形状01"
	approach_actor["move_range"] = 5
	approach_actor["moveRange"] = 5
	approach_actor["has_attacked"] = false
	approach_actor["action_slots_used"] = {}
	approach_target["x"] = 6
	approach_target["y"] = 0
	var approach_distance_before: int = abs(int(approach_actor.get("x", -1)) - int(approach_target.get("x", -1))) + abs(int(approach_actor.get("y", -1)) - int(approach_target.get("y", -1)))
	_expect(approach_position_state.dispatch({"type": "AUTO_POSITION_HEROES"}), "approach-position public command is accepted")
	approach_actor = approach_position_state.unit_by_id("pal_002")
	var approach_distance_after: int = abs(int(approach_actor.get("x", -1)) - int(approach_target.get("x", -1))) + abs(int(approach_actor.get("y", -1)) - int(approach_target.get("y", -1)))
	_expect(approach_distance_after < approach_distance_before, "auto-position advances toward a distant enemy when no immediate attack is available")
	_expect(String(Dictionary(approach_position_state.last_command_result.get("plan", {})).get("resultSignature", "")) != "", "approach-position reports a deterministic planner result signature")
	var spread_kill_state := _new_legacy_state()
	_expect(spread_kill_state.dispatch({"type": "START_BATTLE"}), "spread-kill auto-position fixture can start battle")
	var spread_enemy_ids := _prepare_enemy_targets(spread_kill_state, [{"x": 4, "y": 3}, {"x": 4, "y": 5}], 20)
	var spread_actor_a := spread_kill_state.unit_by_id("pal_002")
	var spread_actor_b_id := _append_player_clone(spread_kill_state, "pal_002", "pal_spread_kill_ally", 0, 4, 30)
	var spread_actor_b := spread_kill_state.unit_by_id(spread_actor_b_id)
	for unit in spread_kill_state.units:
		if String(unit.get("side", "")) == StateScript.PLAYER and not ["pal_002", spread_actor_b_id].has(String(unit.get("id", ""))):
			unit["hp"] = 0
	for actor in [spread_actor_a, spread_actor_b]:
		actor["shape_id"] = "01"
		actor["shape_name"] = "形状01"
		actor["hit_cells"] = 1
		actor["move_range"] = 5
		actor["moveRange"] = 5
		actor["atk"] = 10
		actor["has_attacked"] = false
		actor["action_slots_used"] = {}
	spread_actor_a["x"] = 1
	spread_actor_a["y"] = 4
	_expect(spread_enemy_ids.size() == 2 and not spread_actor_a.is_empty() and not spread_actor_b.is_empty(), "spread-kill fixture has two attackers and two killable enemies")
	_expect(spread_kill_state.dispatch({"type": "AUTO_POSITION_HEROES"}), "spread-kill auto-position public command is accepted")
	var spread_plan := Dictionary(spread_kill_state.last_command_result.get("plan", {}))
	var spread_target_ids: Array = []
	for direction_value in Array(spread_plan.get("directions", [])):
		for target_id in Array(Dictionary(direction_value).get("targets", [])):
			if not spread_target_ids.has(String(target_id)):
				spread_target_ids.append(String(target_id))
	_expect(Array(spread_plan.get("moves", [])).size() == 2, "auto-position gives both attackers distinct legal kill positions")
	_expect(spread_target_ids.size() == 2, "auto-position spreads attackers across separate killable enemies")
	_expect(int(spread_plan.get("kills", 0)) == 2, "auto-position reports two distinct projected kills instead of duplicate overkill")
	var auto_battle_position_state := _new_legacy_state()
	_expect(auto_battle_position_state.dispatch({"type": "START_BATTLE"}), "auto-battle positioning fixture can start battle")
	_expect(auto_battle_position_state.dispatch({"type": "RUN_BATTLE"}), "auto-battle public command is accepted")
	var auto_battle_result := Dictionary(auto_battle_position_state.snapshot().get("last_command_result", {}))
	_expect(bool(auto_battle_result.get("autoPositioned", false)), "auto-battle reports smart positioning before player all-out actions")
	var move_parity_state := _new_legacy_state()
	_expect(move_parity_state.dispatch({"type": "START_BATTLE"}), "move parity fixture can start battle")
	var move_parity_actor := move_parity_state.unit_by_id("pal_002")
	var move_parity_target_id := _place_first_enemy(move_parity_state, 5, 5, 50)
	for unit in move_parity_state.units:
		if String(unit.get("side", "")) == StateScript.PLAYER and String(unit.get("id", "")) != "pal_002":
			unit["hp"] = 0
		if String(unit.get("side", "")) == StateScript.ENEMY and String(unit.get("id", "")) != move_parity_target_id:
			unit["hp"] = 0
	move_parity_actor["x"] = 1
	move_parity_actor["y"] = 5
	move_parity_actor["shape_id"] = "01"
	move_parity_actor["shape_name"] = "形状01"
	move_parity_actor["move_range"] = 3
	move_parity_actor["moveRange"] = 3
	move_parity_actor["has_attacked"] = false
	var move_parity_ap_before := int(move_parity_state.snapshot().get("ap", 0))
	var move_parity_version_before := int(move_parity_state.snapshot().get("stateVersion", 0))
	var move_parity_response := move_parity_state.run_command({
		"type": "MOVE_HERO",
		"unitId": "pal_002",
		"to": {"r": 5, "c": 4},
		"baseStateVersion": move_parity_version_before,
		"commandId": "smoke_move_parity"
	})
	_expect(bool(move_parity_response.get("ok", false)), "MOVE_HERO accepts a target within unit moveRange")
	_expect(move_parity_response.get("result", false) == true, "MOVE_HERO response result stays true while manualFlowPreview is top-level")
	var move_events := Array(move_parity_response.get("events", []))
	var saw_move_event := false
	for event in move_events:
		if typeof(event) == TYPE_DICTIONARY and String(Dictionary(event).get("type", "")) == "MOVE_HERO":
			saw_move_event = true
	_expect(saw_move_event, "MOVE_HERO response events include structured MOVE_HERO event")
	move_parity_actor = move_parity_state.unit_by_id("pal_002")
	_expect(int(move_parity_actor.get("x", -1)) == 4 and int(move_parity_actor.get("y", -1)) == 5, "MOVE_HERO can move farther than one adjacent cell when moveRange allows it")
	_expect(int(move_parity_state.snapshot().get("ap", 0)) == move_parity_ap_before, "MOVE_HERO does not spend global battle AP")
	var move_parity_team_preview := Dictionary(move_parity_state.snapshot().get("teamPlacementPreview", {}))
	_expect(String(move_parity_team_preview.get("activeUnitId", "")) == "pal_002", "MOVE_HERO records activeUnitId for cumulative team placement preview")
	_expect(Array(move_parity_team_preview.get("movedUnitIds", [])).has("pal_002"), "MOVE_HERO records movedUnitIds for cumulative team placement preview")
	var move_parity_board_cell := _board_cell(move_parity_state, 4, 5)
	_expect(String(move_parity_board_cell.get("unitId", "")) == "pal_002", "MOVE_HERO updates the browser-style board cell projection")
	var move_preview := Dictionary(move_parity_response.get("manualFlowPreview", {}))
	_expect(not move_preview.is_empty(), "MOVE_HERO response carries post-move manualFlowPreview")
	var move_preview_commands := Array(move_preview.get("commands", []))
	_expect(move_preview_commands.size() >= 2, "MOVE_HERO manualFlowPreview runs the next two formal flow commands")
	if move_preview_commands.size() >= 2:
		_expect(String(Dictionary(move_preview_commands[0]).get("type", "")) == "RUN_PLAYER_ALL_OUT", "MOVE_HERO manualFlowPreview first command is RUN_PLAYER_ALL_OUT")
	_expect(String(Dictionary(move_preview_commands[1]).get("type", "")) == "END_PLAYER_TURN", "MOVE_HERO manualFlowPreview second command is END_PLAYER_TURN")
	var move_cell_diffs := Array(move_preview.get("cellDiffs", []))
	var move_unit_diffs := Array(move_preview.get("unitDiffs", []))
	_expect(move_cell_diffs.size() > 0, "MOVE_HERO manualFlowPreview carries full-cell diffs")
	_expect(move_unit_diffs.size() > 0, "MOVE_HERO manualFlowPreview carries unit diffs")
	if move_cell_diffs.size() > 0:
		var first_cell_diff := Dictionary(move_cell_diffs[0])
		_expect(first_cell_diff.has("r") and first_cell_diff.has("c") and first_cell_diff.has("key") and first_cell_diff.has("before") and first_cell_diff.has("after"), "MOVE_HERO manualFlowPreview cellDiff schema matches browser preview")
		_expect(not first_cell_diff.has("kind") and not first_cell_diff.has("index"), "MOVE_HERO manualFlowPreview cellDiff omits Godot-only kind/index schema")
	if move_unit_diffs.size() > 0:
		var first_unit_diff := Dictionary(move_unit_diffs[0])
		_expect(first_unit_diff.has("id") and first_unit_diff.has("before") and first_unit_diff.has("after") and first_unit_diff.has("enemyIds") and first_unit_diff.has("threats"), "MOVE_HERO manualFlowPreview unitDiff schema includes browser threat source fields")
	var move_target_diff := {}
	for diff_value in move_unit_diffs:
		if typeof(diff_value) == TYPE_DICTIONARY and String(Dictionary(diff_value).get("id", "")) == move_parity_target_id:
			move_target_diff = Dictionary(diff_value)
			break
	var move_damage_summary := Dictionary(move_target_diff.get("damageSummary", {}))
	_expect(int(move_damage_summary.get("totalDamage", 0)) > 0, "MOVE_HERO manualFlowPreview aggregates target totalDamage")
	_expect(int(move_damage_summary.get("hpDamage", 0)) > 0, "MOVE_HERO manualFlowPreview aggregates target hpDamage")
	_expect(int(move_damage_summary.get("hpFrom", -1)) == 50 and int(move_damage_summary.get("hpTo", -1)) < 50, "MOVE_HERO manualFlowPreview exposes target hp range")
	var move_target_cell := _board_cell(move_parity_state, 5, 5)
	var move_target_threat := Dictionary(move_target_cell.get("threat", {}))
	_expect(String(move_target_threat.get("source", "")) == "manual_flow_preview", "MOVE_HERO projects manual-flow damage onto the current target cell")
	_expect(int(move_target_threat.get("totalDamage", 0)) == int(move_damage_summary.get("totalDamage", -1)), "MOVE_HERO board threat reuses the core damage summary")
	_expect(int(move_parity_state.unit_by_id(move_parity_target_id).get("hp", 0)) == 50, "MOVE_HERO damage preview keeps authoritative target hp unchanged")
	var move_log_line := String(Array(move_parity_state.snapshot().get("log_lines", [])).back())
	_expect(not move_log_line.contains("预计HP损失") and not move_log_line.contains("预计护盾消耗"), "MOVE_HERO log stays free of single-unit risk text")
	var move_reject_version := int(move_parity_state.snapshot().get("stateVersion", 0))
	var move_reject_response := move_parity_state.run_command({
		"type": "MOVE_HERO",
		"unitId": "pal_002",
		"to": {"r": 99, "c": 99},
		"baseStateVersion": move_reject_version,
		"commandId": "smoke_move_out_of_board"
	})
	_expect(bool(move_reject_response.get("ok", false)) and bool(move_reject_response.get("accepted", false)), "blocked MOVE_HERO is still an accepted command envelope")
	_expect(move_reject_response.get("result", true) == false, "blocked MOVE_HERO returns result false")
	_expect(int(move_parity_state.snapshot().get("stateVersion", -1)) == move_reject_version + 1, "blocked MOVE_HERO advances stateVersion like browser adapter")
	var move_reject_events := Array(move_reject_response.get("events", []))
	var move_reject_event_type := ""
	if move_reject_events.size() > 0:
		move_reject_event_type = String(Dictionary(move_reject_events[0]).get("type", ""))
	_expect(move_reject_events.size() > 0 and move_reject_event_type == "MOVE_HERO_BLOCKED", "rejected MOVE_HERO response carries structured blocked event")
	_expect(_log_contains(move_parity_state.snapshot()["log_lines"], "超出棋盘"), "out-of-board MOVE_HERO writes a visible failure log")
	var move_yellow_state := _new_legacy_state()
	_expect(move_yellow_state.dispatch({"type": "START_BATTLE"}), "yellow target legality MOVE_HERO fixture can start battle")
	var move_yellow_actor := move_yellow_state.unit_by_id("pal_002")
	for move_yellow_unit in move_yellow_state.units:
		if String(move_yellow_unit.get("side", "")) == StateScript.PLAYER and String(move_yellow_unit.get("id", "")) != "pal_002":
			move_yellow_unit["hp"] = 0
	_place_first_enemy(move_yellow_state, 7, 0, 20)
	move_yellow_actor["x"] = 1
	move_yellow_actor["y"] = 5
	move_yellow_actor["move_range"] = 2
	move_yellow_actor["moveRange"] = 2
	move_yellow_actor["has_attacked"] = false
	var move_yellow_range_response := move_yellow_state.run_command({"type": "MOVE_HERO", "unitId": "pal_002", "to": {"r": 5, "c": 7}, "baseStateVersion": int(move_yellow_state.snapshot().get("stateVersion", 0))})
	_expect(bool(move_yellow_range_response.get("ok", false)) and move_yellow_range_response.get("result", true) == false, "yellow target beyond moveRange is rejected instead of snapping nearby")
	move_yellow_actor = move_yellow_state.unit_by_id("pal_002")
	_expect(int(move_yellow_actor.get("x", -1)) == 1 and int(move_yellow_actor.get("y", -1)) == 5, "range-invalid yellow target keeps the pet at its source")
	_expect(_log_contains(move_yellow_state.snapshot()["log_lines"], "移动力2"), "range-invalid yellow target writes a visible movement-range failure log")
	var move_yellow_blocker_id := _place_first_enemy(move_yellow_state, 2, 5, 20)
	move_yellow_actor["move_range"] = 1
	move_yellow_actor["moveRange"] = 1
	var move_yellow_occupied_response := move_yellow_state.run_command({"type": "MOVE_HERO", "unitId": "pal_002", "to": {"r": 5, "c": 2}, "baseStateVersion": int(move_yellow_state.snapshot().get("stateVersion", 0))})
	_expect(move_yellow_blocker_id != "" and bool(move_yellow_occupied_response.get("ok", false)) and move_yellow_occupied_response.get("result", true) == false, "occupied yellow target is rejected instead of snapping nearby")
	move_yellow_actor = move_yellow_state.unit_by_id("pal_002")
	_expect(int(move_yellow_actor.get("x", -1)) == 1 and int(move_yellow_actor.get("y", -1)) == 5, "occupied yellow target keeps the pet at its source")
	_expect(_log_contains(move_yellow_state.snapshot()["log_lines"], "已被占用"), "occupied yellow target writes a visible occupancy failure log")
	var move_reject_selection_state := _new_legacy_state()
	_expect(move_reject_selection_state.dispatch({"type": "START_BATTLE"}), "move reject selection fixture can start battle")
	var other_move_unit_id := "smoke_selected_other"
	var other_move_unit := move_reject_selection_state.unit_by_id("pal_002").duplicate(true)
	other_move_unit["id"] = other_move_unit_id
	other_move_unit["name"] = "选择保持测试"
	other_move_unit["x"] = 0
	other_move_unit["y"] = 0
	other_move_unit["hp"] = max(1, int(other_move_unit.get("hp", 1)))
	move_reject_selection_state.units.append(other_move_unit)
	_expect(other_move_unit_id != "", "move reject selection fixture has a different living pet")
	_expect(move_reject_selection_state.dispatch({"type": "SELECT_UNIT", "unitId": other_move_unit_id}), "move reject selection fixture can select a different pet")
	var move_reject_selection_version := int(move_reject_selection_state.snapshot().get("stateVersion", 0))
	var move_reject_selection_response := move_reject_selection_state.run_command({
		"type": "MOVE_HERO",
		"unitId": "pal_002",
		"to": {"r": 99, "c": 99},
		"baseStateVersion": move_reject_selection_version,
		"commandId": "smoke_move_reject_selection"
	})
	_expect(bool(move_reject_selection_response.get("ok", false)) and move_reject_selection_response.get("result", true) == false, "blocked MOVE_HERO with unitId stays accepted with result false")
	_expect(String(move_reject_selection_state.snapshot().get("selected_unit_id", "")) == other_move_unit_id, "rejected MOVE_HERO with unitId does not mutate current selection")
	var move_has_attacked_state := _new_legacy_state()
	_expect(move_has_attacked_state.dispatch({"type": "START_BATTLE"}), "move hasAttacked fixture can start battle")
	var move_has_attacked_actor := move_has_attacked_state.unit_by_id("pal_002")
	move_has_attacked_actor["has_attacked"] = false
	move_has_attacked_actor["hasAttacked"] = true
	var move_has_attacked_response := move_has_attacked_state.run_command({"type": "MOVE_HERO", "unitId": "pal_002", "to": {"r": 5, "c": 4}, "baseStateVersion": int(move_has_attacked_state.snapshot().get("stateVersion", 0))})
	_expect(bool(move_has_attacked_response.get("ok", false)) and move_has_attacked_response.get("result", true) == false, "MOVE_HERO blocks H5-style hasAttacked flag with result false")
	var move_ap_state := _new_legacy_state()
	_expect(move_ap_state.dispatch({"type": "START_BATTLE"}), "moveAp fixture can start battle")
	var move_ap_actor := move_ap_state.unit_by_id("pal_002")
	move_ap_actor["x"] = 1
	move_ap_actor["y"] = 5
	move_ap_actor.erase("move_range")
	move_ap_actor.erase("moveRange")
	move_ap_actor["moveAp"] = 0
	move_ap_actor["ap"] = 3
	var move_ap_response := move_ap_state.run_command({"type": "MOVE_HERO", "unitId": "pal_002", "to": {"r": 5, "c": 2}, "baseStateVersion": int(move_ap_state.snapshot().get("stateVersion", 0))})
	_expect(bool(move_ap_response.get("ok", false)) and move_ap_response.get("result", true) == false, "yellow target with moveAp=0 is rejected instead of snapping to the current cell")
	move_ap_actor = move_ap_state.unit_by_id("pal_002")
	_expect(int(move_ap_actor.get("x", -1)) == 1 and int(move_ap_actor.get("y", -1)) == 5, "MOVE_HERO still honors moveAp=0 instead of falling back to AP")
	_finish("SMOKE_SINGLEPLAYER_POSITIONING_OK")
