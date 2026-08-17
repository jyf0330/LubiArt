extends SceneTree

const BATTLE_UI_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var battle := BATTLE_UI_SCENE.instantiate() as Control
	if battle == null:
		push_error("Battle UI should instantiate for board-pet stat smoke.")
		quit(1)
		return
	root.add_child(battle)
	await process_frame
	battle.call("render_snapshot", _snapshot_with_threat(7))
	await process_frame
	var unit := _unit_at(battle, Vector2i(3, 5))
	if unit == null:
		push_error("Moved pet should render at visible board cell (3,5).")
		quit(1)
		return
	if not _has_board_stats(unit, 24, 4, 7):
		push_error("Board pet public stat projection should expose health, attack, and damage-cap values at (3,5).")
		quit(1)
		return
	battle.call("render_snapshot", _snapshot_with_threat(0))
	await process_frame
	unit = _unit_at(battle, Vector2i(3, 5))
	if not _has_board_stats(unit, 24, 4, 0):
		push_error("Board pet public stat projection should expose zero damage-cap when its core threat is empty.")
		quit(1)
		return
	battle.call("render_snapshot", _snapshot_with_threat(7))
	await process_frame
	var capture_saved := await _save_capture("res://output/battle_board_pet_three_stats.png")
	if not capture_saved:
		print("SMOKE_BATTLE_BOARD_PET_THREE_STATS_CAPTURE_SKIPPED headless viewport texture unavailable")
	print("SMOKE_BATTLE_BOARD_PET_THREE_STATS_OK")
	if _should_keep_open():
		print("SMOKE_BATTLE_BOARD_PET_THREE_STATS_KEEP_OPEN")
		return
	quit(0)


func _snapshot_with_threat(incoming_damage: int) -> Dictionary:
	return {
		"board": {
			"cells": [{
				"x": 3,
				"y": 5,
				"unitId": "pal_002",
				"unitName": "捣蛋猫",
				"side": "player",
				"hp": 24,
				"atk": 4,
				"damage_cap": incoming_damage,
				"threat": {"damage": incoming_damage, "unitName": "棉悠悠"}
			}]
		},
		"units": [{
			"id": "pal_002",
			"name": "捣蛋猫",
			"side": "player",
			"hp": 24,
			"max_hp": 24,
			"atk": 4,
			"damage_cap": incoming_damage
		}]
	}


func _unit_at(battle: Control, grid: Vector2i) -> Control:
	var board_grid := battle.get_node_or_null("Board/CellHost")
	if board_grid == null:
		return null
	for cell in board_grid.get_children():
		if not cell.has_method("get_grid_position") or Vector2i(cell.call("get_grid_position")) != grid:
			continue
		if cell.has_method("get_unit_node"):
			return cell.call("get_unit_node") as Control
	return null


func _has_board_stats(unit: Control, health: int, attack: int, damage_cap: int) -> bool:
	if not unit.has_method("get_dynamic_stat_snapshot"):
		return false
	var stats := Dictionary(unit.call("get_dynamic_stat_snapshot"))
	return (
		int(stats.get("hp", -1)) == health
		and int(stats.get("atk", stats.get("attack", -1))) == attack
		and int(stats.get("damage_cap", stats.get("damageCap", -1))) == damage_cap
	)


func _should_keep_open() -> bool:
	return OS.get_cmdline_args().has("--keep-open") or OS.get_cmdline_user_args().has("--keep-open")


func _save_capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	return image != null and image.save_png(path) == OK
