extends SceneTree

const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := MockSession.new({"start_phase": "battle"})
	var first_auto_response := Dictionary(session.call("submit_command", {
		"type": "AUTO_POSITION_HEROES",
	}))
	if not _check(bool(first_auto_response.get("accepted", false)), "first auto-position was rejected"):
		return
	var previous_snapshot := Dictionary(session.call("current_snapshot"))

	var first_response := Dictionary(session.call("submit_command", {
		"type": "RUN_COMBAT_ROUND",
	}))
	if not _check(bool(first_response.get("accepted", false)), "first combat round was rejected"):
		return
	var first_snapshot := Dictionary(session.call("current_snapshot"))
	if not _assert_trace_element_outcomes(previous_snapshot, first_snapshot, 0):
		return
	if not _check(
		_visible_empty_element_cell_count(first_snapshot) == 0,
		"occupied first-round hits left element tiles on empty cells"
	):
		return

	var first_trace_count := Array(
		first_snapshot.get("battleTrace", first_snapshot.get("battle_trace", []))
	).size()
	var second_auto_response := Dictionary(session.call("submit_command", {
		"type": "AUTO_POSITION_HEROES",
	}))
	if not _check(bool(second_auto_response.get("accepted", false)), "second auto-position was rejected"):
		return
	previous_snapshot = Dictionary(session.call("current_snapshot"))
	var second_response := Dictionary(session.call("submit_command", {
		"type": "RUN_COMBAT_ROUND",
	}))
	if not _check(bool(second_response.get("accepted", false)), "second combat round was rejected"):
		return
	var second_snapshot := Dictionary(session.call("current_snapshot"))
	if not _assert_trace_element_outcomes(previous_snapshot, second_snapshot, first_trace_count):
		return
	if not _check(
		_visible_empty_element_cell_count(second_snapshot) > 0,
		"empty second-round hits did not retain element tiles"
	):
		return

	var second_trace_count := Array(
		second_snapshot.get("battleTrace", second_snapshot.get("battle_trace", []))
	).size()
	var third_auto_response := Dictionary(session.call("submit_command", {
		"type": "AUTO_POSITION_HEROES",
	}))
	if not _check(bool(third_auto_response.get("accepted", false)), "third auto-position was rejected"):
		return
	previous_snapshot = Dictionary(session.call("current_snapshot"))
	var third_response := Dictionary(session.call("submit_command", {
		"type": "RUN_COMBAT_ROUND",
	}))
	if not _check(bool(third_response.get("accepted", false)), "third combat round was rejected"):
		return
	var third_snapshot := Dictionary(session.call("current_snapshot"))
	if not _assert_trace_element_outcomes(previous_snapshot, third_snapshot, second_trace_count):
		return
	if not _check(
		String(third_snapshot.get("phase", "")) == "battle_end",
		"third combat round did not reach battle_end"
	):
		return

	print("SMOKE_BATTLE_ELEMENT_TILE_OUTCOMES_PASS")
	quit()


func _assert_trace_element_outcomes(
	previous_snapshot: Dictionary,
	current_snapshot: Dictionary,
	first_new_event: int
) -> bool:
	var expected := _element_layers_by_coordinate(previous_snapshot)
	var checked_keys := {}
	var trace := Array(current_snapshot.get(
		"battleTrace",
		current_snapshot.get("battle_trace", [])
	))
	var event_index := first_new_event
	var occupied_targets_checked := 0
	var empty_targets_checked := 0
	while event_index < trace.size():
		var event := Dictionary(trace[event_index])
		if String(event.get("type", "")) != "ELEMENT_APPLIED":
			event_index += 1
			continue
		var payload := Dictionary(event.get("payload", {}))
		var element := String(payload.get("element", ""))
		var application_targets := {}
		for target_value in Array(payload.get("targets", [])):
			var target := Dictionary(target_value)
			application_targets[_coordinate_key(target)] = true
		var occupied_targets := {}
		var observed_attack_strike := false
		var scan_index := event_index + 1
		while scan_index < trace.size():
			var following_event := Dictionary(trace[scan_index])
			if String(following_event.get("type", "")) == "ELEMENT_APPLIED":
				break
			if String(following_event.get("type", "")) == "ATTACK_STRIKE":
				var strike_payload := Dictionary(following_event.get("payload", {}))
				if bool(strike_payload.get("applyElementOnImpact", false)) \
						and String(strike_payload.get("element", "")) == element:
					observed_attack_strike = true
					for strike_target_value in Array(strike_payload.get("targets", [])):
						var strike_target := Dictionary(strike_target_value)
						var target_id := String(strike_target.get(
							"id",
							strike_target.get("unitId", strike_target.get("unit_id", ""))
						)).strip_edges()
						var key := _coordinate_key(strike_target)
						if target_id != "" and application_targets.has(key):
							occupied_targets[key] = true
			scan_index += 1
		if not observed_attack_strike:
			event_index = scan_index
			continue
		for change_value in Array(event.get("changes", [])):
			var change := Dictionary(change_value)
			var key := _change_coordinate_key(change)
			var expected_key := "%s|%s" % [key, element]
			checked_keys[expected_key] = true
			if occupied_targets.has(key):
				occupied_targets_checked += 1
			else:
				empty_targets_checked += 1
				expected[expected_key] = int(expected.get(expected_key, 0)) \
					+ int(change.get("delta", 0))
		event_index = scan_index

	var actual := _element_layers_by_coordinate(current_snapshot)
	for key in checked_keys.keys():
		if not _check(
			int(actual.get(key, 0)) == int(expected[key]),
			"unexpected element layers at %s: expected=%d actual=%d" % [
				String(key),
				int(expected[key]),
				int(actual.get(key, 0)),
			]
		):
			return false
	if not _check(occupied_targets_checked > 0, "trace did not expose occupied hit targets"):
		return false
	if first_new_event > 0:
		if not _check(empty_targets_checked > 0, "trace did not expose empty hit targets"):
			return false
	return true


func _element_layers_by_coordinate(snapshot: Dictionary) -> Dictionary:
	var result := {}
	for cell_value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		var cell := Dictionary(cell_value)
		var coordinate_key := _coordinate_key(cell)
		for element_value in Dictionary(cell.get("elements", {})).keys():
			var element := String(element_value)
			result["%s|%s" % [coordinate_key, element]] = int(
				Dictionary(cell.get("elements", {})).get(element_value, 0)
			)
	return result


func _visible_empty_element_cell_count(snapshot: Dictionary) -> int:
	var count := 0
	for cell_value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		var cell := Dictionary(cell_value)
		if String(cell.get("unitId", cell.get("unit_id", ""))) != "":
			continue
		for layers in Dictionary(cell.get("elements", {})).values():
			if int(layers) > 0:
				count += 1
				break
	return count


func _coordinate_key(record: Dictionary) -> String:
	return "%d,%d" % [
		int(record.get("x", record.get("c", -1))),
		int(record.get("y", record.get("r", -1))),
	]


func _change_coordinate_key(change: Dictionary) -> String:
	var path_parts := String(change.get("path", "")).split(".")
	if not _check(path_parts.size() >= 3, "element change path is malformed"):
		return ""
	if not _check(path_parts[0] == "cell_elements", "element change path has wrong prefix"):
		return ""
	return String(path_parts[1])


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("SMOKE_BATTLE_ELEMENT_TILE_OUTCOMES_FAIL: %s" % message)
	quit(1)
	return false
