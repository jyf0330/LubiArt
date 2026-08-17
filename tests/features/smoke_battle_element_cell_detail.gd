extends SceneTree

const BATTLE_UI_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _battle: Control = null
var _probe: RefCounted = null
var _requested_command: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	_battle = BATTLE_UI_SCENE.instantiate() as Control
	if _battle == null:
		push_error("Battle UI scene should instantiate for element-cell detail smoke.")
		quit(1)
		return
	root.add_child(_battle)
	_battle.command_requested.connect(_on_command_requested)
	await process_frame
	_probe = BattleSceneProbe.new(_battle)
	var terrain_detail := _battle.get_node_or_null("OverlayHost/BattleElementDetailPanel") as PanelContainer
	if terrain_detail == null or terrain_detail.scene_file_path != "res://art/prefabs/terrain/terrain_detail.tscn":
		push_error("Battle CellDetail must author the formal terrain-detail prefab instance.")
		quit(1)
		return
	_battle.call("render_snapshot", _element_snapshot())
	if _manual_visible_requested():
		print("SMOKE_BATTLE_ELEMENT_CELL_DETAIL_WAITING_FOR_MOUSE")
		return
	var opened := Dictionary(_probe.call("open_first_element_detail"))
	if not bool(opened.get("opened", false)):
		push_error("A rendered element-only cell should be selectable for details.")
		quit(1)
		return
	await process_frame
	if String(_requested_command.get("type", "")) != "GET_CELL_DETAIL":
		push_error("Element-cell click should request GET_CELL_DETAIL, got %s." % JSON.stringify(_requested_command))
		quit(1)
		return
	var summary := Dictionary(_probe.call("detail_summary"))
	var text := String(summary.get("text", ""))
	if not bool(summary.get("visible", false)) or text.find("地形详情") < 0 or text.find("第3行 · 第5列") < 0 or text.find("火3") < 0 or text.find("水1") < 0:
		push_error("Element-cell detail should show position and real element layers, got %s." % JSON.stringify(summary))
		quit(1)
		return
	var capture_saved := await _save_capture("res://output/battle_element_cell_detail.png")
	if not capture_saved:
		print("SMOKE_BATTLE_ELEMENT_CELL_DETAIL_CAPTURE_SKIPPED headless viewport texture unavailable")
	print("SMOKE_BATTLE_ELEMENT_CELL_DETAIL_OK")
	if _should_keep_open():
		print("SMOKE_BATTLE_ELEMENT_CELL_DETAIL_KEEP_OPEN")
		return
	quit(0)


func _on_command_requested(command: Dictionary) -> void:
	_requested_command = command.duplicate(true)
	if String(command.get("type", "")) != "GET_CELL_DETAIL":
		return
	var snapshot := _element_snapshot()
	snapshot["lastCommandResult"] = {
		"x": 4,
		"y": 2,
		"c": 4,
		"r": 2,
		"elements": {"火": 3, "水": 1, "土": 0, "风": 0},
		"unit": {},
		"preview": {},
		"threat": {}
	}
	_battle.call("render_snapshot", snapshot)
	if _manual_visible_requested():
		call_deferred("_save_manual_visible_capture")


func _element_snapshot() -> Dictionary:
	return {
		"board": {
			"cells": [{
				"x": 4,
				"y": 2,
				"elements": {"火": 3, "水": 1, "土": 0, "风": 0}
			}]
		},
		"units": []
	}


func _should_keep_open() -> bool:
	if OS.get_environment("KEEP_GODOT_OPEN") == "1":
		return true
	for arg in OS.get_cmdline_args():
		if String(arg) == "--keep-open":
			return true
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--keep-open":
			return true
	return false


func _manual_visible_requested() -> bool:
	for arg in OS.get_cmdline_args():
		if String(arg) == "--manual-visible":
			return true
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--manual-visible":
			return true
	return false


func _save_manual_visible_capture() -> void:
	if await _save_capture("res://output/battle_element_cell_detail.png"):
		print("SMOKE_BATTLE_ELEMENT_CELL_DETAIL_VISIBLE_CAPTURE_OK")


func _save_capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		return false
	return image.save_png(path) == OK
