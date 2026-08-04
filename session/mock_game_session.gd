extends "res://session/game_session.gd"
class_name MockGameSession

## Offline replay of public snapshots captured from the production
## LocalGameSession. This project does not calculate combat outcomes.

signal snapshot_changed(snapshot: Dictionary, event: Dictionary)

const CAPTURE_PATH := "res://data/mock_battle_snapshot.json"
const DEFAULT_SKILLS := [
	{"id": "skill_vanguard", "name": "先锋击"},
	{"id": "skill_flank", "name": "侧翼击"},
]
const DEFAULT_COMBOS := [
	{"id": "combo_pincer", "name": "前后夹击", "skills": ["skill_vanguard", "skill_flank"]},
]
const START_PHASE_ROUTE := "route"
const START_PHASE_BATTLE := "battle"

var _capture_source: Dictionary = {}
var _presentation_bootstrap_snapshot: Dictionary = {}
var _battle_bootstrap_snapshot: Dictionary = {}
var _snapshot: Dictionary = {}
var _steps: Array = []
var _step_index := 0
var _skill_control_order: Array = []
var _skill_control_units: Array = []
var _captured_target_preview_templates: Dictionary = {}
var _captured_incoming_preview_template: Dictionary = {}
var _incoming_projection_unit_ids: Dictionary = {}
var _projected_incoming_previews: Dictionary = {}
var _start_phase := START_PHASE_ROUTE


func _init(options: Dictionary = {}) -> void:
	_start_phase = _normalized_start_phase(String(options.get("start_phase", START_PHASE_ROUTE)))
	reset(false)
	_publish_initial_snapshot_after_ui_ready()


func get_authority() -> RefCounted:
	return null


func connect_session() -> bool:
	return not _snapshot.is_empty()


func is_session_connected() -> bool:
	return not _snapshot.is_empty()


func current_snapshot() -> Dictionary:
	if _snapshot.is_empty():
		reset(false)
	return _snapshot.duplicate(true)


func capture_source() -> Dictionary:
	return _capture_source.duplicate(true)


func presentation_bootstrap_snapshot() -> Dictionary:
	return _presentation_bootstrap_snapshot.duplicate(true)


func replay_step_count() -> int:
	return _steps.size()


func replay_step_index() -> int:
	return _step_index


func submit_command(command: Dictionary) -> Dictionary:
	var requested_type := String(command.get("type", "")).strip_edges().to_upper()
	var command_type := _canonical_command_type(requested_type)
	if command_type == "RESET_MOCK":
		reset(false)
		return _accepted_projection(
			command,
			command_type,
			{"type": "RESET_MOCK", "ok": true, "message": "已回到正式运行数据起点"}
		)
	if command_type == "GET_CELL_DETAIL":
		_clear_captured_incoming_preview_projection()
		return _accepted_projection(
			command,
			command_type,
			_projection_result(command_type, command)
		)
	if command_type == "SELECT_UNIT":
		return _accepted_projection(
			command,
			command_type,
			_projection_result(command_type, command)
		)
	if command_type == "SET_SKILL_CONTROL_ORDER":
		return _accepted_projection(command, command_type, _set_skill_control_order(command))
	if command_type == "SELECT_CELL":
		var selection := _projection_result(command_type, command)
		if bool(selection.get("ok", false)):
			return _accepted_projection(command, command_type, selection)
		return _rejected_response(
			command,
			command_type,
			"CELL_NOT_SELECTABLE",
			"该格没有可选择的我方单位"
		)
	if command_type == "SET_ACTION_DIRECTION":
		return _project_action_direction(command)
	if command_type == "MOVE_HERO":
		return _accepted_projection(command, command_type, _project_move_hero(command))
	return _replay_captured_command(command, command_type)


func submit_command_and_wait(command: Dictionary) -> Dictionary:
	return submit_command(command)


func persistence_slot_count() -> int:
	# Preserve the production RunTools geometry without enabling persistence.
	# The standalone Mock still cannot read or write formal-project saves.
	return 3


