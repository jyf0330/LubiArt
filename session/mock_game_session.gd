extends "res://session/game_session.gd"
class_name MockGameSession

## Offline replay of public snapshots captured from the production
## LocalGameSession. This project does not calculate combat outcomes.

signal snapshot_changed(snapshot: Dictionary, event: Dictionary)

const CAPTURE_PATH := "res://data/mock_battle_snapshot.json"
const SHOP_CAPTURE_PATH := "res://data/formal_shop_art_runtime.json"
const BoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const DEFAULT_SKILLS := [
	{"id": "skill_vanguard", "name": "先锋击"},
	{"id": "skill_flank", "name": "侧翼击"},
]
const DEFAULT_COMBOS := [
	{"id": "combo_pincer", "name": "前后夹击", "skills": ["skill_vanguard", "skill_flank"]},
]
const START_PHASE_ROUTE := "route"
const START_PHASE_SHOP := "shop"
const START_PHASE_BATTLE := "battle"
const SHOP_OFFER_COUNT := 5
const MOCK_SHOP_ROLL_POOL_SIZE := 10

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
var _legacy_insertion_row_templates: Dictionary = {}
var _legacy_element_layers_projection: Dictionary = {}
var _start_phase := START_PHASE_ROUTE
var _shop_offer_pool: Array = []
var _shop_roll_offset := 0
var _shop_art_capture: Dictionary = {}
var _shop_capture_purchase_available := false
var _shop_capture_operation_index := 0


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
			return _accepted_projection(command, command_type, selection, true)
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
	if command_type == "CHOOSE_ROUTE" and String(_snapshot.get("phase", "")) == START_PHASE_ROUTE:
		return _project_shop_entry(command)
	if command_type == "EXIT_SHOP" and String(_snapshot.get("phase", "")) == START_PHASE_SHOP:
		return _project_shop_exit(command)
	if command_type == "BUY_OFFER" and String(_snapshot.get("phase", "")) == START_PHASE_SHOP:
		return _accepted_projection(command, command_type, _apply_local_buy_command(command))
	if command_type == "DROP_ITEM_ON_TARGET" and String(_snapshot.get("phase", "")) == START_PHASE_SHOP:
		return _accepted_projection(command, command_type, _apply_local_drop_command(command, command_type))
	if command_type == "ROLL_SHOP" and String(_snapshot.get("phase", "")) == START_PHASE_SHOP:
		return _project_shop_roll(command)
	return _replay_captured_command(command, command_type)


func submit_command_and_wait(command: Dictionary) -> Dictionary:
	return submit_command(command)


func persistence_slot_count() -> int:
	# Preserve the production RunTools geometry without enabling persistence.
	# The standalone Mock still cannot read or write formal-project saves.
	return 3


func reset(emit_change: bool = true) -> void:
	_legacy_insertion_row_templates = {}
	_legacy_element_layers_projection = {}
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
	var shop_projection: Dictionary = {}
	if _start_phase != START_PHASE_BATTLE and FileAccess.file_exists(SHOP_CAPTURE_PATH):
		var shop_file := FileAccess.open(SHOP_CAPTURE_PATH, FileAccess.READ)
		var shop_parsed: Variant = JSON.parse_string(shop_file.get_as_text()) if shop_file != null else null
		if shop_parsed is Dictionary \
				and String(Dictionary(shop_parsed).get("schema", "")) == "ysbzs.shop-art-runtime-projection.v1":
			shop_projection = Dictionary(shop_parsed)
	_capture_source = Dictionary(
		shop_projection.get("presentation_source", capture.get("source", {}))
	).duplicate(true)
	_shop_art_capture = Dictionary(
		shop_projection.get("shop_art_capture", capture.get("shop_art_capture", {}))
	).duplicate(true)
	_shop_capture_purchase_available = not _shop_art_capture.is_empty()
	_shop_capture_operation_index = 0
	_presentation_bootstrap_snapshot = Dictionary(
		shop_projection.get(
			"presentation_bootstrap_snapshot",
			capture.get("presentation_bootstrap_snapshot", {})
		)
	).duplicate(true)
	_battle_bootstrap_snapshot = Dictionary(capture.get("initial_snapshot", {})).duplicate(true)
	_legacy_insertion_row_templates = _capture_legacy_insertion_row_templates(
		_battle_bootstrap_snapshot
	)
	_presentation_bootstrap_snapshot = _adapt_legacy_board_snapshot(
		_presentation_bootstrap_snapshot
	)
	_battle_bootstrap_snapshot = _adapt_legacy_board_snapshot(_battle_bootstrap_snapshot)
	var exported_shop_offers := Array(_presentation_bootstrap_snapshot.get("shop_offers", []))
	var roll_pool_size := mini(MOCK_SHOP_ROLL_POOL_SIZE, exported_shop_offers.size())
	_shop_offer_pool = exported_shop_offers.slice(0, roll_pool_size).duplicate(true)
	_shop_roll_offset = 0
	if _start_phase == START_PHASE_BATTLE or _presentation_bootstrap_snapshot.is_empty():
		_snapshot = _battle_bootstrap_snapshot.duplicate(true)
	else:
		_snapshot = _presentation_bootstrap_snapshot.duplicate(true)
		if _start_phase == START_PHASE_SHOP:
			_apply_shop_phase_from_route({})
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
	_ensure_all_friendly_incoming_preview_projection()
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
	if phase == START_PHASE_SHOP:
		return START_PHASE_SHOP
	return START_PHASE_ROUTE


