extends SceneTree

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")

var _failed := false
var _commands: Array[Dictionary] = []
var _session_operations: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BATTLE_SCENE.instantiate() as Control
	root.add_child(battle)
	battle.command_requested.connect(_on_command_requested)
	battle.session_operation_requested.connect(_on_session_operation_requested)
	await process_frame
	await process_frame
	battle.call("configure_trace_cursor", 7)
	_expect(int(battle.call("get_trace_cursor")) == 7, "formal Trace cursor contract is preserved")
	battle.call("render_snapshot", _snapshot_fixture())
	await process_frame

	var controls := battle.get_node("MapControls") as Control
	_expect(not (controls.get_node("ResetButton") as TextureButton).disabled, "eligible reset is available")
	_expect(not (controls.get_node("SpeedButton") as TextureButton).disabled, "presentation-only battle speed action is available")
	_expect(not (controls.get_node("BagButton") as TextureButton).disabled, "round rewind is available when snapshot exposes a previous-round checkpoint")
	_expect(
		not (battle.get_node("Hud/BattleActionPanel/Margin/Content/MapDebugButton") as Button).visible,
		"map debug is hidden outside developer mode"
	)
	_expect(battle.get_node_or_null("ShortcutHintDebugButton") == null, "obsolete shortcut debug control stays deleted")

	(controls.get_node("ResetButton") as TextureButton).pressed.emit()
	_expect(_commands.size() == 1 and _commands[0] == {"type": "RESET_PETS"}, "reset submits one pure semantic intent")
	(controls.get_node("BagButton") as TextureButton).pressed.emit()
	_expect(
		_commands.size() == 2 and _commands[1] == {"type": "REWIND_TO_PREVIOUS_ROUND_START"},
		"temporary bag control submits one pure previous-round rewind intent"
	)
	(controls.get_node("AttackOrderButton") as TextureButton).pressed.emit()
	await process_frame
	var timeline := battle.get_node("Hud/AttackTimelineLayer/AttackTimeline") as Control
	_expect(timeline.visible and int(timeline.call("debug_marker_count")) == 8, "map control opens the eight-entry A/B timeline")

	(controls.get_node("SettingsButton") as TextureButton).pressed.emit()
	await process_frame
	var settings := battle.get_node("OverlayHost/SettingsMenu") as Control
	var buttons_root := "CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/"
	_expect(settings.visible, "map control opens formal settings")
	_expect((settings.get_node(buttons_root + "MainMenu") as Button).disabled, "unrouted main-menu action is disabled")
	_expect((settings.get_node(buttons_root + "Resign") as Button).disabled, "unrouted resign action is disabled")
	(settings.get_node(buttons_root + "SaveGame") as Button).pressed.emit()
	await process_frame
	var save_dialog := settings.get_node("UISaveGame") as Control
	(save_dialog.find_child("SaveSlot1", true, false) as Button).pressed.emit()
	await process_frame
	_expect(_session_operations.size() == 1, "settings emits one narrow Session operation")
	if _session_operations.size() == 1:
		_expect(StringName(_session_operations[0].get("operation", &"")) == &"save", "settings emits save intent")
		_expect(int(Dictionary(_session_operations[0].get("arguments", {})).get("slot", 0)) == 1, "settings preserves selected slot")
	_finish()


func _snapshot_fixture() -> Dictionary:
	var units: Array = []
	var control_bar: Array = []
	for pet_index in range(4):
		var unit_id := "pet_%d" % (pet_index + 1)
		var unit_name := "测试宠物%d" % (pet_index + 1)
		units.append({"id": unit_id, "name": unit_name, "side": "player"})
		for skill_slot in ["a", "b"]:
			control_bar.append({
				"entryId": "%s:%s" % [unit_id, skill_slot],
				"unitId": unit_id,
				"unitName": unit_name,
				"skillSlot": skill_slot,
				"skillId": "skill_%s" % skill_slot,
				"label": "技能%s" % skill_slot.to_upper(),
			})
	return {
		"phase": "battle",
		"units": units,
		"skillControlBar": control_bar,
		"pet_reset": {"player": {"eligible": true}},
		"round_rewind": {"canRewind": true, "currentRound": 2, "targetRound": 1},
		"board": {"cells": []},
		"battleTrace": [],
	}


func _on_command_requested(command: Dictionary) -> void:
	_commands.append(command.duplicate(true))


func _on_session_operation_requested(operation: StringName, arguments: Dictionary) -> void:
	_session_operations.append({"operation": operation, "arguments": arguments.duplicate(true)})


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_BATTLE_ART_CONTROLS_FAIL: %s" % message)


func _finish() -> void:
	if not _failed:
		print("SMOKE_BATTLE_ART_CONTROLS_OK")
	quit(1 if _failed else 0)
