extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const SmokeContextScript := preload("res://tests/helpers/singleplayer_smoke_context.gd")
const QualityProgressionPolicyScript := preload("res://core/party/quality_progression_policy.gd")

var _smoke_context := SmokeContextScript.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(false, "singleplayer smoke suite must override _run()")
	_finish("SMOKE_SINGLEPLAYER_SUITE_INVALID")


func _finish(sentinel: String) -> void:
	if _smoke_context.has_failures():
		for failure in _smoke_context.failure_messages():
			push_error(failure)
		quit(1)
		return
	print(sentinel)
	quit(0)


func _new_legacy_state() -> StateScript:
	return _smoke_context.new_legacy_state()


func _expect(condition: bool, message: String) -> void:
	_smoke_context.expect(self, condition, message)

func _find_button_with_command(root_node: Node, command_type: String, kind: String = "") -> BaseButton:
	for node in root_node.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != command_type:
			continue
		if kind == "" or _command_matches_kind(button, command, kind):
			return button
	return null

func _command_button_count(root_node: Node, command_type: String) -> int:
	var count := 0
	for node in root_node.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == command_type:
			count += 1
	return count

func _command_matches_kind(button: BaseButton, command: Dictionary, kind: String) -> bool:
	var text := "%s %s %s" % [
		String(command.get("option_id", "")),
		String(button.get_meta("route_kind", "")),
		String(command.get("nodeId", ""))
	]
	var lower_text := text.to_lower()
	if kind == "shop":
		return lower_text.contains("shop") or text.contains("商店")
	if kind == "reward":
		return lower_text.contains("reward") or text.contains("奖励")
	if kind == "battle":
		return lower_text.contains("battle") or text.contains("战斗")
	return String(button.get_meta("route_kind", "")) == kind

func _command_log_contains_type(command_log: Array, command_type: String) -> bool:
	for item in command_log:
		if typeof(item) == TYPE_DICTIONARY and String(Dictionary(item).get("type", "")) == command_type:
			return true
	return false

func _actions(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("next_actions", []))

func _action_count(snapshot: Dictionary, action_type: String) -> int:
	var count := 0
	for action in _actions(snapshot):
		if String(Dictionary(action).get("type", "")) == action_type:
			count += 1
	return count

func _has_action(snapshot: Dictionary, action_type: String) -> bool:
	return _action_count(snapshot, action_type) > 0