func _project_shop_entry(command: Dictionary) -> Dictionary:
	var replay := _replay_next_shop_capture(command, "CHOOSE_ROUTE")
	if bool(replay.get("handled", false)):
		return Dictionary(replay.get("response", {}))
	var stall := _apply_shop_phase_from_route(command)
	if stall.is_empty():
		return _rejected_response(
			command,
			"CHOOSE_ROUTE",
			"SHOP_ROUTE_NOT_EXPORTED",
			"公开 Snapshot 中没有对应的商店路线项"
		)
	var captured_shop := _shop_capture_snapshot("shop_snapshot")
	if not captured_shop.is_empty() and _shop_capture_matches_option(command):
		_snapshot = captured_shop
		stall = Dictionary(_snapshot.get("active_stall", stall)).duplicate(true)
	else:
		_advance_artist_flow_projection("shop")
	return _accepted_projection(command, "CHOOSE_ROUTE", {
		"type": "CHOOSE_ROUTE",
		"ok": true,
		"mock_snapshot_projection": true,
		"active_stall": stall,
	})


func _apply_shop_phase_from_route(command: Dictionary) -> Dictionary:
	var requested_id := String(command.get("option_id", command.get("optionId", "")))
	var selected: Dictionary = {}
	for value in Array(_snapshot.get("route_options", [])):
		var option := Dictionary(value)
		var option_id := String(option.get("id", option.get("optionId", option.get("option_id", ""))))
		if requested_id != "" and option_id != requested_id:
			continue
		if String(option.get("kind", option.get("nodeType", ""))) != "shop":
			continue
		selected = option
		break
	if selected.is_empty():
		return {}
	var stall := Dictionary(selected.get("sourceNode", selected.get("source_node", {}))).duplicate(true)
	if stall.is_empty():
		stall = selected.duplicate(true)
	_snapshot["phase"] = START_PHASE_SHOP
	_snapshot["active_stall"] = stall
	var visible_offers := Array(_snapshot.get("shop_offers", [])).duplicate(true)
	if visible_offers.size() > SHOP_OFFER_COUNT:
		_snapshot["shop_offers"] = visible_offers.slice(0, SHOP_OFFER_COUNT)
	var pool_id := String(stall.get("shopPoolId", stall.get("shop_pool_id", "")))
	if pool_id != "":
		_snapshot["active_shop_pool"] = pool_id
	return stall


func _project_shop_exit(command: Dictionary) -> Dictionary:
	var replay := _replay_next_shop_capture(command, "EXIT_SHOP")
	if bool(replay.get("handled", false)):
		return Dictionary(replay.get("response", {}))
	var captured_exit := _shop_capture_snapshot("exit_snapshot")
	if not captured_exit.is_empty():
		_snapshot = captured_exit
		return _accepted_projection(command, "EXIT_SHOP", {
			"type": "EXIT_SHOP",
			"ok": true,
			"formal_shop_capture_replay": true,
		})
	_snapshot["phase"] = START_PHASE_ROUTE
	_snapshot["active_stall"] = {}
	_advance_artist_flow_projection("route")
	return _accepted_projection(command, "EXIT_SHOP", {
		"type": "EXIT_SHOP",
		"ok": true,
		"mock_snapshot_projection": true,
	})


