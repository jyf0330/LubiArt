extends SceneTree

const MockSession := preload("res://session/mock_game_session.gd")
const FeatureRegistry := preload("res://game/controllers/feature_registry.gd")
const SceneRouter := preload("res://game/controllers/scene_router.gd")
const BattleBoardController := preload("res://features/battle/controllers/battle_board_controller.gd")
const BattleHudController := preload("res://features/battle/controllers/battle_hud_controller.gd")
const BattleDetailController := preload("res://features/battle/controllers/battle_detail_controller.gd")
const BattleCommandBuilder := preload("res://features/battle/controllers/battle_command_builder.gd")
const BattleTraceProjection := preload("res://features/battle/controllers/battle_trace_projection.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_presentation_patterns_load()
	var isolated_session := MockSession.new()
	var boot_snapshot := Dictionary(isolated_session.current_snapshot())
	_assert_snapshot_contract(boot_snapshot)
	assert(String(boot_snapshot.get("phase", "")) == "route")
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var initial := Dictionary(isolated_session.current_snapshot())
	assert(String(initial.get("phase", "")) == "battle")
	var before_position := _unit_position(initial, "player_pet_01")
	var auto_response := Dictionary(isolated_session.submit_command({"type": "AUTO_POSITION_HEROES"}))
	assert(bool(auto_response.get("accepted", false)))
	var positioned := Dictionary(isolated_session.current_snapshot())
	assert(_unit_position(positioned, "player_pet_01") != before_position)
	var before_round := int(positioned.get("battle_round", 0))
	var round_response := Dictionary(isolated_session.submit_command({"type": "RUN_COMBAT_ROUND"}))
	assert(bool(round_response.get("accepted", false)))
	var advanced := Dictionary(isolated_session.current_snapshot())
	assert(int(advanced.get("battle_round", 0)) == before_round + 1)
	assert(not Array(advanced.get("battleTrace", [])).is_empty())
	assert(not isolated_session.supports_persistence())

	var main_scene := load("res://game/scenes/game.tscn") as PackedScene
	assert(main_scene != null)
	var main_instance := main_scene.instantiate()
	root.add_child(main_instance)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await create_timer(1.0).timeout

	var view_host := main_instance.get_node_or_null("ViewHost") as Control
	assert(view_host != null)
	assert(view_host.get_child_count() == 1)
	var artist_view := view_host.get_child(0) as Control
	assert(artist_view != null)
	assert(artist_view.name == "UI")
	var battle_view := artist_view.get_node_or_null("BattleFlow") as Control
	assert(battle_view != null)
	assert(battle_view.get_node_or_null("BattleVfxPlayer") != null)
	assert(battle_view.get_node_or_null("BattleActionPanel") != null)
	assert(battle_view.get_node_or_null("BattlePetDetailPanel") != null)

	var game_session := main_instance.call("get_game_session") as RefCounted
	assert(game_session != null)
	assert(String(Dictionary(game_session.call("current_snapshot")).get("phase", "")) == "battle")
	var board_grid := battle_view.get_node("BoardGrid") as Control
	assert(board_grid.get_child_count() == 64)
	assert(main_instance.call("get_active_view") == artist_view)
	assert(artist_view.call("get_feature_controller", &"battle") == battle_view)

	var visible_pet_count := 0
	for cell in board_grid.get_children():
		var pet_view := cell.call("get_unit_node") as Control
		if pet_view == null or not pet_view.visible:
			continue
		visible_pet_count += 1
		var grid := cell.call("get_grid_position") as Vector2i
		cell.cell_selected.emit(grid.x, grid.y)
		break
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	assert(visible_pet_count > 0)
	assert((battle_view.get_node("BattlePetDetailPanel") as Control).visible)

	var main_before_position := _unit_position(
		Dictionary(game_session.call("current_snapshot")),
		"player_pet_01"
	)
	(battle_view.get_node("AutoArrangeButton") as TextureButton).pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	var main_positioned := Dictionary(game_session.call("current_snapshot"))
	assert(_unit_position(main_positioned, "player_pet_01") != main_before_position)

	var main_before_round := int(main_positioned.get("battle_round", 0))
	(battle_view.get_node("BeginTurnButton") as TextureButton).pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	assert(
		int(Dictionary(game_session.call("current_snapshot")).get("battle_round", 0))
		== main_before_round + 1
	)
	print("MOCK_BATTLE_PROJECT_SMOKE_PASS")
	quit(0)


func _assert_presentation_patterns_load() -> void:
	assert(FeatureRegistry.new() != null)
	assert(SceneRouter.new() != null)
	assert(BattleBoardController.new() != null)
	assert(BattleHudController.new() != null)
	assert(BattleDetailController.new() != null)
	assert(BattleCommandBuilder.new() != null)
	assert(BattleTraceProjection.new() != null)


func _assert_snapshot_contract(snapshot: Dictionary) -> void:
	for key in [
		"phase",
		"leaders",
		"units",
		"board",
		"roster",
		"inventory",
		"shop_offers",
		"viewModel",
	]:
		assert(snapshot.has(key))
	var board := Dictionary(snapshot.get("board", {}))
	assert(int(board.get("width", 0)) == 8)
	assert(int(board.get("height", 0)) == 8)
	assert(Array(board.get("cells", [])).size() == 64)
	assert(Array(snapshot.get("units", [])).size() == 8)
	for value in Array(snapshot.get("roster", [])):
		assert(value is Dictionary)


func _unit_position(snapshot: Dictionary, unit_id: String) -> Vector2i:
	for value in Array(snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", "")) == unit_id:
			return Vector2i(int(unit.get("x", -1)), int(unit.get("y", -1)))
	return Vector2i(-1, -1)