func _battle_wave(snapshot: Dictionary, wave_id: String, round_number: int) -> Dictionary:
	for item in Array(Dictionary(snapshot.get("battle", {})).get("waves", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("id", "")) == wave_id and int(row.get("round", -1)) == round_number:
			return row
	return {}

func _wave_enemy_player_action_field_count(snapshot: Dictionary) -> int:
	var count := 0
	for wave_value in Array(Dictionary(snapshot.get("battle", {})).get("waves", [])):
		if typeof(wave_value) != TYPE_DICTIONARY:
			continue
		for enemy_value in Array(Dictionary(wave_value).get("enemies", [])):
			if typeof(enemy_value) != TYPE_DICTIONARY:
				continue
			var enemy := Dictionary(enemy_value)
			for field in ["action_type", "skill", "shape", "range", "shape_id"]:
				if String(enemy.get(field, "")).strip_edges() != "":
					count += 1
	return count

func _economy_event(state: StateScript, event_id: String) -> Dictionary:
	for item in Array(Dictionary(state.game_data.get("economy", {})).get("events", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("id", "")) == event_id:
			return row
	return {}

func _economy_events_contain_text(state: StateScript, text: String) -> bool:
	for item in Array(Dictionary(state.game_data.get("economy", {})).get("events", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		for key in ["name", "option_text", "gain", "note"]:
			if String(row.get(key, "")).contains(text):
				return true
	return false

func _first_action(snapshot: Dictionary, action_type: String) -> Dictionary:
	for action in _actions(snapshot):
		var row := Dictionary(action)
		if String(row.get("type", "")) == action_type:
			return row
	return {}

func _alive_enemy_count(units: Array) -> int:
	var count := 0
	for unit in units:
		if String(unit.get("side", "")) == StateScript.ENEMY and int(unit.get("hp", 0)) > 0:
			count += 1
	return count

func _any_alive_enemy_with_hp(units: Array, hp: int) -> bool:
	for unit in units:
		if String(unit.get("side", "")) == StateScript.ENEMY and int(unit.get("hp", 0)) == hp:
			return true
	return false

func _alive_player_count(units: Array) -> int:
	var count := 0
	for unit in units:
		if String(unit.get("side", "")) == StateScript.PLAYER and int(unit.get("hp", 0)) > 0:
			count += 1
	return count

func _clear_battle_to_result(state: StateScript) -> void:
	state.enemy_hero_hp = 0
	state._check_battle_end()

func _drive_current_day_to_end(state: StateScript) -> void:
	var starting_day := int(state.snapshot().get("day", 1))
	var guard := 0
	while int(state.snapshot().get("day", starting_day)) == starting_day and String(state.snapshot().get("phase", "")) != "day_end" and guard < 40:
		guard += 1
		var snap := state.snapshot()
		match String(snap.get("phase", "")):
			"route":
				var options := Array(snap.get("route_options", []))
				_expect(not options.is_empty(), "day-end driver has a route option before day end")
				var option := Dictionary(options[0])
				_expect(state.dispatch({"type": "PICK_NODE", "nodeId": String(option.get("nodeId", option.get("id", "")))}), "day-end driver can pick a route option")
			"shop":
				_expect(state.dispatch({"type": "EXIT_SHOP"}), "day-end driver can exit shop")
			"reward":
				_expect(state.dispatch({"type": "PICK_REWARD", "index": 0}), "day-end driver can pick reward")
			"battle":
				_clear_battle_to_result(state)
			"battle_end":
				_expect(state.dispatch({"type": "CONTINUE_AFTER_BATTLE"}), "day-end driver can continue after battle")
			_:
				_expect(false, "day-end driver reached unsupported phase %s" % String(snap.get("phase", "")))
	_expect(guard < 40, "day-end driver finishes within guard")

func _assert_state_round_trip(state: StateScript, label: String) -> void:
	var before_snapshot := state.snapshot()
	var before_phase := String(before_snapshot.get("phase", ""))
	var before_hash := String(before_snapshot.get("stateHash", ""))
	var before_version := int(before_snapshot.get("stateVersion", -1))
	var document := state.save_document("round-trip")
	var restored := _new_legacy_state()
	_expect(restored.load_document(document), "%s: load_document accepts saved document" % label)
	var after_snapshot := restored.snapshot()
	_expect(String(after_snapshot.get("phase", "")) == before_phase, "%s: phase survives save/load" % label)
	_expect(int(after_snapshot.get("stateVersion", -1)) == before_version, "%s: stateVersion survives save/load" % label)
	_expect(String(after_snapshot.get("stateHash", "")) == before_hash, "%s: stateHash survives save/load" % label)

func _assert_replay_error(state: StateScript, replay: Dictionary, expected_error: String, label: String) -> void:
	var result := state.verify_replay_document(replay)
	_expect(not bool(result.get("ok", true)), "%s returns ok=false" % label)
	_expect(String(result.get("error", "")) == expected_error, "%s returns %s" % [label, expected_error])

func _first_trace_event(events: Array, event_type: String) -> Dictionary:
	for event in events:
		var row := Dictionary(event)
		if String(row.get("type", "")) == event_type:
			return row
	return {}

func _fixture_pet(pet_id: String, display_name: String) -> Dictionary:
	return {
		"id": pet_id,
		"pet_id": pet_id,
		"name": display_name,
		"element": "风",
		"role": "测试",
		"quality": "青铜",
		"max_hp": 12,
		"hp": 12,
		"atk": 3,
		"def": 0,
		"shield": 0,
		"ap": 3,
		"shape": "02",
		"shape_id": "02",
		"range": "近战",
		"price": 2
	}

func _all_shop_offers_match_element(offers: Array, element: String) -> bool:
	if offers.is_empty():
		return false
	for offer in offers:
		if String(offer.get("element", "")) != element:
			return false
	return true

func _offer_pet_ids(snapshot: Dictionary) -> Array:
	var ids: Array = []
	for offer in Array(snapshot.get("shop_offers", [])):
		var row := Dictionary(offer)
		ids.append("%s:%s:%s" % [
			String(row.get("offer_id", row.get("id", ""))),
			String(row.get("pet_id", "")),
			String(row.get("pool_id", ""))
		])
	return ids

func _roster_pet(roster: Array, pet_id: String) -> Dictionary:
	for pet in roster:
		var row := Dictionary(pet)
		if String(row.get("pet_id", row.get("id", ""))) == pet_id:
			return row
	return {}

func _option_ids(options: Array) -> Array:
	var ids: Array = []
	for option in options:
		var row := Dictionary(option)
		ids.append(String(row.get("id", row.get("optionId", ""))))
	return ids

func _has_option(options: Array, id: String) -> bool:
	for option in options:
		var row := Dictionary(option)
		if String(row.get("id", "")) == id or String(row.get("nodeId", "")) == id or String(row.get("optionId", "")) == id:
			return true
	return false

func _first_route_option_by_kind(options: Array, kind: String) -> Dictionary:
	for option in options:
		var row := Dictionary(option)
		if String(row.get("kind", "")) == kind:
			return row
	return {}

func _advance_one_route_node_for_smoke(state, label: String) -> void:
	var snap: Dictionary = state.snapshot()
	_expect(String(snap.get("phase", "")) == "route", "%s starts in route phase" % label)
	var options := Array(snap.get("route_options", []))
	_expect(not options.is_empty(), "%s has route options" % label)
	if options.is_empty():
		return
	var option := Dictionary(options[0])
	_expect(String(option.get("kind", "")) != "battle", "%s uses an ordinary route node before fixed battle" % label)
	_expect(state.dispatch({"type": "PICK_NODE", "nodeId": String(option.get("nodeId", option.get("id", "")))}), "%s can pick the next ordinary route node" % label)
	var next_phase := String(state.snapshot().get("phase", ""))
	if next_phase == "shop":
		_expect(state.dispatch({"type": "EXIT_SHOP"}), "%s can leave shop" % label)
	elif next_phase == "reward":
		_expect(state.dispatch({"type": "PICK_REWARD", "index": 0}), "%s can claim reward" % label)
	elif not ["route", "day_end", "game_over"].has(next_phase):
		_expect(false, "%s returned an unsupported phase %s" % [label, next_phase])

func _first_pet_reward(options: Array) -> Dictionary:
	for option in options:
		var row := Dictionary(option)
		if String(row.get("type", "pet")) == "pet" and String(row.get("pet_id", "")) != "":
			return row
	return {}

func _all_reward_options_are_pets(options: Array) -> bool:
	for option in options:
		var row := Dictionary(option)
		if String(row.get("type", "pet")) != "pet" or String(row.get("pet_id", "")) == "":
			return false
	return true

func _has_summary_kind(tags: Array, kind: String) -> bool:
	for tag in tags:
		if String(Dictionary(tag).get("kind", "")) == kind:
			return true
	return false

func _has_roster_pet(roster: Array, pet_id: String) -> bool:
	if pet_id == "":
		return false
	for pet in roster:
		var row := Dictionary(pet)
		if String(row.get("pet_id", row.get("id", ""))) == pet_id:
			return true
	return false

func _source_files_include(snapshot: Dictionary, source_file: String) -> bool:
	for file in Array(Dictionary(snapshot.get("source", {})).get("files", [])):
		if String(file) == source_file:
			return true
	return false

func _has_post_battle_event(result: Dictionary, event_id: String) -> bool:
	for event in Array(result.get("post_battle_events", [])):
		if String(Dictionary(event).get("event_id", "")) == event_id:
			return true
	return false

func _post_battle_event(result: Dictionary, event_id: String) -> Dictionary:
	for event in Array(result.get("post_battle_events", [])):
		var row := Dictionary(event)
		if String(row.get("event_id", "")) == event_id:
			return row
	return {}

func _has_shop_event(snapshot: Dictionary, event_id: String) -> bool:
	for event in Array(snapshot.get("shop_events", [])):
		if String(Dictionary(event).get("id", "")) == event_id:
			return true
	return false

func _snapshot_has_next_action(snapshot: Dictionary, action_type: String) -> bool:
	for action in Array(snapshot.get("next_actions", snapshot.get("nextActions", []))):
		if String(Dictionary(action).get("type", "")) == action_type:
			return true
	return false

func _preview_rows_by_target(state: StateScript) -> Dictionary:
	var rows := {}
	var result_value: Variant = state.snapshot().get("last_command_result", [])
	var result: Array = Array(result_value) if typeof(result_value) == TYPE_ARRAY else []
	for row_value in result:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(row_value)
		rows[String(row.get("targetId", ""))] = row
	return rows

func _offer_by_id(offers: Array, offer_id: String) -> Dictionary:
	for offer in offers:
		var row := Dictionary(offer)
		if String(row.get("offer_id", row.get("id", ""))) == offer_id or String(row.get("id", "")) == offer_id:
			return row
	return {}

func _has_summary_tag(tags: Array, kind: String, label: String) -> bool:
	for tag in tags:
		var row := Dictionary(tag)
		if String(row.get("kind", "")) == kind and String(row.get("label", "")) == label:
			return true
	return false

func _find_offer_id_by_pet(state: StateScript, pet_id: String) -> String:
	for offer in Array(state.snapshot().get("shop_offers", [])):
		var row := Dictionary(offer)
		if String(row.get("pet_id", "")) == pet_id:
			return String(row.get("offer_id", row.get("id", "")))
	return ""

func _first_buyable_offer_id(state: StateScript) -> String:
	var snap: Dictionary = state.snapshot()
	var coins := int(snap.get("coins", 0))
	for offer in Array(snap.get("shop_offers", [])):
		var row := Dictionary(offer)
		var offer_id := String(row.get("offer_id", row.get("id", "")))
		if offer_id == "":
			continue
		if bool(row.get("sold", false)):
			continue
		if int(row.get("price", 0)) > coins:
			continue
		return offer_id
	return ""

func _set_roster_quality(state: StateScript, pet_id: String, quality: String) -> Dictionary:
	for index in range(state.roster.size()):
		var pet := Dictionary(state.roster[index])
		if String(pet.get("pet_id", pet.get("id", ""))) != pet_id:
			continue
		pet["quality"] = quality
		var progressed := _progress_quality_fixture(state, pet)
		if progressed.is_empty():
			return {}
		state.roster[index] = progressed
		return progressed
	return {}

func _set_roster_quality_with_growth(state: StateScript, pet_id: String, quality: String, growth_mode: String, seed: String) -> Dictionary:
	for index in range(state.roster.size()):
		var pet := Dictionary(state.roster[index])
		if String(pet.get("pet_id", pet.get("id", ""))) != pet_id:
			continue
		pet["quality"] = quality
		pet["quality_growth_mode"] = growth_mode
		pet["quality_growth_seed"] = seed
		var progressed := _progress_quality_fixture(state, pet)
		if progressed.is_empty():
			return {}
		state.roster[index] = progressed
		return progressed
	return {}

func _progress_quality_fixture(state: StateScript, pet: Dictionary) -> Dictionary:
	var result := QualityProgressionPolicyScript.new().progress(
		pet,
		{"gameData": state.game_data.duplicate(true)},
		true
	)
	_expect(bool(result.get("ok", false)), "quality fixture progression succeeds")
	return Dictionary(result.get("unit", {})) if bool(result.get("ok", false)) else {}

func _set_unit_quality_upgrade(state: StateScript, unit_id: String, upgrade_id: String) -> void:
	var unit := state.unit_by_id(unit_id)
	if unit.is_empty():
		return
	for item in Array(Dictionary(state.game_data.get("quality", {})).get("upgrades", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("id", "")) != upgrade_id:
			continue
		unit["quality_upgrade"] = row.duplicate(true)
		var progression := Dictionary(unit.get("quality_progression", {}))
		progression["upgrade_id"] = upgrade_id
		progression["upgrade_name"] = String(row.get("name", upgrade_id))
		unit["quality_progression"] = progression
		return

func _zero_enemy_attack(state: StateScript) -> void:
	for index in range(state.units.size()):
		var unit := Dictionary(state.units[index])
		if String(unit.get("side", "")) == "enemy":
			unit["atk"] = 0
			state.units[index] = unit

func _set_unit_shape(state: StateScript, unit_id: String, shape_id: String, hit_cells: int) -> void:
	var unit := state.unit_by_id(unit_id)
	if unit.is_empty():
		return
	unit["shape_id"] = shape_id
	unit["shape"] = shape_id
	unit["hit_cells"] = hit_cells

func _board_cell(state: StateScript, x: int, y: int) -> Dictionary:
	for cell in Array(Dictionary(state.snapshot().get("board", {})).get("cells", [])):
		var row := Dictionary(cell)
		if int(row.get("x", -1)) == x and int(row.get("y", -1)) == y:
			return row
	return {}

func _first_adjacent_empty_cell(state: StateScript, unit: Dictionary) -> Dictionary:
	var x := int(unit.get("x", -1))
	var y := int(unit.get("y", -1))
	for delta in [
		{"x": 1, "y": 0},
		{"x": -1, "y": 0},
		{"x": 0, "y": 1},
		{"x": 0, "y": -1}
	]:
		var target_x := x + int(Dictionary(delta).get("x", 0))
		var target_y := y + int(Dictionary(delta).get("y", 0))
		if target_x < 0 or target_y < 0 or target_x >= state.board_width or target_y >= state.board_height:
			continue
		if state.unit_at(target_x, target_y).is_empty():
			return {"c": target_x, "r": target_y}
	return {}

func _total_element_layers(unit: Dictionary) -> int:
	var total := 0
	for value in Dictionary(unit.get("elements", {})).values():
		total += int(value)
	return total

func _trace_ids(traces: Array) -> Array:
	var ids: Array = []
	for item in traces:
		if typeof(item) == TYPE_DICTIONARY:
			ids.append(String(Dictionary(item).get("id", "")))
	return ids

func _battle_trace_has_type(state: StateScript, event_type: String) -> bool:
	for event_value in state.battle_trace:
		if String(Dictionary(event_value).get("type", "")) == event_type:
			return true
	return false

func _battle_trace_damage_target_count(state: StateScript, target_id: String, source_type: String = "") -> int:
	var count := 0
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) != "DAMAGE_APPLIED":
			continue
		var target := Dictionary(event.get("target", {}))
		if String(target.get("id", "")) != target_id:
			continue
		var payload := Dictionary(event.get("payload", {}))
		if source_type != "" and String(payload.get("sourceType", "")) != source_type:
			continue
		count += 1
	return count

func _append_player_clone(state: StateScript, source_id: String, clone_id: String, x: int, y: int, hp: int) -> String:
	var source := state.unit_by_id(source_id)
	if source.is_empty():
		return ""
	var clone: Dictionary = source.duplicate(true)
	clone["id"] = clone_id
	clone["pet_id"] = clone_id
	clone["name"] = "%s-测试友方" % String(source.get("name", "我方"))
	clone["x"] = x
	clone["y"] = y
	clone["hp"] = hp
	clone["max_hp"] = max(hp, int(clone.get("max_hp", hp)))
	clone["shield"] = 0
	clone["side"] = StateScript.PLAYER
	state.units.append(clone)
	return clone_id

func _place_first_enemy(state: StateScript, x: int, y: int, hp: int) -> String:
	# Legacy mechanic fixtures isolate a stable target; reset behavior has its own smoke.
	state.pet_reset_charges[StateScript.ENEMY] = 0
	state.pet_reset_next_charge_round[StateScript.ENEMY] = 999
	var picked_id := ""
	for unit in state.units:
		if String(unit.get("side", "")) != StateScript.ENEMY:
			continue
		if picked_id == "":
			unit["x"] = x
			unit["y"] = y
			unit["hp"] = hp
			unit["max_hp"] = max(hp, int(unit.get("max_hp", hp)))
			unit["def"] = 0
			unit["shield"] = 0
			picked_id = String(unit.get("id", ""))
		else:
			unit["hp"] = 0
	return picked_id

func _place_two_enemies(state: StateScript, x1: int, y1: int, x2: int, y2: int, hp: int) -> Array:
	# Legacy mechanic fixtures isolate stable targets; reset behavior has its own smoke.
	state.pet_reset_charges[StateScript.ENEMY] = 0
	state.pet_reset_next_charge_round[StateScript.ENEMY] = 999
	var ids: Array = []
	for unit in state.units:
		if String(unit.get("side", "")) != StateScript.ENEMY:
			continue
		if ids.size() == 0:
			unit["x"] = x1
			unit["y"] = y1
			unit["hp"] = hp
			unit["max_hp"] = max(hp, int(unit.get("max_hp", hp)))
			unit["def"] = 0
			unit["shield"] = 0
			ids.append(String(unit.get("id", "")))
		elif ids.size() == 1:
			unit["x"] = x2
			unit["y"] = y2
			unit["hp"] = hp
			unit["max_hp"] = max(hp, int(unit.get("max_hp", hp)))
			unit["def"] = 0
			unit["shield"] = 0
			ids.append(String(unit.get("id", "")))
		else:
			unit["hp"] = 0
	return ids

func _prepare_enemy_targets(state: StateScript, cells: Array, hp: int) -> Array:
	var existing: Array = []
	var template: Dictionary = {}
	for unit in state.units:
		if String(Dictionary(unit).get("side", "")) != StateScript.ENEMY:
			continue
		existing.append(unit)
		if template.is_empty():
			template = Dictionary(unit).duplicate(true)
	if template.is_empty():
		template = {
			"id": "enemy_fixture_template",
			"name": "测试敌人",
			"side": StateScript.ENEMY,
			"element": "火",
			"max_hp": hp,
			"hp": hp,
			"atk": 1,
			"def": 0,
			"shield": 0,
			"x": 0,
			"y": 0
		}
	var ids: Array = []
	for index in range(cells.size()):
		var cell := Dictionary(cells[index])
		var unit: Dictionary
		if index < existing.size():
			unit = Dictionary(existing[index])
		else:
			unit = template.duplicate(true)
			unit["id"] = "enemy_fixture_%d_%d" % [state.units.size(), index]
			unit["name"] = "测试敌人%d" % (index + 1)
			state.units.append(unit)
		unit["side"] = StateScript.ENEMY
		unit["x"] = int(cell.get("x", 0))
		unit["y"] = int(cell.get("y", 0))
		unit["hp"] = hp
		unit["max_hp"] = max(hp, int(unit.get("max_hp", hp)))
		unit["def"] = 0
		unit["shield"] = 0
		ids.append(String(unit.get("id", "")))
	for index in range(cells.size(), existing.size()):
		Dictionary(existing[index])["hp"] = 0
	return ids

func _log_contains(lines: Array, needle: String) -> bool:
	for line in lines:
		if String(line).contains(needle):
			return true
	return false

func _contains_all_strings(actual: Array, expected: Array) -> bool:
	var actual_set := {}
	for item in actual:
		actual_set[String(item)] = true
	for item in expected:
		if not actual_set.has(String(item)):
			return false
	return true

func _string_array_intersection(first: Array, second: Array) -> Array:
	var second_set := {}
	for item in second:
		second_set[String(item)] = true
	var out: Array = []
	for item in first:
		var key := String(item)
		if second_set.has(key):
			out.append(key)
	return out

func _has_unit_named(units: Array, name: String) -> bool:
	for unit in units:
		if typeof(unit) == TYPE_DICTIONARY and String(Dictionary(unit).get("name", "")) == name:
			return true
	return false

func _board_has_element_layer(snapshot: Dictionary, element: String, min_layers: int) -> bool:
	for cell in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		if typeof(cell) != TYPE_DICTIONARY:
			continue
		var elements := Dictionary(Dictionary(cell).get("elements", {}))
		if int(elements.get(element, 0)) >= min_layers:
			return true
	return false

func _snapshot_cell_element(snapshot: Dictionary, x: int, y: int, element: String) -> int:
	for cell in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		if typeof(cell) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(cell)
		if int(row.get("x", -1)) == x and int(row.get("y", -1)) == y:
			return int(Dictionary(row.get("elements", {})).get(element, 0))
	return 0

func _snapshot_cell_has_trace_kind(snapshot: Dictionary, x: int, y: int, trace_kind: String) -> bool:
	for cell in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		if typeof(cell) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(cell)
		if int(row.get("x", -1)) != x or int(row.get("y", -1)) != y:
			continue
		for trace in Array(row.get("traces", [])):
			if typeof(trace) == TYPE_DICTIONARY and String(Dictionary(trace).get("kind", "")) == trace_kind:
				return true
	return false

func _log_contains_order(lines: Array, first: String, second: String) -> bool:
	for line in lines:
		var text := String(line)
		var first_index := text.find(first)
		var second_index := text.find(second)
		if first_index >= 0 and second_index >= 0 and first_index < second_index:
			return true
	return false

func _log_contains_order_across(lines: Array, first: String, second: String) -> bool:
	var first_line := -1
	for index in range(lines.size() - 1, -1, -1):
		var text := String(lines[index])
		if first_line < 0 and text.contains(first):
			first_line = index
		if first_line >= 0 and index < first_line and text.contains(second):
			return true
	return false

func _slot_by_index(slots: Array, index: int) -> Dictionary:
	for slot in slots:
		var row := Dictionary(slot)
		if int(row.get("index", -1)) == index:
			return row
	return {}

func _mechanism_row(snapshot: Dictionary, mechanism_id: String) -> Dictionary:
	for item in Array(Dictionary(snapshot.get("battle", {})).get("mechanisms", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("id", "")) == mechanism_id:
			return row
	return {}