func _project_shop_roll(command: Dictionary = {"type": "ROLL_SHOP"}) -> Dictionary:
	var replay := _replay_next_shop_capture(command, "ROLL_SHOP")
	if bool(replay.get("handled", false)):
		return Dictionary(replay.get("response", {}))
	var captured_refresh := _shop_capture_snapshot("refreshed_snapshot")
	if not captured_refresh.is_empty():
		_snapshot = captured_refresh
		_shop_capture_purchase_available = true
		return {
			"type": "ROLL_SHOP",
			"ok": true,
			"formal_shop_capture_replay": true,
			"offer_ids": Array(_snapshot.get("shop_offers", [])).map(
				func(value): return String(Dictionary(value).get("id", ""))
			),
			"message": "Mock 已回放正式商店刷新后的公开 Snapshot",
		}
	if _shop_offer_pool.size() <= SHOP_OFFER_COUNT:
		return _noop_result("ROLL_SHOP", "公开 Snapshot 没有足够的已映射商品用于补货")
	_shop_roll_offset = (_shop_roll_offset + SHOP_OFFER_COUNT) % _shop_offer_pool.size()
	var rolled_offers := []
	for index in range(SHOP_OFFER_COUNT):
		var pool_index := (_shop_roll_offset + index) % _shop_offer_pool.size()
		rolled_offers.append(Dictionary(_shop_offer_pool[pool_index]).duplicate(true))
	_snapshot["shop_offers"] = rolled_offers
	_advance_artist_flow_projection("shop_roll")
	return {
		"type": "ROLL_SHOP",
		"ok": true,
		"mock_snapshot_projection": true,
		"offer_ids": rolled_offers.map(func(value): return String(Dictionary(value).get("id", ""))),
		"message": "Mock 已从公开 Snapshot 的已映射商品中补货",
	}


func _advance_artist_flow_projection(label: String) -> void:
	var next_version := int(_snapshot.get("stateVersion", 0)) + 1
	_snapshot["stateVersion"] = next_version
	_snapshot["state_version"] = next_version
	_snapshot["stateHash"] = "mock_artist_flow_%s_%d" % [label, next_version]
	_snapshot["state_hash"] = _snapshot["stateHash"]


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
	var source_offer_price := 0
	if source_roster_index < 0 and source_type == "shop":
		var offer := _shop_offer_for_drop_source(source_index, command)
		if not offer.is_empty():
			source_offer_id = String(offer.get("id", command.get("offer_id", "")))
			source_offer_price = maxi(0, int(offer.get("price", 0)))
			if int(_snapshot.get("coins", 0)) < source_offer_price:
				return _noop_result(command_type, "Mock 金币不足，未购买该精灵")
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
		_snapshot["coins"] = maxi(0, int(_snapshot.get("coins", 0)) - source_offer_price)
	_commit_local_roster(roster)
	return {
		"type": command_type,
		"ok": true,
		"mock_local_projection": true,
		"message": "Mock 已本地更新队伍和背包位置",
	}


func _apply_local_buy_command(command: Dictionary) -> Dictionary:
	var replay := _replay_next_shop_capture(command, "BUY_OFFER")
	if bool(replay.get("handled", false)):
		return Dictionary(replay.get("response", {}))
	var offer_id := String(command.get("offer_id", command.get("offerId", ""))).strip_edges()
	if _shop_capture_purchase_available and _shop_capture_purchase_offer_id() == offer_id:
		var captured_purchase := _shop_capture_snapshot("purchased_snapshot")
		if not captured_purchase.is_empty():
			_snapshot = captured_purchase
			_shop_capture_purchase_available = false
			return {
				"type": "BUY_OFFER",
				"ok": true,
				"formal_shop_capture_replay": true,
				"message": "Mock 已回放正式商店购买后的公开 Snapshot",
			}
	var offers := Array(_snapshot.get("shop_offers", []))
	var source_index := -1
	for index in range(offers.size()):
		if String(Dictionary(offers[index]).get("id", "")) == offer_id:
			source_index = index
			break
	if source_index < 0:
		return _noop_result("BUY_OFFER", "Mock 没找到该商店商品，未执行购买")
	return _apply_local_drop_command({
		"source_type": "shop",
		"source_index": source_index,
		"offer_id": offer_id,
		"target_type": "bag",
		"target_index": -1,
	}, "BUY_OFFER")


