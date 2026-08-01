extends "res://session/game_session.gd"
class_name MockGameSession

## Offline replay of public snapshots captured from the production
## LocalGameSession. This project does not calculate combat outcomes.

signal snapshot_changed(snapshot: Dictionary, event: Dictionary)

const CAPTURE_PATH := "res://data/mock_battle_snapshot.json"
const DEFAULT_SKILLS := [
	{"id": "skill_vanguard", "name": "先锋击"},
	{"id": "skill_flank", "name": "侧翼击"},
	{"id": "skill_pierce", "name": "穿阵击"},
	{"id": "skill_revolve", "name": "回旋击"},
	{"id": "skill_chase", "name": "追风击"},
	{"id": "skill_break", "name": "裂阵击"},
	{"id": "skill_suppress", "name": "压制击"},
	{"id": "skill_finale", "name": "终幕击"},
]
const DEFAULT_COMBOS := [
	{"id": "combo_pincer", "name": "前后夹击", "skills": ["skill_vanguard", "skill_flank"]},
	{"id": "combo_piercing_arc", "name": "穿回连携", "skills": ["skill_pierce", "skill_revolve"]},
	{"id": "combo_breakthrough", "name": "追裂连携", "skills": ["skill_chase", "skill_break"]},
	{"id": "combo_finale", "name": "压制终幕", "skills": ["skill_suppress", "skill_finale"]},
]
const DAMAGE_PREVIEW_TEMPLATES_KEY := "mock_damage_preview_templates_by_actor"
const INCOMING_DAMAGE_PREVIEW_TEMPLATE_KEY := "mock_incoming_damage_preview_template"
const START_PHASE_ROUTE := "route"
const START_PHASE_BATTLE := "battle"

var _capture_source: Dictionary = {}
var _presentation_bootstrap_snapshot: Dictionary = {}
var _battle_bootstrap_snapshot: Dictionary = {}
var _snapshot: Dictionary = {}
var _steps: Array = []
var _step_index := 0
var _skill_orders: Dictionary = {}
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
	if command_type in ["GET_CELL_DETAIL", "SELECT_UNIT"]:
		return _accepted_projection(
			command,
			command_type,
			_projection_result(command_type, command)
		)
	if command_type == "SET_SKILL_ORDER":
		return _accepted_projection(command, command_type, _set_skill_order(command))
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
	_skill_orders = {}
	_ensure_action_block_ranges_projection()
	_ensure_skill_queue_projection()
	_steps = Array(capture.get("steps", [])).duplicate(true)
	_snapshot[DAMAGE_PREVIEW_TEMPLATES_KEY] = _collect_damage_preview_templates(capture)
	_snapshot[INCOMING_DAMAGE_PREVIEW_TEMPLATE_KEY] = \
		_collect_incoming_damage_preview_template(capture)
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
	_ensure_action_block_ranges_projection()
	_ensure_skill_queue_projection()


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


func _ensure_skill_queue_projection() -> void:
	var unit_id := String(_snapshot.get("selected_unit_id", _snapshot.get("selectedUnitId", "")))
	var order := Array(_skill_orders.get(unit_id, _default_skill_ids())).duplicate()
	var entries: Array = []
	for index in range(order.size()):
		var skill_id := String(order[index])
		entries.append({
			"entryId": "%s:%s" % [unit_id, skill_id],
			"ownerUnitId": unit_id,
			"skillId": skill_id,
			"label": _skill_name(skill_id),
			"orderIndex": index,
		})
	_snapshot["selected_skill_queue"] = entries
	_snapshot["selectedSkillQueue"] = entries.duplicate(true)
	var traits := [_mock_trait_for_selected_unit()]
	var combos := _mock_combos_for_order(order)
	_snapshot["selected_traits"] = traits
	_snapshot["selectedTraits"] = traits.duplicate(true)
	_snapshot["selected_skill_combos"] = combos
	_snapshot["selectedSkillCombos"] = combos.duplicate(true)


func _set_skill_order(command: Dictionary) -> Dictionary:
	var unit_id := String(command.get("unitId", command.get("unit_id", "")))
	var requested := Array(command.get("orderedSkillIds", command.get("ordered_skill_ids", [])))
	var current := Array(_skill_orders.get(unit_id, _default_skill_ids()))
	if requested.size() != current.size():
		return {"type": "SET_SKILL_ORDER", "ok": false, "message": "技能顺序必须包含全部8个技能"}
	for skill_id in current:
		if requested.count(skill_id) != 1:
			return {"type": "SET_SKILL_ORDER", "ok": false, "message": "技能顺序包含重复或缺失技能"}
	_skill_orders[unit_id] = requested.duplicate()
	_ensure_skill_queue_projection()
	return {"type": "SET_SKILL_ORDER", "ok": true, "unitId": unit_id, "skillQueue": Array(_snapshot["selectedSkillQueue"]).duplicate(true)}


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
			_ensure_skill_queue_projection()
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
		_ensure_skill_queue_projection()
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
