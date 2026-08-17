extends SceneTree

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")

var _failed := false
var _commands: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BATTLE_SCENE.instantiate()
	root.add_child(battle)
	await process_frame
	var hud := battle.find_child("Hud", true, false) as Control
	if hud != null:
		hud.show()
	var panel := battle.find_child("BattleActionPanel", true, false)
	_expect(panel != null, "battle action panel exists")
	if panel == null:
		_finish()
		return
	panel.command_requested.connect(_on_command_requested)
	var snap := _snapshot_fixture()
	var select_snap := snap.duplicate(true)
	select_snap["selected_unit_id"] = ""
	select_snap["selected_action_cells"] = []
	panel.call("render_snapshot", select_snap)
	await process_frame
	_expect(panel.find_child("FlowState", true, false) != null, "authored flow-state node exists")
	var select_state := Dictionary(panel.call("visual_state_summary"))
	_expect(String(select_state.get("state", "")) == "select", "empty selection uses the select visual state")
	_expect(String(select_state.get("flow_text", "")).contains("选择宠物"), "select state explains the first step")
	_expect(not (panel.find_child("AllOutButton", true, false) as Button).disabled, "shared skill bar can execute without a selected pet")
	panel.call("render_snapshot", snap)
	await process_frame
	_expect(String(panel.call("feedback_text")).contains("预览：红色作用格 3 个"), "selected pet preview is explicit")
	_expect(String(panel.call("feedback_text")).contains("共享条 8 个 A/B 技能从左到右触发"), "shared-bar execution order is explicit")
	var preview_state := Dictionary(panel.call("visual_state_summary"))
	_expect(String(preview_state.get("state", "")) == "preview", "selected pet uses the preview visual state")
	_expect(String(preview_state.get("flow_text", "")).contains("红色范围"), "preview state names the target-range step")

	var skill_grid := panel.find_child("SkillQueueGrid", true, false) as GridContainer
	var slot_one := skill_grid.get_child(0) as Button
	var slot_two := skill_grid.get_child(1) as Button
	var slot_three := skill_grid.get_child(2) as Button
	_expect(slot_one.focus_mode == Control.FOCUS_ALL, "skill slots accept keyboard and controller focus")
	_expect(slot_one.get_node(slot_one.focus_neighbor_right) == slot_two, "slot one right neighbor is slot two")
	_expect(slot_one.get_node(slot_one.focus_neighbor_bottom) == slot_three, "slot one down neighbor is slot three")
	var focus_graph := Dictionary(panel.call("focus_navigation_summary"))
	_expect(focus_graph.size() == 12, "focus graph covers reset, eight skills, and three actions")
	for name in focus_graph:
		var row := Dictionary(focus_graph[name])
		_expect(String(row.get("top", "")) != "" and String(row.get("bottom", "")) != "", "%s has explicit vertical focus neighbors" % name)
		_expect(String(row.get("next", "")) != "" and String(row.get("previous", "")) != "", "%s participates in tab focus order" % name)

	panel.call("focus_default")
	await process_frame
	_expect(root.gui_get_focus_owner() == slot_one, "selected queue starts focus at the first skill")
	slot_one.emit_signal("pressed")
	_expect(bool(slot_one.call("is_picked")), "confirm-key selection stays visibly picked")
	_expect(int(Dictionary(panel.call("visual_state_summary")).get("picked_skill_index", -1)) == 0, "picked slot is exposed for visual QA")
	slot_two.emit_signal("pressed")
	_expect(not bool(slot_one.call("is_picked")), "picked styling clears after the move request")
	_expect(_commands.size() == 1 and String(_commands[0].get("type", "")) == "SET_SKILL_CONTROL_ORDER", "confirm-key button path emits the shared-bar reorder command")
	_expect(Array(_commands[0].get("orderedEntryIds", [])).slice(0, 2) == ["pet_1:b", "pet_1:a"], "confirm-key reorder preserves stable pet-slot entry identities")

	panel.call("set_input_locked", true)
	_expect(bool(panel.call("is_input_locked")), "battle trace lifecycle locks the action panel")
	var executing_state := Dictionary(panel.call("visual_state_summary"))
	_expect(String(executing_state.get("state", "")) == "executing", "input lock uses the executing visual state")
	_expect(String(executing_state.get("flow_text", "")).contains("执行中"), "executing state is visible without reading disabled controls")
	for button in _panel_buttons(panel):
		_expect(button.disabled, "%s is disabled while trace is playing" % button.name)
	_expect((panel.find_child("SkillQueueTitle", true, false) as Label).text.contains("等待权威 Trace"), "locked panel explains why input is unavailable")

	var resolved := snap.duplicate(true)
	resolved["battleTrace"] = [
		{"type": "SKILL_TRIGGERED", "payload": {}},
		{"type": "SKILL_TRIGGERED", "payload": {}},
		{"type": "SKILL_COMBO_TRIGGERED", "payload": {}},
		{"type": "DAMAGE_APPLIED", "payload": {"finalDamage": 7, "hpDamage": 5, "shieldDamage": 2}},
		{"type": "DAMAGE_APPLIED", "payload": {"finalDamage": 5, "hpDamage": 4, "shieldDamage": 1}},
	]
	panel.call("render_snapshot", resolved)
	panel.call("set_input_locked", false)
	var feedback := String(panel.call("feedback_text"))
	_expect(feedback.contains("结果：2 个技能 · 1 个组合"), "trace result reports executed skills and combos")
	_expect(feedback.contains("伤害 12（生命 9 / 护盾 3）"), "trace result reports authoritative damage split")
	_expect(not bool(panel.call("is_input_locked")), "action panel unlocks after trace completion")
	var result_state := Dictionary(panel.call("visual_state_summary"))
	_expect(String(result_state.get("state", "")) == "result", "completed trace uses the result visual state")
	_expect(String(result_state.get("flow_text", "")).contains("执行完成"), "result state explains that execution completed")
	_expect(not (panel.find_child("AllOutButton", true, false) as Button).disabled, "valid action is restored after trace completion")
	_finish()