func _shop_capture_snapshot(key: String) -> Dictionary:
	var replay_snapshots := Dictionary(_shop_art_capture.get("replay_snapshots", {}))
	if replay_snapshots.has(key) and replay_snapshots[key] is Dictionary:
		return Dictionary(replay_snapshots[key]).duplicate(true)
	var value: Variant = _shop_art_capture.get(key, {})
	return Dictionary(value).duplicate(true) if value is Dictionary else {}


func _replay_next_shop_capture(command: Dictionary, command_type: String) -> Dictionary:
	var replay_snapshots := Dictionary(_shop_art_capture.get("replay_snapshots", {}))
	var operations := Array(_shop_art_capture.get("operations", []))
	if replay_snapshots.is_empty() or operations.is_empty():
		return {"handled": false}
	if _shop_capture_operation_index >= operations.size():
		return {
			"handled": true,
			"response": _rejected_response(
				command,
				command_type,
				"SHOP_CAPTURE_COMPLETE",
				"正式商店公开操作序列已经回放完毕"
			),
		}
	var operation := Dictionary(operations[_shop_capture_operation_index])
	var expected_command := Dictionary(operation.get("command", {}))
	if not _shop_capture_command_matches(command, command_type, expected_command):
		return {
			"handled": true,
			"response": _rejected_response(
				command,
				command_type,
				"SHOP_CAPTURE_SEQUENCE_MISMATCH",
				"该操作不是正式商店公开回放序列的下一步"
			),
		}
	var snapshot_key := String(operation.get("snapshot_key", ""))
	var captured_snapshot := _shop_capture_snapshot(snapshot_key)
	var identity := Dictionary(operation.get("snapshot_identity", {}))
	if captured_snapshot.is_empty() \
			or int(captured_snapshot.get("stateVersion", -1)) != int(identity.get("stateVersion", -2)) \
			or String(captured_snapshot.get("stateHash", "")) != String(identity.get("stateHash", "")):
		return {
			"handled": true,
			"response": _rejected_response(
				command,
				command_type,
				"SHOP_CAPTURE_IDENTITY_MISMATCH",
				"正式商店公开 Snapshot 身份校验失败"
			),
		}
	_snapshot = captured_snapshot
	_shop_capture_operation_index += 1
	return {
		"handled": true,
		"response": _accepted_projection(command, command_type, {
			"type": command_type,
			"ok": true,
			"formal_shop_capture_replay": true,
			"capture_operation": String(operation.get("name", "")),
			"snapshot_key": snapshot_key,
		}),
	}


func _shop_capture_command_matches(
	command: Dictionary,
	command_type: String,
	expected: Dictionary
) -> bool:
	if command_type != String(expected.get("type", "")).strip_edges().to_upper():
		return false
	if command_type == "CHOOSE_ROUTE":
		return String(command.get("option_id", command.get("optionId", ""))) \
			== String(expected.get("option_id", expected.get("optionId", "")))
	if command_type == "BUY_OFFER":
		return String(command.get("offer_id", command.get("offerId", ""))) \
			== String(expected.get("offer_id", expected.get("offerId", "")))
	return true


func _shop_capture_matches_option(command: Dictionary) -> bool:
	var source := Dictionary(_shop_art_capture.get("source", {}))
	var expected := String(source.get("selected_option_id", ""))
	var requested := String(command.get("option_id", command.get("optionId", "")))
	return expected != "" and expected == requested


