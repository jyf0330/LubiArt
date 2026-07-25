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
	var capture := _load_capture()
	var capture_source := Dictionary(capture.get("source", {}))
	assert(String(capture_source.get("project", "")) == "godot-latest")
	assert(String(capture_source.get("session", "")) == "LocalGameSession")
	assert(int(capture_source.get("load_slot", 0)) == 2)
	assert(String(Dictionary(capture_source.get("loaded_snapshot_identity", {})).get("stateHash", "")) != "")
	assert(Array(capture_source.get("button_cycle", [])) == [
		"AUTO_POSITION_HEROES",
		"RUN_COMBAT_ROUND",
	])
	var captured_steps := Array(capture.get("steps", []))
	var presentation_bootstrap := Dictionary(
		capture.get("presentation_bootstrap_snapshot", {})
	)
	assert(String(capture_source.get("capture_scope", "")) == "repeat_two_buttons_until_battle_end")
	assert(captured_steps.size() > 2)
	assert(captured_steps.size() % 2 == 0)
	assert(String(presentation_bootstrap.get("phase", "")) == "route")
	assert(
		String(presentation_bootstrap.get("run_seed", "")) \
		== "ysbzs-test-play-20260715-v1"
	)
	assert(String(presentation_bootstrap.get("stateHash", "")) != "")

	var isolated_session := MockSession.new()
	var boot_snapshot := Dictionary(isolated_session.current_snapshot())
	_assert_snapshot_contract(boot_snapshot)
	var captured_initial := Dictionary(capture.get("initial_snapshot", {}))
	assert(_same_snapshot_identity(boot_snapshot, captured_initial))
	assert(String(boot_snapshot.get("phase", "")) == "battle")
	assert(isolated_session.replay_step_count() == captured_steps.size())
	assert(isolated_session.capture_source() == capture_source)
	assert(
		isolated_session.presentation_bootstrap_snapshot() \
		== presentation_bootstrap
	)
	assert(not isolated_session.supports_persistence())
	assert(isolated_session.persistence_slot_count() == 3)
	for step_index in range(captured_steps.size()):
		var captured_step := Dictionary(captured_steps[step_index])
		var command := Dictionary(captured_step.get("command", {}))
		var response := Dictionary(isolated_session.submit_command(command))
		assert(bool(response.get("accepted", false)))
		assert(int(response.get("captureStep", 0)) == step_index + 1)
		var identity := Dictionary(captured_step.get("snapshot_identity", {}))
		var actual := Dictionary(isolated_session.current_snapshot())
		assert(int(actual.get("stateVersion", -1)) == int(identity.get("stateVersion", -2)))
		assert(String(actual.get("stateHash", "")) == String(identity.get("stateHash", "")))
		assert(String(actual.get("phase", "")) == String(identity.get("phase", "")))
	assert(String(Dictionary(isolated_session.current_snapshot()).get("phase", "")) == "battle_end")
	assert(
		not bool(Dictionary(
			isolated_session.submit_command({"type": "AUTO_POSITION_HEROES"})
		).get("accepted", true))
	)
	isolated_session.reset(false)
	assert(_same_snapshot_identity(isolated_session.current_snapshot(), captured_initial))
	assert(not isolated_session.supports_persistence())
	var session_source := FileAccess.get_file_as_string("res://session/mock_game_session.gd")
	assert(not session_source.contains("MOCK_ELEMENT_CELLS"))
	assert(not session_source.contains("_run_combat_round"))
	assert(not session_source.contains("_damage_trace"))

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
	assert(int(game_session.call("replay_step_index")) == 0)
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

	var player_unit_id := _first_player_unit_id(Dictionary(game_session.call("current_snapshot")))
	assert(player_unit_id != "")
	var main_before_position := _unit_position(
		Dictionary(game_session.call("current_snapshot")),
		player_unit_id
	)
	(battle_view.get_node("AutoArrangeButton") as TextureButton).pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	var main_positioned := Dictionary(game_session.call("current_snapshot"))
	assert(_unit_position(main_positioned, player_unit_id) != main_before_position)
	assert(int(game_session.call("replay_step_index")) == 1)

	var main_before_round := int(main_positioned.get("battle_round", 0))
	(battle_view.get_node("BeginTurnButton") as TextureButton).pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	assert(
		int(Dictionary(game_session.call("current_snapshot")).get("battle_round", 0))
		== main_before_round + 1
	)
	assert(int(game_session.call("replay_step_index")) == 2)
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
	var board_width := int(board.get("width", 0))
	var board_height := int(board.get("height", 0))
	assert(board_width > 0)
	assert(board_height > 0)
	assert(Array(board.get("cells", [])).size() == board_width * board_height)
	assert(not Array(snapshot.get("units", [])).is_empty())
	for value in Array(snapshot.get("roster", [])):
		assert(value is Dictionary)


func _load_capture() -> Dictionary:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/mock_battle_snapshot.json")
	)
	assert(parsed is Dictionary)
	return Dictionary(parsed)


func _same_snapshot_identity(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("stateVersion", -1)) == int(right.get("stateVersion", -2)) \
		and String(left.get("stateHash", "")) == String(right.get("stateHash", ""))


func _first_player_unit_id(snapshot: Dictionary) -> String:
	for value in Array(snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == "player":
			return String(unit.get("id", unit.get("unitId", "")))
	return ""


func _unit_position(snapshot: Dictionary, unit_id: String) -> Vector2i:
	for value in Array(snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", "")) == unit_id:
			return Vector2i(int(unit.get("x", -1)), int(unit.get("y", -1)))
	return Vector2i(-1, -1)