func _snapshot_fixture() -> Dictionary:
	var queue: Array = []
	var units: Array = []
	for pet_index in range(4):
		var unit_id := "pet_%d" % (pet_index + 1)
		var unit_name := "测试宠物%d" % (pet_index + 1)
		units.append({"id": unit_id, "name": unit_name, "side": "player"})
		for slot_index in range(2):
			var slot := "a" if slot_index == 0 else "b"
			queue.append({
				"entryId": "%s:%s" % [unit_id, slot],
				"unitId": unit_id,
				"unitName": unit_name,
				"skillSlot": slot,
				"skillId": "skill_%d" % (slot_index + 1),
				"label": "技能%s" % slot.to_upper(),
			})
	return {
		"phase": "battle",
		"battle_round": 2,
		"selected_unit_id": "pet_1",
		"units": units,
		"skillControlBar": queue,
		"selected_action_cells": [{"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}],
		"pet_reset": {"player": {"eligible": true, "resetCount": 1, "charges": 1, "aliveThreshold": 2}},
		"battleTrace": [],
	}


func _panel_buttons(panel: Node) -> Array[Button]:
	var result: Array[Button] = []
	for name in ["ResetPetsButton", "AllOutButton", "EndTurnButton", "MonsterTurnButton"]:
		var button := panel.find_child(name, true, false) as Button
		if button != null:
			result.append(button)
	var skill_grid := panel.find_child("SkillQueueGrid", true, false) as GridContainer
	if skill_grid != null:
		for child in skill_grid.get_children():
			var skill_button := child as Button
			if skill_button != null:
				result.append(skill_button)
	return result


func _on_command_requested(command: Dictionary) -> void:
	_commands.append(command.duplicate(true))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_BATTLE_ACTION_LIFECYCLE_FAIL %s" % message)


func _finish() -> void:
	if not _failed:
		print("SMOKE_BATTLE_ACTION_LIFECYCLE_OK")
	quit(1 if _failed else 0)