func _shop_capture_purchase_offer_id() -> String:
	for value in Array(_shop_art_capture.get("operations", [])):
		var operation := Dictionary(value)
		if String(operation.get("name", "")) != "purchase_offer":
			continue
		return String(Dictionary(operation.get("command", {})).get("offer_id", ""))
	return ""


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
	var offers := Array(_snapshot.get("shop_offers", [])).duplicate(true)
	for index in range(offers.size()):
		if String(Dictionary(offers[index]).get("id", "")) != offer_id:
			continue
		offers[index] = {}
		break
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
	var previous_board := Dictionary(_snapshot.get("board", {})).duplicate(true)
	var previous_trace_count := Array(
		_snapshot.get("battleTrace", _snapshot.get("battle_trace", []))
	).size()
	for key_value in Array(delta.get("remove", [])):
		_snapshot.erase(String(key_value))
	for key_value in Dictionary(delta.get("set", {})).keys():
		var key := String(key_value)
		_snapshot[key] = Dictionary(delta.get("set", {}))[key_value]
	_snapshot = _adapt_legacy_board_snapshot(_snapshot)
	_reconcile_legacy_occupied_hit_element_tiles(previous_trace_count, previous_board)
	_ensure_captured_target_preview_projection()
	_ensure_all_friendly_incoming_preview_projection()
	_ensure_action_block_ranges_projection()
	_ensure_skill_control_projection()


func _reconcile_legacy_occupied_hit_element_tiles(
	previous_trace_count: int,
	previous_board: Dictionary
) -> void:
	# Old exports wrote action-area element layers before the paired strike disclosed
	# which coordinates were occupied. Reconcile only that exported event pair; never
	# infer impact occupancy from units missing in the resulting snapshot.
	var trace := Array(_snapshot.get("battleTrace", _snapshot.get("battle_trace", [])))
	var first_new_event := clampi(previous_trace_count, 0, trace.size())
	_project_legacy_element_layers(trace, first_new_event, previous_board)
	if _legacy_element_layers_projection.is_empty():
		return
	var board := Dictionary(_snapshot.get("board", {}))
	if not board.is_empty():
		_snapshot["board"] = _subtract_legacy_occupied_hit_elements(board)
	var view_model := Dictionary(_snapshot.get("viewModel", {})).duplicate(true)
	if view_model.get("board", null) is Dictionary:
		view_model["board"] = _subtract_legacy_occupied_hit_elements(
			Dictionary(view_model["board"])
		)
		_snapshot["viewModel"] = view_model


func _project_legacy_element_layers(
	trace: Array,
	first_new_event: int,
	previous_board: Dictionary
) -> void:
	var event_index := first_new_event
	while event_index < trace.size():
		var event := Dictionary(trace[event_index])
		if String(event.get("type", "")) != "ELEMENT_APPLIED":
			event_index += 1
			continue
		var payload := Dictionary(event.get("payload", {}))
		if not bool(payload.get("deferToAttackStrike", false)) \
				or String(payload.get("sourceType", "")) != "action_area" \
				or _element_application_has_explicit_occupancy(payload):
			event_index += 1
			continue
		var element := String(payload.get("element", ""))
		var application_targets := {}
		for target_value in Array(payload.get("targets", [])):
			var target := Dictionary(target_value)
			application_targets[_trace_coordinate_key(target)] = true
		var occupied_hit_targets := {}
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
						var coordinate_key := _trace_coordinate_key(strike_target)
						if target_id != "" and application_targets.has(coordinate_key):
							occupied_hit_targets[coordinate_key] = true
			scan_index += 1
		if not observed_attack_strike:
			event_index = scan_index
			continue
		for change_value in Array(event.get("changes", [])):
			var change := Dictionary(change_value)
			var coordinate := _legacy_element_change_coordinate(change)
			var coordinate_key := "%d,%d" % [coordinate.x, coordinate.y]
			var change_element := String(change.get("element", element))
			var delta := int(change.get("delta", 0))
			if coordinate.x < 0 or coordinate.y < 0 \
					or change_element != element \
					or delta <= 0:
				continue
			var projection_key := "%s|%s" % [coordinate_key, element]
			var projection := Dictionary(
				_legacy_element_layers_projection.get(projection_key, {})
			).duplicate(true)
			if projection.is_empty():
				projection = {
					"x": coordinate.x,
					"y": coordinate.y,
					"element": element,
					"layers": _board_element_layers(
						previous_board,
						coordinate.x,
						coordinate.y,
						element
					),
				}
			if not occupied_hit_targets.has(coordinate_key):
				projection["layers"] = int(projection.get("layers", 0)) + delta
			_legacy_element_layers_projection[projection_key] = projection
		event_index = scan_index


