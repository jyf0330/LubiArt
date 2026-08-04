extends SceneTree

const BATTLE_SCENE_PATH := "res://art/scenes/battle/battle_art_scene.tscn"
const BOARD_PATH := "res://core_ui/scripts/battle/scenes/battle_board.gd"
const DRAG_PATH := "res://core_ui/scripts/battle/controllers/battle_board_drag_interaction.gd"
const PREVIEW_PATH := "res://core_ui/scripts/battle/controllers/battle_board_preview_coordinator.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var board_source := _read(BOARD_PATH)
	var drag_source := _read(DRAG_PATH)
	var preview_source := _read(PREVIEW_PATH)
	assert(not board_source.is_empty())
	assert(not drag_source.is_empty())
	assert(not preview_source.is_empty())

	for retained in [
		"var _cell_pool: Array[Control]",
		"var _unit_pool: Array[Control]",
		"func render_snapshot(",
		"func _build_board(",
		"func _grid_from_board_position(",
		"func _apply_local_unit_drop(",
	]:
		assert(board_source.contains(retained))
	for migrated in [
		"var _drag_unit_id",
		"var _drop_settle_active",
		"var _direction_hover_highlight_keys",
		"var _enemy_damage_preview_sync_epoch_msec",
		"func _start_unit_drag(",
		"func _show_direction_hover_preview(",
		"func _sync_enemy_damage_previews(",
	]:
		assert(not board_source.contains(migrated))

	for required in [
		"signal command_requested(command: Dictionary)",
		"func handle_input(event: InputEvent) -> bool",
		"func cancel_for_board_resize() -> void",
		"func restore_after_snapshot() -> void",
	]:
		assert(drag_source.contains(required))
	for required in [
		"func render_snapshot(snapshot: Dictionary) -> void",
		"func show_direction_preview(unit_id: String, direction: String) -> void",
		"func begin_drag(unit_id: String, origin: Vector2i, preview: Control) -> void",
		"func sync_enemy_damage_previews(preserve_active_enemy_previews: bool = false) -> void",
	]:
		assert(preview_source.contains(required))

	for forbidden in ["YsbzsState", "GameSession", "Repository", "DamageResolver", "CombatManager"]:
		assert(not drag_source.contains(forbidden))
		assert(not preview_source.contains(forbidden))

	var packed := load(BATTLE_SCENE_PATH) as PackedScene
	assert(packed != null)
	var scene := packed.instantiate() as Control
	assert(scene != null)
	root.add_child(scene)
	await process_frame
	var expected_paths := [
		"Board",
		"Board/Background",
		"Board/CellHost",
		"Board/UnitHost",
		"Board/VfxHost",
		"Hud",
		"OverlayHost",
	]
	assert(scene.get_child_count() == 3)
	for path in expected_paths:
		assert(scene.get_node_or_null(path) != null)
	assert(scene.get_node("Board/CellHost").get_script() == null)
	assert(scene.get_node("Board/UnitHost").get_script() == null)
	var board := scene.get_node("Board")
	for method_name in [
		"configure",
		"set_input_locked",
		"show_direction_preview",
		"apply_enemy_move_final_cell",
		"reveal_reset_units",
		"clear_transient_state",
		"render_snapshot",
		"board_dimensions",
		"rendered_cell_count",
		"missing_mapping_report",
	]:
		assert(board.has_method(method_name))

	scene.queue_free()
	await process_frame
	print("BATTLE_BOARD_RESPONSIBILITY_CONTRACT_PASS")
	quit(0)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""