func reset(emit_change: bool = true) -> void:
	var file := FileAccess.open(CAPTURE_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open production battle capture: %s" % CAPTURE_PATH)
		_snapshot = {}
		_steps = []
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Production battle capture is not a JSON object: %s" % CAPTURE_PATH)
		_snapshot = {}
		_steps = []
		return
	var capture := Dictionary(parsed)
	if int(capture.get("capture_schema_version", 0)) != 1:
		push_error("Unsupported production battle capture schema")
		_snapshot = {}
		_steps = []
		return
	_capture_source = Dictionary(capture.get("source", {})).duplicate(true)
	_presentation_bootstrap_snapshot = Dictionary(
		capture.get("presentation_bootstrap_snapshot", {})
	).duplicate(true)
	_battle_bootstrap_snapshot = Dictionary(capture.get("initial_snapshot", {})).duplicate(true)
	if _start_phase == START_PHASE_BATTLE or _presentation_bootstrap_snapshot.is_empty():
		_snapshot = _battle_bootstrap_snapshot.duplicate(true)
	else:
		_snapshot = _presentation_bootstrap_snapshot.duplicate(true)
	_skill_control_order = []
	_skill_control_units = []
	for unit_value in Array(_battle_bootstrap_snapshot.get("units", [])):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != "player":
			continue
		_skill_control_units.append({
			"id": String(unit.get("id", unit.get("unitId", ""))),
			"name": String(unit.get("name", unit.get("id", "宠物"))),
		})
		if _skill_control_units.size() >= 4:
			break
	_incoming_projection_unit_ids = {}
	_projected_incoming_previews = {}
	_captured_target_preview_templates = _collect_damage_preview_templates(capture)
	_captured_incoming_preview_template = _collect_incoming_damage_preview_template(capture)
	_ensure_captured_target_preview_projection()
	_ensure_action_block_ranges_projection()
	_ensure_skill_control_projection()
	_steps = Array(capture.get("steps", [])).duplicate(true)
	_step_index = 0
	if emit_change:
		_emit_snapshot(
			{"type": "RESET_MOCK", "ok": true, "message": "已重新载入正式运行数据"},
			"reset"
		)


func _publish_initial_snapshot_after_ui_ready() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	_emit_snapshot(
		{"type": "CAPTURE_READY", "ok": true, "message": "正式战斗运行数据已就绪"},
		"capture_ready"
	)


func _canonical_command_type(command_type: String) -> String:
	match command_type:
		"AUTO_POSITION":
			return "AUTO_POSITION_HEROES"
		"RUN_PLAYER_ALL_OUT", "END_PLAYER_TURN", "RUN_MONSTER_TURN", "RUN_BATTLE":
			return "RUN_COMBAT_ROUND"
	return command_type


func _normalized_start_phase(value: String) -> String:
	var phase := value.strip_edges().to_lower()
	if phase == START_PHASE_BATTLE:
		return START_PHASE_BATTLE
	return START_PHASE_ROUTE


func _replay_captured_command(command: Dictionary, command_type: String) -> Dictionary:
	_skip_auto_position_before_round(command_type)
	if _step_index >= _steps.size():
		if command_type == "DROP_ITEM_ON_TARGET":
			return _accepted_projection(command, command_type, _apply_local_drop_command(command, command_type))
		return _accepted_projection(
			command,
			command_type,
			_noop_result(command_type, "正式项目的双按钮循环数据已经回放完毕，Mock 已忽略本次操作")
		)
	var record := Dictionary(_steps[_step_index])
	var expected_command := String(Dictionary(record.get("command", {})).get("type", "")).to_upper()
	if command_type != expected_command:
		if command_type == "DROP_ITEM_ON_TARGET":
			return _accepted_projection(command, command_type, _apply_local_drop_command(command, command_type))
		return _accepted_projection(
			command,
			command_type,
			_noop_result(command_type, "该 UI 操作不在正式录制回放序列中，Mock 已忽略顺序限制")
		)
	return _apply_captured_record(command, command_type, record, true)


func _apply_captured_record(
	command: Dictionary,
	command_type: String,
	record: Dictionary,
	emit_change: bool
) -> Dictionary:
	_apply_snapshot_delta(Dictionary(record.get("snapshot_delta", {})))
	var identity := Dictionary(record.get("snapshot_identity", {}))
	if int(_snapshot.get("stateVersion", -1)) != int(identity.get("stateVersion", -2)) \
			or String(_snapshot.get("stateHash", "")) != String(identity.get("stateHash", "")):
		return _rejected_response(
			command,
			command_type,
			"CAPTURE_IDENTITY_MISMATCH",
			"正式 Snapshot 增量校验失败"
		)
	_step_index += 1

	var response := Dictionary(record.get("response", {})).duplicate(true)
	response["command"] = command_type
	response["snapshot"] = current_snapshot()
	response["captureStep"] = _step_index
	command_completed.emit(command.duplicate(true), response.duplicate(true))
	command_settled.emit(response.duplicate(true))
	if emit_change:
		_emit_snapshot(
			Dictionary(response.get("result", {})),
			"formal_capture_replay",
			command_type
		)
	return response


func _skip_auto_position_before_round(command_type: String) -> void:
	if command_type != "RUN_COMBAT_ROUND":
		return
	if _step_index >= _steps.size():
		return
	var record := Dictionary(_steps[_step_index])
	var expected_command := String(Dictionary(record.get("command", {})).get("type", "")).to_upper()
	if expected_command == "AUTO_POSITION_HEROES":
		_apply_captured_record({"type": "AUTO_POSITION_HEROES"}, expected_command, record, false)


func _noop_result(command_type: String, message: String) -> Dictionary:
	return {
		"type": command_type,
		"ok": true,
		"mock_noop": true,
		"message": message,
	}


func _project_move_hero(command: Dictionary) -> Dictionary:
	# The authored battle surface has already resolved its visible drop target.
	# The standalone Mock only mirrors that semantic command into its public
	# Snapshot so Game can round-trip the view; formal legality remains owned by
	# LocalGameSession/YsbzsState and is intentionally not reimplemented here.
	var unit_id := String(command.get("unitId", command.get("unit_id", ""))).strip_edges()
	var target_x := int(command.get("x", Dictionary(command.get("cell", {})).get("x", -1)))
	var target_y := int(command.get("y", Dictionary(command.get("cell", {})).get("y", -1)))
	var board := Dictionary(_snapshot.get("board", {})).duplicate(true)
	var cells := Array(board.get("cells", [])).duplicate(true)
	var source_index := -1
	var target_index := -1
	for index in range(cells.size()):
		var cell := Dictionary(cells[index])
		if String(cell.get("unitId", cell.get("unit_id", ""))) == unit_id:
			source_index = index
		if int(cell.get("x", cell.get("c", -1))) == target_x \
				and int(cell.get("y", cell.get("r", -1))) == target_y:
			target_index = index
	if source_index < 0 or target_index < 0 or source_index == target_index:
		return _noop_result("MOVE_HERO", "Mock 没找到可投影的拖拽起点或终点")
	var source_cell := Dictionary(cells[source_index]).duplicate(true)
	var target_cell := Dictionary(cells[target_index]).duplicate(true)
	if String(target_cell.get("unitId", target_cell.get("unit_id", ""))) != "":
		return _noop_result("MOVE_HERO", "Mock 拖拽终点已有单位，保持正式 Snapshot")
	var moved_cell := source_cell.duplicate(true)
	_copy_cell_location(moved_cell, target_cell)
	var emptied_source := target_cell.duplicate(true)
	_copy_cell_location(emptied_source, source_cell)
	cells[source_index] = emptied_source
	cells[target_index] = moved_cell
	board["cells"] = cells
	_snapshot["board"] = board
	_project_unit_coordinates(unit_id, target_x, target_y)
	_incoming_projection_unit_ids[unit_id] = true
	_ensure_captured_target_preview_projection()
	_ensure_captured_incoming_preview_for_unit(unit_id)
	var next_version := int(_snapshot.get("stateVersion", 0)) + 1
	_snapshot["stateVersion"] = next_version
	_snapshot["state_version"] = next_version
	_snapshot["stateHash"] = "mock_move_%d" % next_version
	_snapshot["state_hash"] = _snapshot["stateHash"]
	_snapshot = _snapshot.duplicate(true)
	return {
		"type": "MOVE_HERO",
		"ok": true,
		"mock_local_projection": true,
		"unitId": unit_id,
		"x": target_x,
		"y": target_y,
		"message": "Mock 已按公开命令更新拖拽展示坐标",
	}


func _copy_cell_location(destination: Dictionary, source: Dictionary) -> void:
	for key in ["x", "y", "r", "c", "key", "elements", "trace", "traces"]:
		if source.has(key):
			destination[key] = source[key].duplicate(true) if source[key] is Dictionary or source[key] is Array else source[key]
		else:
			destination.erase(key)


func _project_unit_coordinates(unit_id: String, target_x: int, target_y: int) -> void:
	var units := Array(_snapshot.get("units", [])).duplicate(true)
	for index in range(units.size()):
		var unit := Dictionary(units[index]).duplicate(true)
		if String(unit.get("id", unit.get("unitId", ""))) != unit_id:
			continue
		unit["x"] = target_x
		unit["y"] = target_y
		unit["c"] = target_x
		unit["r"] = target_y
		units[index] = unit
		break
	_snapshot["units"] = units
	var view_model := Dictionary(_snapshot.get("viewModel", {})).duplicate(true)
	if not view_model.is_empty():
		view_model["units"] = units.duplicate(true)
		view_model["board"] = Dictionary(_snapshot.get("board", {})).duplicate(true)
		view_model["stateVersion"] = int(_snapshot.get("stateVersion", 0)) + 1
		view_model["stateHash"] = "mock_move_%d" % int(view_model["stateVersion"])
		_snapshot["viewModel"] = view_model


func _apply_local_drop_command(command: Dictionary, command_type: String) -> Dictionary:
	var source_type := String(command.get("source_type", "")).strip_edges()
	var source_index := int(command.get("source_index", -1))
	var target_type := String(command.get("target_type", "")).strip_edges()
	var target_index := int(command.get("target_index", -1))
	var roster := Array(_snapshot.get("roster", [])).duplicate(true)
	var source_roster_index := _roster_index_for_drop_source(roster, source_type, source_index, command)
	var source_offer_id := ""
	if source_roster_index < 0 and source_type == "shop":
		var offer := _shop_offer_for_drop_source(source_index, command)
		if not offer.is_empty():
			source_offer_id = String(offer.get("id", command.get("offer_id", "")))
			offer["active"] = false
			offer["slot"] = 0
			offer["bag_slot"] = _first_free_bag_slot(roster)
			roster.append(offer)
			source_roster_index = roster.size() - 1
	if source_roster_index < 0:
		return _noop_result(command_type, "Mock 没找到可移动的精灵，已忽略本次拖拽")
	if target_type == "sell":
		roster.remove_at(source_roster_index)
		_commit_local_roster(roster)
		return {
			"type": command_type,
			"ok": true,
			"mock_local_projection": true,
			"message": "Mock 已本地移除出售精灵",
		}
	var source_record := Dictionary(roster[source_roster_index])
	var source_was_active := bool(source_record.get("active", false))
	var source_party_slot := int(source_record.get("slot", 0))
	var source_bag_slot := int(source_record.get("bag_slot", source_record.get("bagSlot", source_index)))
	var occupant_index := -1
	if target_type == "party":
		var party_slot := target_index + 1
		if party_slot <= 0:
			party_slot = _first_free_party_slot(roster)
		occupant_index = _active_roster_index_at_party_slot(roster, party_slot, source_roster_index)
		source_record["active"] = true
		source_record["slot"] = party_slot
	elif target_type == "bag":
		var bag_slot := target_index if target_index >= 0 else _first_free_bag_slot(roster, source_roster_index)
		occupant_index = _inactive_roster_index_at_bag_slot(roster, bag_slot, source_roster_index)
		source_record["active"] = false
		source_record["bag_slot"] = bag_slot
	else:
		return _noop_result(command_type, "Mock 暂不处理该拖拽目标，已忽略本次操作")
	roster[source_roster_index] = source_record
	if occupant_index >= 0:
		var occupant := Dictionary(roster[occupant_index])
		if source_was_active:
			occupant["active"] = true
			occupant["slot"] = source_party_slot
		else:
			occupant["active"] = false
			occupant["bag_slot"] = source_bag_slot
		roster[occupant_index] = occupant
	if source_offer_id != "":
		_remove_shop_offer(source_offer_id)
	_commit_local_roster(roster)
	return {
		"type": command_type,
		"ok": true,
		"mock_local_projection": true,
		"message": "Mock 已本地更新队伍和背包位置",
	}


func _commit_local_roster(roster: Array) -> void:
	_snapshot["roster"] = roster
	var next_version := int(_snapshot.get("stateVersion", 0)) + 1
	_snapshot["stateVersion"] = next_version
	_snapshot["stateHash"] = "mock_local_%d" % next_version
	_snapshot = _snapshot.duplicate(true)


func _roster_index_for_drop_source(
	roster: Array,
	source_type: String,
	source_index: int,
	command: Dictionary
) -> int:
	var unit_id := _command_record_ref(command)
	if unit_id != "":
		for index in range(roster.size()):
			if _record_ref(Dictionary(roster[index])) == unit_id:
				return index
	match source_type:
		"party":
			return _active_roster_index_at_party_slot(roster, source_index + 1)
		"bag":
			var inactive_indices := _inactive_roster_indices_sorted(roster)
			if source_index >= 0 and source_index < inactive_indices.size():
				return int(Dictionary(inactive_indices[source_index]).get("roster_index", -1))
	return -1


func _active_roster_index_at_party_slot(roster: Array, party_slot: int, ignored_index: int = -1) -> int:
	for index in range(roster.size()):
		if index == ignored_index:
			continue
		var pet := Dictionary(roster[index])
		if bool(pet.get("active", false)) and int(pet.get("slot", 0)) == party_slot:
			return index
	return -1


func _inactive_roster_index_at_bag_slot(roster: Array, bag_slot: int, ignored_index: int = -1) -> int:
	for index in range(roster.size()):
		if index == ignored_index:
			continue
		var pet := Dictionary(roster[index])
		if not bool(pet.get("active", false)) \
				and int(pet.get("bag_slot", pet.get("bagSlot", -1))) == bag_slot:
			return index
	return -1


func _inactive_roster_indices_sorted(roster: Array) -> Array:
	var inactive_indices := []
	for index in range(roster.size()):
		var pet := Dictionary(roster[index])
		if bool(pet.get("active", false)):
			continue
		inactive_indices.append({
			"roster_index": index,
			"bag_slot": int(pet.get("bag_slot", pet.get("bagSlot", 999))),
		})
	inactive_indices.sort_custom(func(left, right):
		return int(Dictionary(left).get("bag_slot", 999)) < int(Dictionary(right).get("bag_slot", 999))
	)
	return inactive_indices


func _first_free_party_slot(roster: Array) -> int:
	for slot in range(1, 5):
		if _active_roster_index_at_party_slot(roster, slot) < 0:
			return slot
	return 1


func _first_free_bag_slot(roster: Array, ignored_index: int = -1) -> int:
	for slot in range(0, 64):
		if _inactive_roster_index_at_bag_slot(roster, slot, ignored_index) < 0:
			return slot
	return 0


func _shop_offer_for_drop_source(source_index: int, command: Dictionary) -> Dictionary:
	var offer_id := String(command.get("offer_id", "")).strip_edges()
	var offers := Array(_snapshot.get("shop_offers", []))
	if offer_id != "":
		for value in offers:
			var offer := Dictionary(value)
			if String(offer.get("id", "")) == offer_id:
				return offer.duplicate(true)
	if source_index >= 0 and source_index < offers.size():
		return Dictionary(offers[source_index]).duplicate(true)
	return {}


func _remove_shop_offer(offer_id: String) -> void:
	if offer_id == "":
		return
	var offers := []
	for value in Array(_snapshot.get("shop_offers", [])):
		var offer := Dictionary(value)
		if String(offer.get("id", "")) != offer_id:
			offers.append(offer)
	_snapshot["shop_offers"] = offers


func _command_record_ref(command: Dictionary) -> String:
	for key in ["unitId", "unit_id", "id", "pet_id", "petId", "instance_id", "instanceId"]:
		var value := String(command.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func _record_ref(record: Dictionary) -> String:
	for key in ["id", "unitId", "unit_id", "pet_id", "petId", "instance_id", "instanceId"]:
		var value := String(record.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func _apply_snapshot_delta(delta: Dictionary) -> void:
	for key_value in Array(delta.get("remove", [])):
		_snapshot.erase(String(key_value))
	for key_value in Dictionary(delta.get("set", {})).keys():
		var key := String(key_value)
		_snapshot[key] = Dictionary(delta.get("set", {}))[key_value]
	_snapshot = _snapshot.duplicate(true)
	_ensure_captured_target_preview_projection()
	_ensure_tracked_incoming_preview_projection()
	_ensure_action_block_ranges_projection()
	_ensure_skill_control_projection()


func _ensure_action_block_ranges_projection() -> void:
	var previews := Dictionary(_snapshot.get("action_preview_by_unit", {}))
	var ranges_by_unit := {}
	for unit_id_value in previews.keys():
		var unit_id := String(unit_id_value)
		var preview := Dictionary(previews[unit_id_value])
		var ranges: Array[Dictionary] = []
		for slot_index in range(3):
			ranges.append({
				"slotIndex": slot_index,
				"origin": Dictionary(preview.get("origin", {})).duplicate(true),
				"direction": String(preview.get("direction", "")),
				"available": bool(preview.get("available", true)),
				"cells": Array(preview.get("cells", [])).duplicate(true),
			})
		ranges_by_unit[unit_id] = ranges
	_snapshot["action_block_ranges_by_unit"] = ranges_by_unit


func _ensure_skill_control_projection() -> void:
	var entries_by_id := {}
	var default_order: Array = []
	for unit_value in _skill_control_units:
		var unit := Dictionary(unit_value)
		var unit_id := String(unit.get("id", ""))
		for slot_index in range(DEFAULT_SKILLS.size()):
			var skill := Dictionary(DEFAULT_SKILLS[slot_index])
			var skill_slot := "a" if slot_index == 0 else "b"
			var entry_id := "%s:%s" % [unit_id, skill_slot]
			entries_by_id[entry_id] = {
				"entryId": entry_id,
				"unitId": unit_id,
				"unitName": String(unit.get("name", unit_id)),
				"skillSlot": skill_slot,
				"skillId": String(skill.get("id", "")),
				"label": String(skill.get("name", "")),
			}
			default_order.append(entry_id)
	var order := _skill_control_order.duplicate()
	for entry_id in default_order:
		if not order.has(entry_id):
			order.append(entry_id)
	var entries: Array = []
	for index in range(order.size()):
		if not entries_by_id.has(order[index]):
			continue
		var entry := Dictionary(entries_by_id[order[index]]).duplicate(true)
		entry["orderIndex"] = entries.size()
		entries.append(entry)
	_snapshot["skill_control_bar"] = entries
	_snapshot["skillControlBar"] = entries.duplicate(true)
	var traits := [_mock_trait_for_selected_unit()]
	var combos := _mock_combos_for_order(_skill_ids_for_entries(entries))
	_snapshot["selected_traits"] = traits
	_snapshot["selectedTraits"] = traits.duplicate(true)
	_snapshot["selected_skill_combos"] = combos
	_snapshot["selectedSkillCombos"] = combos.duplicate(true)


func _set_skill_control_order(command: Dictionary) -> Dictionary:
	var requested := Array(command.get("orderedEntryIds", command.get("ordered_entry_ids", [])))
	var current := _default_skill_control_entry_ids() if _skill_control_order.is_empty() else _skill_control_order
	if requested.size() != current.size():
		return {"type": "SET_SKILL_CONTROL_ORDER", "ok": false, "message": "技能控制条必须包含全部8个宠物 A/B 格"}
	for entry_id in current:
		if requested.count(entry_id) != 1:
			return {"type": "SET_SKILL_CONTROL_ORDER", "ok": false, "message": "技能控制条包含重复或缺失格"}
	_skill_control_order = requested.duplicate()
	_ensure_skill_control_projection()
	return {"type": "SET_SKILL_CONTROL_ORDER", "ok": true, "skillControlBar": Array(_snapshot["skillControlBar"]).duplicate(true)}


func _default_skill_control_entry_ids() -> Array:
	var result: Array = []
	for unit_value in _skill_control_units:
		var unit_id := String(Dictionary(unit_value).get("id", ""))
		result.append("%s:a" % unit_id)
		result.append("%s:b" % unit_id)
	return result


func _skill_ids_for_entries(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		result.append(String(Dictionary(entry_value).get("skillId", "")))
	return result


func _default_skill_ids() -> Array:
	var result: Array = []
	for definition in DEFAULT_SKILLS:
		result.append(String(Dictionary(definition).get("id", "")))
	return result


func _skill_name(skill_id: String) -> String:
	for definition in DEFAULT_SKILLS:
		var row := Dictionary(definition)
		if String(row.get("id", "")) == skill_id:
			return String(row.get("name", skill_id))
	return skill_id


func _mock_trait_for_selected_unit() -> Dictionary:
	var unit := _unit_by_id(String(_snapshot.get("selected_unit_id", _snapshot.get("selectedUnitId", ""))))
	var role := String(unit.get("role", ""))
	if role.contains("输出") or role.contains("机动"):
		return {"id": "trait_relentless", "name": "猛攻本能"}
	if role.contains("治疗") or role.contains("控制"):
		return {"id": "trait_element_affinity", "name": "元素亲和"}
	if role.contains("坦克") or role.contains("防御") or role.contains("抗压"):
		return {"id": "trait_combo_mastery", "name": "连携精通"}
	return {"id": "trait_combo_resonance", "name": "连携共鸣"}


func _mock_combos_for_order(order: Array) -> Array:
	var result: Array = []
	for combo_value in DEFAULT_COMBOS:
		var combo := Dictionary(combo_value)
		var pattern := Array(combo.get("skills", []))
		for index in range(max(0, order.size() - pattern.size() + 1)):
			if order.slice(index, index + pattern.size()) != pattern:
				continue
			var entry := combo.duplicate(true)
			entry["start_index"] = index
			entry["end_index"] = index + pattern.size() - 1
			entry["matched_skill_ids"] = pattern.duplicate()
			result.append(entry)
			break
	return result


func _accepted_projection(
	command: Dictionary,
	command_type: String,
	result: Dictionary
) -> Dictionary:
	var response := {
		"accepted": true,
		"pending": false,
		"status": "completed",
		"ok": true,
		"command": command_type,
		"result": result.duplicate(true),
		"snapshot": current_snapshot(),
		"stateVersion": int(_snapshot.get("stateVersion", -1)),
		"stateHash": String(_snapshot.get("stateHash", "")),
	}
	command_completed.emit(command.duplicate(true), response.duplicate(true))
	command_settled.emit(response.duplicate(true))
	snapshot_received.emit(current_snapshot(), {
		"asynchronous": false,
		"source": "formal_snapshot_projection",
		"command": command_type,
	})
	snapshot_changed.emit(current_snapshot(), result.duplicate(true))
	return response


func _project_action_direction(command: Dictionary) -> Dictionary:
	var unit_id := String(command.get("unitId", command.get("unit_id", "")))
	var slot_index := int(command.get("slotId", command.get("slot_id", -1)))
	var direction := String(command.get("dir", command.get("direction", ""))).to_lower()
	if _unit_by_id(unit_id).is_empty() or slot_index < 0 or slot_index >= 3 \
			or direction not in ["up", "right", "down", "left"]:
		return _rejected_response(
			command,
			"SET_ACTION_DIRECTION",
			"INVALID_DIRECTION_PREVIEW",
			"攻击方向预览参数无效"
		)
	var action_dirs := Dictionary(_snapshot.get("action_dirs", _snapshot.get("actionDirs", {}))).duplicate(true)
	action_dirs["%s:slot%d" % [unit_id, slot_index]] = direction
	_snapshot["action_dirs"] = action_dirs
	return _accepted_projection(command, "SET_ACTION_DIRECTION", {
		"type": "SET_ACTION_DIRECTION",
		"ok": true,
		"unitId": unit_id,
		"slotId": slot_index,
		"dir": direction,
		"previewOnly": true,
	})


func _ensure_captured_target_preview_projection() -> void:
	if _captured_target_preview_templates.is_empty():
		return
	var board := Dictionary(_snapshot.get("board", {})).duplicate(true)
	var cells := Array(board.get("cells", [])).duplicate(true)
	if cells.is_empty():
		return
	var actor_ids := PackedStringArray(_captured_target_preview_templates.keys())
	actor_ids.sort()
	var changed := false
	for cell_index in range(cells.size()):
		var cell := Dictionary(cells[cell_index]).duplicate(true)
		if not _cell_is_enemy_target(cell):
			continue
		var previews := Array(cell.get("previews", [])).duplicate(true)
		for actor_id in actor_ids:
			if _has_enemy_preview_for_actor(cell, previews, actor_id):
				continue
			var projected := _captured_target_preview_for_cell(
				Dictionary(_captured_target_preview_templates[actor_id]),
				cell
			)
			if projected.is_empty():
				continue
			previews.append(projected)
			changed = true
		if previews.size() != Array(cell.get("previews", [])).size():
			cell["previews"] = previews
			cells[cell_index] = cell
	if not changed:
		return
	board["cells"] = cells
	_snapshot["board"] = board


func _cell_is_enemy_target(cell: Dictionary) -> bool:
	var unit_id := String(cell.get("unitId", cell.get("unit_id", ""))).strip_edges()
	if unit_id == "":
		return false
	var side := String(cell.get("side", cell.get("unitSide", ""))).to_lower()
	return side in ["enemy", "monster", "enemy_leader", "boss"]


func _cell_is_friendly_target(cell: Dictionary) -> bool:
	var unit_id := String(cell.get("unitId", cell.get("unit_id", ""))).strip_edges()
	if unit_id == "":
		return false
	var side := String(cell.get("side", cell.get("unitSide", ""))).to_lower()
	return side in ["player", "ally", "hero_leader", "player_leader"]


func _has_enemy_preview_for_actor(cell: Dictionary, previews: Array, actor_id: String) -> bool:
	var candidates := previews.duplicate()
	for key in ["action_preview_data", "actionPreviewData", "preview"]:
		var value = cell.get(key, null)
		if value is Dictionary and not Dictionary(value).is_empty():
			candidates.append(value)
	for value in candidates:
		if not (value is Dictionary):
			continue
		var preview := Dictionary(value)
		var preview_actor := String(preview.get(
			"actorId",
			preview.get("actor_id", preview.get("unitId", preview.get("unit_id", "")))
		))
		if preview_actor != actor_id:
			continue
		if bool(preview.get("hitEnemy", preview.get("hit_enemy", false))) \
				or String(preview.get("preview_type", preview.get("previewType", ""))) \
				in ["enemy", "target"]:
			return true
	return false


func _captured_target_preview_for_cell(template: Dictionary, cell: Dictionary) -> Dictionary:
	# This is a Mock-only retargeting of a captured public result. It clamps the
	# already-captured final damage to exported target stats; it does not read
	# attack, element, resistance, content or any formal combat service.
	var captured_damage := maxi(0, int(template.get(
		"predictedDamage",
		template.get("predicted_damage", 0)
	)))
	if captured_damage <= 0:
		return {}
	var current_hp := maxi(0, int(cell.get("hp", 0)))
	var current_shield := maxi(0, int(cell.get("shield", 0)))
	var shield_damage := mini(current_shield, captured_damage)
	var hp_damage := mini(current_hp, maxi(0, captured_damage - shield_damage))
	var projected_damage := shield_damage + hp_damage
	if projected_damage <= 0:
		return {}
	var target_id := String(cell.get("unitId", cell.get("unit_id", "")))
	var x := int(cell.get("x", cell.get("c", -1)))
	var y := int(cell.get("y", cell.get("r", -1)))
	var projected := template.duplicate(true)
	projected["x"] = x
	projected["y"] = y
	projected["c"] = x
	projected["r"] = y
	projected["targetId"] = target_id
	projected["target_unit_id"] = target_id
	projected["hitEnemy"] = true
	projected["hitAlly"] = false
	projected["preview_type"] = "target"
	projected["predictedDamage"] = projected_damage
	projected["predictedShieldDamage"] = shield_damage
	projected["predictedHpDamage"] = hp_damage
	projected["predictedShieldFrom"] = current_shield
	projected["predictedShieldTo"] = current_shield - shield_damage
	projected["predictedHpFrom"] = current_hp
	projected["predictedHpTo"] = current_hp - hp_damage
	return projected


func _ensure_tracked_incoming_preview_projection() -> void:
	var unit_ids := PackedStringArray(_incoming_projection_unit_ids.keys())
	unit_ids.sort()
	for unit_id in unit_ids:
		_ensure_captured_incoming_preview_for_unit(unit_id)


func _ensure_captured_incoming_preview_for_unit(unit_id: String) -> void:
	if unit_id == "" or _captured_incoming_preview_template.is_empty():
		return
	var cell := _board_cell_for_unit(unit_id)
	if cell.is_empty() or not _cell_is_friendly_target(cell):
		return
	var by_unit := Dictionary(_snapshot.get(
		"placement_damage_by_unit",
		_snapshot.get("placementDamageByUnit", {})
	)).duplicate(true)
	if by_unit.has(unit_id) and by_unit[unit_id] is Dictionary \
			and not Dictionary(by_unit[unit_id]).is_empty():
		return
	var projected := _captured_incoming_preview_for_cell(
		_captured_incoming_preview_template,
		cell
	)
	if projected.is_empty():
		return
	by_unit[unit_id] = projected
	_projected_incoming_previews[unit_id] = projected.duplicate(true)
	_snapshot["placement_damage_by_unit"] = by_unit
	_snapshot["placementDamageByUnit"] = by_unit.duplicate(true)


func _clear_captured_incoming_preview_projection() -> void:
	if _projected_incoming_previews.is_empty():
		_incoming_projection_unit_ids.clear()
		return
	var by_unit := Dictionary(_snapshot.get(
		"placement_damage_by_unit",
		_snapshot.get("placementDamageByUnit", {})
	)).duplicate(true)
	for unit_id_value in _projected_incoming_previews.keys():
		var unit_id := String(unit_id_value)
		var current = by_unit.get(unit_id, null)
		if current is Dictionary \
				and Dictionary(current) == Dictionary(_projected_incoming_previews[unit_id_value]):
			by_unit.erase(unit_id)
	_snapshot["placement_damage_by_unit"] = by_unit
	_snapshot["placementDamageByUnit"] = by_unit.duplicate(true)
	_incoming_projection_unit_ids.clear()
	_projected_incoming_previews.clear()


func _captured_incoming_preview_for_cell(template: Dictionary, cell: Dictionary) -> Dictionary:
	# As above, only a captured public total is clamped to exported presentation
	# stats. No formal damage formula or legality decision is reproduced here.
	var captured_damage := maxi(0, int(template.get(
		"totalDamage",
		template.get("damage", template.get("threat", 0))
	)))
	if captured_damage <= 0:
		return {}
	var current_hp := maxi(0, int(cell.get("hp", 0)))
	var current_shield := maxi(0, int(cell.get("shield", 0)))
	var shield_damage := mini(current_shield, captured_damage)
	var hp_damage := mini(current_hp, maxi(0, captured_damage - shield_damage))
	var projected_damage := shield_damage + hp_damage
	if projected_damage <= 0:
		return {}
	var projected := template.duplicate(true)
	projected["unitId"] = String(cell.get("unitId", cell.get("unit_id", "")))
	projected["totalDamage"] = projected_damage
	projected["damage"] = projected_damage
	projected["shieldDamage"] = shield_damage
	projected["hpDamage"] = hp_damage
	projected["shieldFrom"] = current_shield
	projected["shieldTo"] = current_shield - shield_damage
	projected["hpFrom"] = current_hp
	projected["hpTo"] = current_hp - hp_damage
	return projected


func _board_cell_for_unit(unit_id: String) -> Dictionary:
	for value in Array(Dictionary(_snapshot.get("board", {})).get("cells", [])):
		var cell := Dictionary(value)
		if String(cell.get("unitId", cell.get("unit_id", ""))) == unit_id:
			return cell.duplicate(true)
	return {}


func _collect_damage_preview_templates(capture: Dictionary) -> Dictionary:
	var templates := {}
	_collect_damage_preview_templates_from_snapshot(
		Dictionary(capture.get("initial_snapshot", {})),
		templates
	)
	for step_value in Array(capture.get("steps", [])):
		var step := Dictionary(step_value)
		var snapshot_set := Dictionary(Dictionary(step.get("snapshot_delta", {})).get("set", {}))
		_collect_damage_preview_templates_from_snapshot(snapshot_set, templates)
	return templates


func _collect_damage_preview_templates_from_snapshot(
	snapshot: Dictionary,
	templates: Dictionary
) -> void:
	var board := Dictionary(snapshot.get("board", {}))
	for cell_value in Array(board.get("cells", [])):
		var cell := Dictionary(cell_value)
		var candidates: Array = []
		for key in ["action_preview_data", "actionPreviewData", "preview"]:
			var candidate = cell.get(key, null)
			if candidate is Dictionary and not Dictionary(candidate).is_empty():
				candidates.append(candidate)
		for preview_value in Array(cell.get("previews", [])):
			if preview_value is Dictionary:
				candidates.append(preview_value)
		for candidate in candidates:
			var preview := Dictionary(candidate)
			if not bool(preview.get("hitEnemy", preview.get("hit_enemy", false))):
				continue
			var actor_id := String(preview.get(
				"actorId",
				preview.get("actor_id", preview.get("unitId", preview.get("unit_id", "")))
			))
			var damage := int(preview.get("predictedDamage", preview.get("predicted_damage", 0)))
			if actor_id == "" or damage <= 0:
				continue
			var existing := Dictionary(templates.get(actor_id, {}))
			var existing_damage := int(existing.get(
				"predictedDamage",
				existing.get("predicted_damage", -1)
			))
			if existing.is_empty() or damage > existing_damage:
				templates[actor_id] = preview.duplicate(true)


func _collect_incoming_damage_preview_template(capture: Dictionary) -> Dictionary:
	var friendly_unit_ids := {}
	var snapshots: Array[Dictionary] = [Dictionary(capture.get("initial_snapshot", {}))]
	for step_value in Array(capture.get("steps", [])):
		var step := Dictionary(step_value)
		snapshots.append(Dictionary(Dictionary(step.get("snapshot_delta", {})).get("set", {})))
	for snapshot in snapshots:
		var board := Dictionary(snapshot.get("board", {}))
		for cell_value in Array(board.get("cells", [])):
			var cell := Dictionary(cell_value)
			var side := String(cell.get("side", cell.get("unitSide", ""))).to_lower()
			var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
			if unit_id != "" and side in ["player", "ally"]:
				friendly_unit_ids[unit_id] = true
	var best_preview := {}
	var best_damage := -1
	for snapshot in snapshots:
		var damage_by_unit := Dictionary(snapshot.get(
			"placement_damage_by_unit",
			snapshot.get("placementDamageByUnit", {})
		))
		for unit_id_value in damage_by_unit.keys():
			var unit_id := String(unit_id_value)
			if not friendly_unit_ids.has(unit_id):
				continue
			var preview := Dictionary(damage_by_unit[unit_id_value])
			var damage := int(preview.get(
				"totalDamage",
				preview.get("damage", preview.get("threat", 0))
			))
			if damage > best_damage:
				best_damage = damage
				best_preview = preview.duplicate(true)
	return best_preview


func _rejected_response(
	command: Dictionary,
	command_type: String,
	code: String,
	message: String
) -> Dictionary:
	var response := {
		"accepted": false,
		"pending": false,
		"status": "rejected",
		"ok": false,
		"command": command_type,
		"error": {"code": code, "message": message},
		"snapshot": current_snapshot(),
		"stateVersion": int(_snapshot.get("stateVersion", -1)),
		"stateHash": String(_snapshot.get("stateHash", "")),
	}
	command_rejected.emit(command.duplicate(true), response.duplicate(true))
	command_settled.emit(response.duplicate(true))
	return response


func _projection_result(command_type: String, command: Dictionary) -> Dictionary:
	if command_type == "SELECT_UNIT":
		var unit_id := String(command.get("unit_id", command.get("unitId", "")))
		var unit := _unit_by_id(unit_id)
		if not unit.is_empty():
			_snapshot["selected_unit_id"] = unit_id
			_incoming_projection_unit_ids[unit_id] = true
			_ensure_captured_incoming_preview_for_unit(unit_id)
			_ensure_skill_control_projection()
		return {
			"type": "SELECT_UNIT",
			"ok": not unit.is_empty(),
			"unit_id": unit_id,
			"unit": unit,
		}
	var cell_arg := Dictionary(command.get("cell", {}))
	var x := int(command.get("x", command.get("c", cell_arg.get("x", cell_arg.get("c", -1)))))
	var y := int(command.get("y", command.get("r", cell_arg.get("y", cell_arg.get("r", -1)))))
	var cell := _board_cell(x, y)
	var unit := _unit_by_id(String(cell.get("unitId", cell.get("unit_id", ""))))
	if command_type == "SELECT_CELL":
		var side := String(unit.get("side", cell.get("side", "")))
		var selected_unit_id := ""
		if side in ["player", "hero", "hero_leader"]:
			selected_unit_id = String(unit.get("id", unit.get("unitId", "")))
		if selected_unit_id == "":
			return {
				"type": "SELECT_CELL",
				"ok": false,
				"x": x,
				"y": y,
				"unit_id": "",
				"unit": unit,
			}
		_snapshot["selected_unit_id"] = selected_unit_id
		if _snapshot.has("selectedUnitId"):
			_snapshot["selectedUnitId"] = selected_unit_id
		_snapshot["selected"] = {
			"unitId": selected_unit_id,
			"x": x,
			"y": y,
		}
		_incoming_projection_unit_ids[selected_unit_id] = true
		_ensure_captured_incoming_preview_for_unit(selected_unit_id)
		_ensure_skill_control_projection()
		return {
			"type": "SELECT_CELL",
			"ok": selected_unit_id != "",
			"x": x,
			"y": y,
			"unit_id": selected_unit_id,
			"unit": unit,
		}
	return {
		"type": "GET_CELL_DETAIL",
		"ok": not cell.is_empty(),
		"x": x,
		"y": y,
		"c": x,
		"r": y,
		"elements": Dictionary(cell.get("elements", {})).duplicate(true),
		"unit": unit,
	}


func _board_cell(x: int, y: int) -> Dictionary:
	var board := Dictionary(_snapshot.get("board", {}))
	for value in Array(board.get("cells", [])):
		var cell := Dictionary(value)
		if int(cell.get("x", cell.get("c", -1))) == x \
				and int(cell.get("y", cell.get("r", -1))) == y:
			return cell.duplicate(true)
	return {}


func _unit_by_id(unit_id: String) -> Dictionary:
	if unit_id == "":
		return {}
	for value in Array(_snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", unit.get("unitId", ""))) == unit_id:
			return unit.duplicate(true)
	return {}


func _emit_snapshot(
	event: Dictionary,
	source: String,
	command_type: String = ""
) -> void:
	var snapshot := current_snapshot()
	var metadata := {
		"asynchronous": false,
		"source": source,
		"command": command_type,
		"captureStep": _step_index,
	}
	snapshot_received.emit(snapshot, metadata)
	snapshot_changed.emit(snapshot, event.duplicate(true))