func _element_application_has_explicit_occupancy(payload: Dictionary) -> bool:
	for target_value in Array(payload.get("targets", [])):
		var target := Dictionary(target_value)
		for key in ["hitEnemy", "hit_enemy", "occupiedAtImpact", "occupied_at_impact", "empty"]:
			if target.has(key):
				return true
	return false


func _legacy_element_change_coordinate(change: Dictionary) -> Vector2i:
	var path_parts := String(change.get("path", "")).split(".")
	if path_parts.size() < 3 or path_parts[0] != "cell_elements":
		return Vector2i(-1, -1)
	var coordinate_parts := String(path_parts[1]).split(",")
	if coordinate_parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(coordinate_parts[0]), int(coordinate_parts[1]))


func _trace_coordinate_key(record: Dictionary) -> String:
	return "%d,%d" % [
		int(record.get("x", record.get("c", -1))),
		int(record.get("y", record.get("r", -1))),
	]


func _board_element_layers(
	board: Dictionary,
	x: int,
	y: int,
	element: String
) -> int:
	var adapted_y := y
	if not _legacy_insertion_row_templates.is_empty() \
			and adapted_y >= int((BoardDimensionsScript.legacy_defaults().y + 1) / 2):
		adapted_y += 1
	for cell_value in Array(board.get("cells", [])):
		var cell := Dictionary(cell_value)
		if int(cell.get("x", cell.get("c", -1))) == x \
				and int(cell.get("y", cell.get("r", -1))) == adapted_y:
			return int(Dictionary(cell.get("elements", {})).get(element, 0))
	return 0


func _subtract_legacy_occupied_hit_elements(board: Dictionary) -> Dictionary:
	var reconciled := board.duplicate(true)
	var cells := Array(reconciled.get("cells", [])).duplicate(true)
	for cell_index in range(cells.size()):
		var cell := Dictionary(cells[cell_index]).duplicate(true)
		var cell_x := int(cell.get("x", cell.get("c", -1)))
		var cell_y := int(cell.get("y", cell.get("r", -1)))
		var elements := Dictionary(cell.get("elements", {})).duplicate(true)
		var changed := false
		for projection_value in _legacy_element_layers_projection.values():
			var projection := Dictionary(projection_value)
			var projection_y := int(projection.get("y", -1))
			if not _legacy_insertion_row_templates.is_empty() \
					and projection_y >= int((BoardDimensionsScript.legacy_defaults().y + 1) / 2):
				projection_y += 1
			if cell_x != int(projection.get("x", -1)) or cell_y != projection_y:
				continue
			var element := String(projection.get("element", ""))
			var current_layers := int(elements.get(element, 0))
			var next_layers := int(projection.get("layers", 0))
			if next_layers != current_layers:
				elements[element] = next_layers
				changed = true
		if changed:
			cell["elements"] = elements
			cells[cell_index] = cell
	reconciled["cells"] = cells
	return reconciled


func _adapt_legacy_board_snapshot(snapshot: Dictionary) -> Dictionary:
	var adapted := snapshot.duplicate(true)
	var board := Dictionary(adapted.get("board", {}))
	var legacy_dimensions := BoardDimensionsScript.legacy_defaults() as Vector2i
	var current_dimensions := BoardDimensionsScript.defaults() as Vector2i
	if int(board.get("width", board.get("columns", 0))) != legacy_dimensions.x \
			or int(board.get("height", board.get("rows", 0))) != legacy_dimensions.y \
			or current_dimensions != Vector2i(8, 8):
		return adapted
	var insertion_row := int((legacy_dimensions.y + 1) / 2)
	var expanded_board := _expand_legacy_board(board, insertion_row, current_dimensions)
	if expanded_board.is_empty():
		return adapted
	adapted["board"] = expanded_board
	for key in ["board_width", "boardWidth"]:
		if adapted.has(key):
			adapted[key] = current_dimensions.x
	for key in ["board_height", "boardHeight"]:
		if adapted.has(key):
			adapted[key] = current_dimensions.y
	if adapted.has("units"):
		adapted["units"] = _shift_coordinate_array(
			Array(adapted.get("units", [])),
			insertion_row
		)
	_adapt_action_preview_coordinates(adapted, insertion_row)
	for key in ["selected", "selected_cell", "selectedCell"]:
		if adapted.get(key, null) is Dictionary:
			adapted[key] = _shift_coordinate_record(Dictionary(adapted[key]), insertion_row)
	var view_model := Dictionary(adapted.get("viewModel", {})).duplicate(true)
	if not view_model.is_empty():
		if view_model.get("board", null) is Dictionary:
			view_model["board"] = _expand_legacy_board(
				Dictionary(view_model["board"]),
				insertion_row,
				current_dimensions
			)
		if view_model.has("units"):
			view_model["units"] = _shift_coordinate_array(
				Array(view_model.get("units", [])),
				insertion_row
			)
		_adapt_action_preview_coordinates(view_model, insertion_row)
		adapted["viewModel"] = view_model
	return adapted


