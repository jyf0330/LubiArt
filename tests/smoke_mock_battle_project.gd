extends SceneTree

const MockSession := preload("res://session/mock_game_session.gd")
const FeatureRegistry := preload("res://core_ui/scripts/app/feature_registry.gd")
const SceneRouter := preload("res://core_ui/scripts/app/scene_router.gd")
const BattleBoardController := preload("res://core_ui/scripts/battle/controllers/battle_board_controller.gd")
const BattleHudController := preload("res://core_ui/scripts/battle/controllers/battle_hud_controller.gd")
const BattleDetailController := preload("res://core_ui/scripts/battle/controllers/battle_detail_controller.gd")
const BattleCommandBuilder := preload("res://core_ui/scripts/battle/controllers/battle_command_builder.gd")
const BattleTraceProjection := preload("res://core_ui/scripts/battle/controllers/battle_trace_projection.gd")
const BattleAssetRegistry := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")
const BattleTerrainScene := preload("res://art/prefabs/terrain/terrain.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_presentation_patterns_load()
	_assert_new_unit_assets()
	await _assert_defensive_stat_semantics()
	await _assert_damage_preview_cycle()
	await _assert_prefab_effect_ownership()
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
	var preview_unit_id := _first_player_unit_id(boot_snapshot)
	var direction_response := Dictionary(isolated_session.submit_command({
		"type": "SET_ACTION_DIRECTION",
		"unitId": preview_unit_id,
		"slotId": 1,
		"dir": "down",
	}))
	assert(bool(direction_response.get("accepted", false)))
	assert(int(isolated_session.replay_step_index()) == 0)
	assert(String(Dictionary(isolated_session.current_snapshot()).get("action_dirs", {}).get(
		"%s:slot1" % preview_unit_id,
		""
	)) == "down")
	isolated_session.reset(false)
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

	var main_scene := load("res://art/scenes/three_choice/three_choice_scene.tscn") as PackedScene
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
	var game_cursor := main_instance.get_node_or_null("GameCursor")
	assert(game_cursor != null)
	assert(game_cursor.get_node_or_null("CursorVisual") != null)
	assert(StringName(game_cursor.call("debug_state")) == &"pointer")
	game_cursor.call("set_pet_hover", true)
	assert(StringName(game_cursor.call("debug_state")) == &"pet_hover")
	game_cursor.call("set_grabbing", true)
	assert(StringName(game_cursor.call("debug_state")) == &"grabbing")
	game_cursor.call("set_loading_source", &"smoke", true)
	assert(StringName(game_cursor.call("debug_state")) == &"loading")
	game_cursor.call("set_loading_source", &"smoke", false)
	game_cursor.call("set_grabbing", false)
	game_cursor.call("set_pet_hover", false)
	assert(StringName(game_cursor.call("debug_state")) == &"pointer")

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	assert(battle_view != null)
	assert(battle_view.get_node_or_null("Board/BattleVfxPlayer") != null)
	assert(battle_view.get_node_or_null("Board/BattleActionPanel") != null)
	assert(battle_view.get_node_or_null("CellDetail/BattlePetDetailPanel") != null)

	var game_session := main_instance.call("get_game_session") as RefCounted
	assert(game_session != null)
	assert(String(Dictionary(game_session.call("current_snapshot")).get("phase", "")) == "battle")
	assert(int(game_session.call("replay_step_index")) == 0)
	var board_grid := battle_view.get_node("Board/BoardGrid") as Control
	assert(board_grid.get_child_count() == 64)
	assert(main_instance.call("get_active_view") == main_instance)
	assert(main_instance.call("get_active_feature_view") == battle_view)
	var direction_drawer := battle_view.get_node("Board/AttackDirectionDrawer") as Control
	var first_direction_state := Dictionary(Array(direction_drawer.call("debug_display_directions"))[0])
	var first_direction_unit_id := String(first_direction_state.get("unit_id", ""))
	var first_direction_arrow := direction_drawer.get_node("Rows/Row1/Arrow1") as TextureRect
	var wheel_down_event := InputEventMouseButton.new()
	wheel_down_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down_event.pressed = true
	wheel_down_event.factor = 1.0
	first_direction_arrow.gui_input.emit(wheel_down_event)
	await process_frame
	await process_frame
	var direction_snapshot := Dictionary(game_session.call("current_snapshot"))
	assert(String(Dictionary(direction_snapshot.get("action_dirs", {})).get(
		"%s:slot0" % first_direction_unit_id,
		""
	)) == "down")
	assert(int(game_session.call("replay_step_index")) == 0)
	var current_board := Dictionary(Dictionary(game_session.call("current_snapshot")).get("board", {}))
	var front_row_y := int(current_board.get("height", current_board.get("rows", 7))) - 1

	var visible_pet_count := 0
	var trimmed_pet_count := 0
	var front_row_pet_count := 0
	var back_row_pet_count := 0
	var selected_first_pet := false
	for cell in board_grid.get_children():
		var pet_view := cell.call("get_unit_node") as Control
		if pet_view == null or not pet_view.visible:
			continue
		visible_pet_count += 1
		assert(pet_view.size.is_equal_approx(cell.size))
		var visible_sprite_rect := Rect2(pet_view.call("get_battle_sprite_visible_rect"))
		var required_bottom_inset := float(pet_view.call("get_battle_footline_bottom_inset"))
		assert(visible_sprite_rect.size.x > 0.0)
		assert(is_equal_approx(
			pet_view.size.y - visible_sprite_rect.end.y,
			required_bottom_inset
		))
		var creature_art := pet_view.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
		var shadow := pet_view.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Shadow") as TextureRect
		assert(shadow.visible)
		assert(shadow.texture != null)
		assert(shadow.z_index < creature_art.z_index)
		assert(shadow.position.y >= 0.0)
		assert(shadow.position.y + shadow.size.y <= pet_view.size.y)
		var shadow_center_y := shadow.position.y + shadow.size.y * 0.5
		assert(shadow_center_y < pet_view.size.y - required_bottom_inset)
		assert(shadow_center_y >= pet_view.size.y - required_bottom_inset - 4.0)
		if int(pet_view.call("get_battle_removed_bottom_pixels")) > 0:
			trimmed_pet_count += 1
		var grid := cell.call("get_grid_position") as Vector2i
		var health_group := pet_view.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health") as Control
		_assert_cell_stat_badges(cell, pet_view)
		if grid.y == front_row_y:
			front_row_pet_count += 1
			assert(health_group.size == Vector2(38.0, 36.0))
			assert(health_group.scale == Vector2.ONE)
		else:
			back_row_pet_count += 1
			assert(health_group.scale.x < 1.0)
			assert(is_equal_approx(health_group.scale.x, health_group.scale.y))
		if not selected_first_pet:
			cell.cell_selected.emit(grid.x, grid.y)
			selected_first_pet = true
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	assert(visible_pet_count > 0)
	assert(trimmed_pet_count == 0)
	assert(front_row_pet_count > 0)
	assert(back_row_pet_count > 0)
	assert((battle_view.get_node("CellDetail/BattlePetDetailPanel") as Control).visible)
	assert(_visible_attack_highlight_count(board_grid) == 0)
	_assert_corner_heroes_are_locked(battle_view, board_grid, current_board)

	var drag_origin: Control = null
	var drag_target: Control = null
	var occupied_target: Control = null
	var blank_detail_target: Control = null
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell == null or not cell.visible:
			continue
		var unit_id := _cell_unit_id(cell)
		if drag_origin == null and unit_id != "" and bool(battle_view.call("_cell_has_draggable_player_unit", cell)):
			drag_origin = cell
		elif drag_target == null and unit_id == "":
			drag_target = cell
		elif occupied_target == null and unit_id != "":
			occupied_target = cell
		if blank_detail_target == null and unit_id == "":
			var candidate_grid := cell.call("get_grid_position") as Vector2i
			if not bool(battle_view.call("_cell_has_visible_elements", candidate_grid)):
				blank_detail_target = cell
	assert(drag_origin != null and drag_target != null and occupied_target != null and blank_detail_target != null)
	var blank_grid := blank_detail_target.call("get_grid_position") as Vector2i
	blank_detail_target.cell_selected.emit(blank_grid.x, blank_grid.y)
	await process_frame
	assert(not bool(Dictionary(battle_view.call("debug_detail_panel_summary")).get("visible", true)))

	var detail_grid := drag_origin.call("get_grid_position") as Vector2i
	drag_origin.cell_selected.emit(detail_grid.x, detail_grid.y)
	await process_frame
	await process_frame
	assert((battle_view.get_node("CellDetail/BattlePetDetailPanel") as Control).visible)
	var cancel_event := InputEventKey.new()
	cancel_event.keycode = KEY_ESCAPE
	cancel_event.pressed = true
	battle_view.call("_input", cancel_event)
	assert(not bool(Dictionary(battle_view.call("debug_detail_panel_summary")).get("visible", true)))

	var dragged_unit_id := _cell_unit_id(drag_origin)
	var drag_origin_grid := drag_origin.call("get_grid_position") as Vector2i
	var drag_target_grid := drag_target.call("get_grid_position") as Vector2i
	var occupied_grid := occupied_target.call("get_grid_position") as Vector2i
	var occupied_unit_id := _cell_unit_id(occupied_target)
	battle_view.call("_start_unit_drag", drag_origin_grid)
	assert(StringName(game_cursor.call("debug_state")) == &"grabbing")
	battle_view.call("_debug_update_drag_preview_position", drag_target_grid)
	assert(_visible_attack_highlight_count(board_grid) > 0)
	battle_view.call("_finish_unit_drag", drag_target_grid)
	assert(StringName(game_cursor.call("debug_state")) == &"pointer")
	assert(_cell_unit_id(drag_origin) == "")
	assert(_cell_unit_id(drag_target) == dragged_unit_id)
	assert(_visible_attack_highlight_count(board_grid) == 0)
	assert(int(game_session.call("replay_step_index")) == 0)
	await create_timer(0.2).timeout
	battle_view.call("_start_unit_drag", drag_target_grid)
	battle_view.call("_debug_update_drag_preview_position", occupied_grid)
	assert(not bool(occupied_target.call("is_hover_highlight_visible")))
	assert(_visible_attack_highlight_count(board_grid) == 0)
	battle_view.call("_finish_unit_drag", occupied_grid)
	assert(_cell_unit_id(drag_target) == dragged_unit_id)
	assert(_cell_unit_id(occupied_target) == occupied_unit_id)
	var rejected_drop := Dictionary(battle_view.call("debug_drop_settle_summary"))
	assert(bool(rejected_drop.get("returned", false)))
	assert(Dictionary(rejected_drop.get("settled", {})) == {"x": drag_target_grid.x, "y": drag_target_grid.y})
	await create_timer(0.2).timeout

	var player_unit_id := _first_player_unit_id(Dictionary(game_session.call("current_snapshot")))
	assert(player_unit_id != "")
	var main_before_position := _unit_position(
		Dictionary(game_session.call("current_snapshot")),
		player_unit_id
	)
	(battle_view.get_node("Board/BattlePrimaryActions/AutoArrangeButton") as TextureButton).pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	var main_positioned := Dictionary(game_session.call("current_snapshot"))
	assert(_unit_position(main_positioned, player_unit_id) != main_before_position)
	assert(int(game_session.call("replay_step_index")) == 1)
	_assert_active_damage_previews_synchronized(board_grid)

	var main_before_round := int(main_positioned.get("battle_round", 0))
	(battle_view.get_node("Board/BattlePrimaryActions/BeginTurnButton") as TextureButton).pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	assert(
		int(Dictionary(game_session.call("current_snapshot")).get("battle_round", 0))
		== main_before_round + 1
	)
	assert(int(game_session.call("replay_step_index")) == 2)
	var vfx_player := battle_view.get_node("Board/BattleVfxPlayer")
	var trace_deadline_msec := Time.get_ticks_msec() + 30000
	while bool(vfx_player.get("_trace_sequence_playing")) and Time.get_ticks_msec() < trace_deadline_msec:
		await process_frame
	assert(not bool(vfx_player.get("_trace_sequence_playing")))
	assert(Array(vfx_player.get("_trace_queue")).is_empty())
	print("MOCK_BATTLE_PROJECT_SMOKE_PASS")
	quit(0)


func _assert_presentation_patterns_load() -> void:
	assert(FeatureRegistry.new() != null)
	assert(SceneRouter.new() != null)
	assert(BattleBoardController.new() != null)
	assert(BattleHudController.new() != null)
	assert(BattleDetailController.new() != null)
	assert(BattleCommandBuilder.new() != null)
	var trace_projection := BattleTraceProjection.new()
	assert(trace_projection != null)
	var projected_cell := {"buffs": [{"active": false, "max_damage_per_hit": 99}]}
	trace_projection.copy_cell_unit_projection({
		"unitId": "moving_guard",
		"hp": 10,
		"shield": 2,
		"buffs": [{"active": true, "max_damage_per_hit": 8}],
	}, projected_cell)
	assert(int(Array(projected_cell.get("buffs", []))[0].get("max_damage_per_hit", 0)) == 8)
	trace_projection.clear_cell_unit_projection(projected_cell)
	assert(not projected_cell.has("buffs"))


func _assert_new_unit_assets() -> void:
	var assets := BattleAssetRegistry.new()
	assert(assets.all_declared_runtime_assets_exist())
	assert(assets.pet_image_by_id.size() == 8)
	var cases := [
		[{"unitId": "player_hero", "unitName": "孙悟空"}, "hero_leader", "hero_wukong.png"],
		[{"unitId": "hero_tang_monk", "unitName": "唐僧"}, "hero_leader", "hero_tang_monk.png"],
		[{"unitId": "hero_rabbit", "unitName": "玉兔"}, "hero_leader", "hero_rabbit.png"],
		[{"unitId": "enemy_hero", "unitName": "蜘蛛精"}, "boss", "hero_spider.png"],
		[{"pet_id": "pal_002"}, "player", "pet_style_001_gold_mascot.png"],
		[{"source_pet_id": "pal_042"}, "enemy", "pet_style_008_volcanic_dijiang.png"],
	]
	for test_case in cases:
		var result := Dictionary(assets.texture_for_unit(test_case[0], test_case[1]))
		var texture_resource := result.get("texture", null) as Texture2D
		assert(texture_resource != null)
		assert(texture_resource.resource_path.ends_with(test_case[2]))


func _assert_defensive_stat_semantics() -> void:
	var pet := BattleUnitScene.instantiate() as Control
	assert(pet != null)
	root.add_child(pet)
	await process_frame

	pet.call("set_unit_data", {
		"unitId": "defense_semantics_test",
		"hp": 20,
		"shield": 2,
		"atk": 5,
		"damageCap": 8,
		"threat": {"totalDamage": 10},
	}, "player", null)
	var lock_group := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/DamageCap") as Control
	var lock_value := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/DamageCap/Value_Text") as Label
	var shield_value := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield/Value_Text") as Label
	assert(lock_group.visible)
	assert(lock_value.text == "8")
	assert(shield_value.text == "2")

	pet.call("set_unit_data", {
		"unitId": "active_guard_test",
		"hp": 20,
		"shield": 2,
		"atk": 5,
		"buffs": [{"id": "pet_guard", "active": true, "max_damage_per_hit": 4}],
	}, "player", null)
	assert(lock_group.visible)
	assert(lock_value.text == "4")

	pet.call("set_unit_data", {
		"unitId": "no_cap_test",
		"hp": 20,
		"shield": 2,
		"atk": 5,
		"threat": {"totalDamage": 10},
	}, "player", null)
	assert(not lock_group.visible)
	assert(lock_value.text == "")
	assert(shield_value.text == "2")
	pet.queue_free()


func _assert_damage_preview_cycle() -> void:
	var pet := BattleUnitScene.instantiate() as Control
	assert(pet != null)
	root.add_child(pet)
	await process_frame
	pet.call("set_unit_data", {
		"unitId": "damage_preview_test",
		"hp": 20,
		"shield": 0,
		"atk": 5,
	}, "enemy", null)
	pet.call("start_damage_preview", 20, 7)
	var health_group := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health") as Control
	var health_icon := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/Icon") as TextureRect
	var health_value := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/Value_Text") as Label
	var group_modulate := health_group.modulate
	var icon_modulate := health_icon.modulate
	var preview := Dictionary(pet.call("get_damage_preview_snapshot"))
	assert(bool(preview.get("active", false)))
	assert(String(preview.get("state", "")) == "projected")
	assert(is_equal_approx(float(preview.get("projected_hold", 0.0)), 2.0))
	assert(is_equal_approx(float(preview.get("current_hold", 0.0)), 2.0))
	assert(health_value.text == "7")
	pet.call("_on_damage_preview_timeout")
	await create_timer(0.1).timeout
	assert(health_group.modulate == group_modulate)
	assert(health_icon.modulate == icon_modulate)
	await create_timer(0.22).timeout
	assert(health_value.text == "20")
	pet.call("_on_damage_preview_timeout")
	await create_timer(0.22).timeout
	assert(health_value.text == "7")
	pet.call("stop_damage_preview")
	assert(health_value.text == "20")
	assert(not bool(Dictionary(pet.call("get_damage_preview_snapshot")).get("active", true)))
	pet.queue_free()
	await process_frame


func _assert_prefab_effect_ownership() -> void:
	var pet := BattleUnitScene.instantiate() as Control
	assert(pet != null)
	root.add_child(pet)
	await process_frame
	assert(pet.has_method("play_cross_cell_projectile"))
	assert(pet.has_method("play_damage_feedback"))
	assert(pet.has_method("play_grid_movement"))
	assert(pet.has_method("play_death_fade"))
	assert(not pet.has_method("play_damage_number"))
	assert(pet.get_node_or_null("CompleteBattleCreaturePrefab/04_BattleEffects") == null)
	var action_root := pet.get_node("CompleteBattleCreaturePrefab/03_AttackActions")
	var authored_node_count := pet.find_children("*", "", true, false).size()
	var projectile := pet.call(
		"play_cross_cell_projectile",
		"fire",
		Vector2(20.0, 20.0),
		Vector2(120.0, 80.0),
		0.32,
		72.0
	) as Node
	assert(projectile != null)
	assert(projectile == action_root)
	var projectile_snapshot := Dictionary(pet.call("get_last_attack_action_snapshot"))
	assert(String(projectile_snapshot.get("projectile_node_path", "")).contains("/03_AttackActions/element_projectile/ProjectileArt"))
	assert(pet.get_node_or_null("CompleteBattleCreaturePrefab/03_AttackActions/element_projectile/ProjectileVariants") == null)
	var projectile_art := pet.get_node("CompleteBattleCreaturePrefab/03_AttackActions/element_projectile/ProjectileArt") as TextureRect
	var expected_projectile_paths := {
		"fire": "res://art/images/shared/pets/battle_complete/projectile_fire.png",
		"water": "res://art/images/shared/pets/battle_complete/projectile_water.png",
		"earth": "res://art/images/shared/pets/battle_complete/projectile_earth.png",
		"wind": "res://art/images/shared/pets/battle_complete/projectile_wind.png",
	}
	for element_id in ["fire", "water", "earth", "wind"]:
		pet.call("play_cross_cell_projectile", element_id, Vector2.ZERO, Vector2.ONE)
		assert(projectile_art.texture == load(String(expected_projectile_paths[element_id])))
	var bite := pet.call("play_bite_impact") as Node
	assert(bite != null)
	assert(bite == action_root)
	var bite_snapshot := Dictionary(pet.call("get_last_attack_action_snapshot"))
	assert(String(bite_snapshot.get("frame_node_path", "")).contains("/03_AttackActions/bite/frame_001/FrameArt"))
	assert(pet.find_children("*", "", true, false).size() == authored_node_count)

	var terrain := BattleTerrainScene.instantiate() as Control
	assert(terrain != null)
	root.add_child(terrain)
	await process_frame
	assert(pet.get_node_or_null("CompleteBattleCreaturePrefab/03_AttackActions/element_projectile/LandingTileVariants") == null)
	assert(terrain.get_node_or_null("GroundElementEffects/LandingTileVariants") == null)
	var tile_art := terrain.get_node_or_null("GroundElementEffects/LandingTileArt") as TextureRect
	assert(tile_art != null)
	assert(tile_art.size == terrain.size)
	var expected_tile_paths := {
		"fire": "res://art/images/shared/pets/battle_complete/landing_fire.png",
		"water": "res://art/images/shared/pets/battle_complete/landing_water.png",
		"earth": "res://art/images/shared/pets/battle_complete/landing_earth.png",
		"wind": "res://art/images/shared/pets/battle_complete/landing_wind.png",
	}
	for element_id in ["fire", "water", "earth", "wind"]:
		terrain.call("show_element_tile", element_id)
		assert(terrain.call("get_active_element_tile_variant") == element_id)
		assert(tile_art.texture == load(String(expected_tile_paths[element_id])))
	terrain.call("set_cell_data", {"elements": {"草": 2}}, null)
	assert(terrain.call("get_active_element_tile_variant") == "wind")
	assert(terrain.has_method("play_element_impact"))
	var impact := terrain.call("play_element_impact", "fire", false) as TextureRect
	assert(impact != null)
	assert(impact.get_parent().name == "ImpactLayer")
	assert(impact.texture == load("res://art/images/shared/pets/battle_complete/landing_fire.png"))
	assert(impact.size == terrain.size)
	pet.queue_free()
	terrain.queue_free()
	await process_frame


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


func _cell_unit_id(cell: Control) -> String:
	var data := Dictionary(cell.get("cell_data"))
	return String(data.get("unitId", data.get("unit_id", "")))


func _assert_corner_heroes_are_locked(
	battle_view: Control,
	board_grid: Control,
	board: Dictionary
) -> void:
	var board_width := int(board.get("width", board.get("columns", 8)))
	var board_height := int(board.get("height", board.get("rows", 7)))
	var expected_heroes := {
		Vector2i(0, board_height - 1): "player_hero",
		Vector2i(board_width - 1, 0): "enemy_boss",
	}
	for grid_value in expected_heroes:
		var grid := Vector2i(grid_value)
		var cell := _board_cell_at(board_grid, grid)
		assert(cell != null)
		assert(_cell_unit_id(cell) == String(expected_heroes[grid]))
		assert(not bool(battle_view.call("_cell_has_draggable_player_unit", cell)))
		battle_view.call("_start_unit_drag", grid)
		var drag_state := Dictionary(battle_view.call(
			"debug_update_drag_preview_to_target",
			{"x": grid.x, "y": grid.y}
		))
		assert(not bool(drag_state.get("dragging", true)))
		assert(not bool(drag_state.get("preview_was_active", true)))


func _board_cell_at(board_grid: Control, grid: Vector2i) -> Control:
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell != null and cell.visible and cell.call("get_grid_position") == grid:
			return cell
	return null


func _visible_attack_highlight_count(board_grid: Control) -> int:
	var count := 0
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell == null or not cell.visible:
			continue
		var highlight := cell.get_node_or_null("AttackHighlight") as Polygon2D
		if highlight != null and highlight.visible:
			count += 1
	return count


func _active_damage_preview_count(board_grid: Control) -> int:
	var count := 0
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var pet := cell.call("get_unit_node") as Control
		if pet == null or not pet.has_method("get_damage_preview_snapshot"):
			continue
		if bool(Dictionary(pet.call("get_damage_preview_snapshot")).get("active", false)):
			count += 1
	return count


func _assert_active_damage_previews_synchronized(board_grid: Control) -> void:
	var active_count := 0
	var shared_epoch_msec := -1
	var shared_state := ""
	var minimum_seconds_to_switch := INF
	var maximum_seconds_to_switch := 0.0
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var pet := cell.call("get_unit_node") as Control
		if pet == null or not pet.has_method("get_damage_preview_snapshot"):
			continue
		var preview := Dictionary(pet.call("get_damage_preview_snapshot"))
		if not bool(preview.get("active", false)):
			continue
		var epoch_msec := int(preview.get("sync_epoch_msec", -1))
		var state := String(preview.get("state", ""))
		var seconds_to_switch := float(preview.get("seconds_to_switch", 0.0))
		assert(epoch_msec >= 0)
		assert(is_equal_approx(float(preview.get("projected_hold", 0.0)), 2.0))
		assert(is_equal_approx(float(preview.get("current_hold", 0.0)), 2.0))
		if active_count == 0:
			shared_epoch_msec = epoch_msec
			shared_state = state
		else:
			assert(epoch_msec == shared_epoch_msec)
			assert(state == shared_state)
		minimum_seconds_to_switch = minf(minimum_seconds_to_switch, seconds_to_switch)
		maximum_seconds_to_switch = maxf(maximum_seconds_to_switch, seconds_to_switch)
		active_count += 1
	assert(active_count > 1)
	assert(maximum_seconds_to_switch - minimum_seconds_to_switch < 0.05)


func _assert_cell_stat_badges(cell: Control, pet: Control) -> void:
	var corners: PackedVector2Array = cell.get("polygon")
	assert(corners.size() == 4)
	var stats := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var health := stats.get_node("Health") as Control
	var shield := stats.get_node("Shield") as Control
	var attack := stats.get_node("Attack") as Control
	var damage_cap := stats.get_node("DamageCap") as Control
	_assert_stat_icon_inside_corner(health, 0, corners)
	_assert_stat_icon_inside_corner(damage_cap, 1, corners)
	_assert_stat_icon_inside_corner(shield, 2, corners)
	_assert_stat_icon_inside_corner(attack, 3, corners)


func _assert_stat_icon_inside_corner(
	group: Control,
	corner_index: int,
	corners: PackedVector2Array
) -> void:
	var icon := group.get_node("Icon") as Control
	var label := group.get_node("Value_Text") as Control
	var icon_bounds := Rect2(
		group.position + icon.position * group.scale,
		icon.size * group.scale
	)
	var is_top := corner_index <= 1
	var is_left := corner_index == 0 or corner_index == 3
	var side_top := corners[0] if is_left else corners[1]
	var side_bottom := corners[3] if is_left else corners[2]
	var side_x_at_top := _stat_edge_x_at_y(side_top, side_bottom, icon_bounds.position.y)
	var side_x_at_bottom := _stat_edge_x_at_y(side_top, side_bottom, icon_bounds.end.y)
	assert(is_equal_approx(
		icon_bounds.position.y if is_top else icon_bounds.end.y,
		corners[corner_index].y
	))
	var expected_side_x := maxf(side_x_at_top, side_x_at_bottom) if is_left else \
		minf(side_x_at_top, side_x_at_bottom)
	assert(is_equal_approx(
		icon_bounds.position.x if is_left else icon_bounds.end.x,
		expected_side_x
	))
	assert(is_zero_approx(group.rotation))
	assert(is_zero_approx(label.rotation))


func _stat_edge_x_at_y(edge_start: Vector2, edge_end: Vector2, y: float) -> float:
	if is_zero_approx(edge_end.y - edge_start.y):
		return edge_start.x
	var weight := clampf((y - edge_start.y) / (edge_end.y - edge_start.y), 0.0, 1.0)
	return lerpf(edge_start.x, edge_end.x, weight)
