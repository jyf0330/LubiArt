extends SceneTree

const BATTLE_SCENE_PATH := "res://art/scenes/battle/battle_art_scene.tscn"
const DRAG_PATH := "res://core_ui/scripts/battle/controllers/battle_board_drag_interaction.gd"
const PREVIEW_PATH := "res://core_ui/scripts/battle/controllers/battle_board_preview_coordinator.gd"
const BattleSnapshotView := preload("res://core_ui/scripts/battle/controllers/battle_snapshot_view.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var drag_source := _read(DRAG_PATH)
	var preview_source := _read(PREVIEW_PATH)
	assert(not drag_source.is_empty())
	assert(not preview_source.is_empty())

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
	var compatibility_snapshot := {
		"phase": "battle",
		"battle_trace": [{"type": "legacy"}],
		"selectedUnitId": "unit_1",
		"selectedActionSlotIndex": 2,
		"skill_control_bar": [{"entry_id": "unit_1:a"}],
	}
	assert(BattleSnapshotView.phase(compatibility_snapshot) == "battle")
	assert(BattleSnapshotView.trace_events(compatibility_snapshot).size() == 1)
	assert(BattleSnapshotView.selected_unit_id(compatibility_snapshot) == "unit_1")
	assert(BattleSnapshotView.selected_slot_index(compatibility_snapshot) == 2)
	assert(BattleSnapshotView.skill_control_bar(compatibility_snapshot).size() == 1)

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
		"MapControls",
		"Hud",
		"Hud/BattleActionPanel/Margin/Content/MapDebugButton",
		"OverlayHost",
		"OverlayHost/SettingsMenu",
	]
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
		"set_background_texture",
		"render_snapshot",
		"board_dimensions",
		"rendered_cell_count",
		"missing_mapping_report",
		"cell_at",
		"cell_data_at_grid",
		"grid_from_board_position",
		"project_local_unit_drop",
	]:
		assert(board.has_method(method_name))

	scene.queue_free()
	await process_frame
	print("BATTLE_BOARD_RESPONSIBILITY_CONTRACT_PASS")
	quit(0)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""