func _expand_legacy_board(
	board: Dictionary,
	insertion_row: int,
	current_dimensions: Vector2i
) -> Dictionary:
	var source_cells := Array(board.get("cells", []))
	var legacy_dimensions := BoardDimensionsScript.legacy_defaults() as Vector2i
	if source_cells.size() != legacy_dimensions.x * legacy_dimensions.y:
		return {}
	var blank_row_templates := _legacy_insertion_row_templates.duplicate(true)
	if blank_row_templates.size() != current_dimensions.x:
		return {}
	var expanded_cells: Array = []
	for cell_value in source_cells:
		var cell := Dictionary(cell_value).duplicate(true)
		var x := int(cell.get("x", cell.get("c", -1)))
		var y := int(cell.get("y", cell.get("r", -1)))
		if y >= insertion_row:
			y += 1
		_set_cell_coordinates(cell, x, y)
		_shift_cell_preview_coordinates(cell, insertion_row)
		expanded_cells.append(cell)
	for x in range(current_dimensions.x):
		var blank := Dictionary(blank_row_templates[x]).duplicate(true)
		_set_cell_coordinates(blank, x, insertion_row)
		_shift_cell_preview_coordinates(blank, insertion_row)
		expanded_cells.append(blank)
	expanded_cells.sort_custom(func(left, right):
		var left_cell := Dictionary(left)
		var right_cell := Dictionary(right)
		var left_y := int(left_cell.get("y", left_cell.get("r", -1)))
		var right_y := int(right_cell.get("y", right_cell.get("r", -1)))
		if left_y == right_y:
			return int(left_cell.get("x", left_cell.get("c", -1))) \
				< int(right_cell.get("x", right_cell.get("c", -1)))
		return left_y < right_y
	)
	var expanded := board.duplicate(true)
	expanded["width"] = current_dimensions.x
	expanded["height"] = current_dimensions.y
	expanded["columns"] = current_dimensions.x
	expanded["rows"] = current_dimensions.y
	expanded["cellCount"] = current_dimensions.x * current_dimensions.y
	expanded["cell_count"] = current_dimensions.x * current_dimensions.y
	expanded["label"] = "%dx%d" % [current_dimensions.x, current_dimensions.y]
	var dimensions := Dictionary(expanded.get("dimensions", {})).duplicate(true)
	dimensions["width"] = current_dimensions.x
	dimensions["height"] = current_dimensions.y
	expanded["dimensions"] = dimensions
	if expanded.get("size", null) is Dictionary:
		var size_value := Dictionary(expanded["size"]).duplicate(true)
		size_value["width"] = current_dimensions.x
		size_value["height"] = current_dimensions.y
		expanded["size"] = size_value
	expanded["cells"] = expanded_cells
	return expanded


func _capture_legacy_insertion_row_templates(snapshot: Dictionary) -> Dictionary:
	var board := Dictionary(snapshot.get("board", {}))
	var legacy_dimensions := BoardDimensionsScript.legacy_defaults() as Vector2i
	if int(board.get("width", board.get("columns", 0))) != legacy_dimensions.x \
			or int(board.get("height", board.get("rows", 0))) != legacy_dimensions.y:
		return {}
	var insertion_row := int((legacy_dimensions.y + 1) / 2)
	var templates := {}
	for cell_value in Array(board.get("cells", [])):
		var cell := Dictionary(cell_value)
		var x := int(cell.get("x", cell.get("c", -1)))
		var y := int(cell.get("y", cell.get("r", -1)))
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		if x >= 0 and x < legacy_dimensions.x \
				and y == insertion_row - 1 and unit_id == "":
			templates[x] = cell.duplicate(true)
	return templates


func _set_cell_coordinates(cell: Dictionary, x: int, y: int) -> void:
	cell["x"] = x
	cell["y"] = y
	cell["c"] = x
	cell["r"] = y
	cell["key"] = "%d,%d" % [x, y]


func _shift_coordinate_array(values: Array, insertion_row: int) -> Array:
	var shifted: Array = []
	for value in values:
		if value is Dictionary:
			shifted.append(_shift_coordinate_record(Dictionary(value), insertion_row))
		else:
			shifted.append(value)
	return shifted


func _shift_coordinate_record(record: Dictionary, insertion_row: int) -> Dictionary:
	var shifted := record.duplicate(true)
	var has_y := shifted.has("y") or shifted.has("r")
	if not has_y:
		return shifted
	var y := int(shifted.get("y", shifted.get("r", -1)))
	if y < insertion_row:
		return shifted
	y += 1
	if shifted.has("y"):
		shifted["y"] = y
	if shifted.has("r"):
		shifted["r"] = y
	return shifted


func _shift_cell_preview_coordinates(cell: Dictionary, insertion_row: int) -> void:
	for key in ["action_preview_data", "actionPreviewData", "preview"]:
		if cell.get(key, null) is Dictionary:
			cell[key] = _shift_coordinate_record(Dictionary(cell[key]), insertion_row)
	if cell.has("previews"):
		cell["previews"] = _shift_coordinate_array(Array(cell.get("previews", [])), insertion_row)


func _adapt_action_preview_coordinates(container: Dictionary, insertion_row: int) -> void:
	for key in ["action_preview_by_unit", "actionPreviewByUnit"]:
		var previews := Dictionary(container.get(key, {})).duplicate(true)
		if previews.is_empty():
			continue
		for unit_id_value in previews.keys():
			var preview := Dictionary(previews[unit_id_value]).duplicate(true)
			if preview.get("origin", null) is Dictionary:
				preview["origin"] = _shift_coordinate_record(
					Dictionary(preview["origin"]),
					insertion_row
				)
			if preview.has("cells"):
				preview["cells"] = _shift_coordinate_array(
					Array(preview.get("cells", [])),
					insertion_row
				)
			previews[unit_id_value] = preview
		container[key] = previews


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
	result: Dictionary,
	lightweight_delivery: bool = false
) -> Dictionary:
	var response_snapshot := current_snapshot()
	var response := {
		"accepted": true,
		"pending": false,
		"status": "completed",
		"ok": true,
		"command": command_type,
		"result": result.duplicate(true),
		"snapshot": response_snapshot,
		"stateVersion": int(_snapshot.get("stateVersion", -1)),
		"stateHash": String(_snapshot.get("stateHash", "")),
	}
	command_completed.emit(
		command.duplicate(true),
		response.duplicate(false) if lightweight_delivery else response.duplicate(true)
	)
	command_settled.emit(response.duplicate(false) if lightweight_delivery else response.duplicate(true))
	snapshot_received.emit(response_snapshot.duplicate(false) if lightweight_delivery else current_snapshot(), {
		"asynchronous": false,
		"source": "formal_snapshot_projection",
		"command": command_type,
	})
	snapshot_changed.emit(
		response_snapshot.duplicate(false) if lightweight_delivery else current_snapshot(),
		result.duplicate(true)
	)
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


func _ensure_all_friendly_incoming_preview_projection() -> void:
	if _captured_incoming_preview_template.is_empty() \
			or String(_snapshot.get("phase", "")) != "battle":
		return
	for value in Array(Dictionary(_snapshot.get("board", {})).get("cells", [])):
		var cell := Dictionary(value)
		if not _cell_is_friendly_target(cell):
			continue
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		if unit_id != "":
			_incoming_projection_unit_ids[unit_id] = true
	_ensure_tracked_incoming_preview_projection()


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
			if not cell.is_empty() and unit.is_empty():
				_snapshot["selected_unit_id"] = ""
				if _snapshot.has("selectedUnitId"):
					_snapshot["selectedUnitId"] = ""
				_snapshot["selected"] = {
					"unitId": "",
					"x": x,
					"y": y,
				}
				return {
					"type": "SELECT_CELL",
					"ok": true,
					"cleared": true,
					"x": x,
					"y": y,
					"unit_id": "",
					"unit": {},
				}
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
