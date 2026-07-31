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
const BattleProjectileScript := preload("res://core_ui/scripts/battle/prefabs/effects/battle_projectile.gd")
const BattleBiteVfxScript := preload("res://core_ui/scripts/battle/prefabs/effects/battle_bite_vfx.gd")
const BattleDamageNumberScript := preload("res://core_ui/scripts/battle/prefabs/effects/battle_damage_number.gd")
const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")
const BattleTerrainScene := preload("res://art/prefabs/terrain/terrain.tscn")

var _projectile_impact_count := 0
var _bite_hit_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_presentation_patterns_load()
	_assert_new_unit_assets()
	await _assert_defensive_stat_semantics()
	await _assert_prefab_effect_ownership()
	await _assert_hit_sync_primitives()
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

	var default_session := MockSession.new()
	assert(String(Dictionary(default_session.current_snapshot()).get("phase", "")) == "route")
	var isolated_session := MockSession.new({"start_phase": "battle"})
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
	var finished_response := Dictionary(isolated_session.submit_command({"type": "AUTO_POSITION_HEROES"}))
	assert(bool(finished_response.get("accepted", false)))
	assert(bool(Dictionary(finished_response.get("result", {})).get("mock_noop", false)))
	isolated_session.reset(false)
	assert(_same_snapshot_identity(isolated_session.current_snapshot(), captured_initial))
	var mismatch_response := Dictionary(isolated_session.submit_command({"type": "DROP_ITEM_ON_TARGET"}))
	assert(bool(mismatch_response.get("accepted", false)))
	assert(bool(Dictionary(mismatch_response.get("result", {})).get("mock_noop", false)))
	assert(_same_snapshot_identity(isolated_session.current_snapshot(), captured_initial))
	var direct_round_response := Dictionary(isolated_session.submit_command({"type": "RUN_COMBAT_ROUND"}))
	assert(bool(direct_round_response.get("accepted", false)))
	assert(int(direct_round_response.get("captureStep", 0)) == 2)
	assert(not isolated_session.supports_persistence())
	var session_source := FileAccess.get_file_as_string("res://session/mock_game_session.gd")
	assert(not session_source.contains("MOCK_ELEMENT_CELLS"))
	assert(not session_source.contains("_run_combat_round"))
	assert(not session_source.contains("_damage_trace"))

	var main_scene := load("res://art/scenes/three_choice/three_choice_scene.tscn") as PackedScene
	assert(main_scene != null)

	var route_main_instance := main_scene.instantiate()
	root.add_child(route_main_instance)
	for _frame in range(8):
		await process_frame
	await create_timer(0.25).timeout
	var route_game_session := route_main_instance.call("get_game_session") as RefCounted
	assert(route_game_session != null)
	assert(String(Dictionary(route_game_session.call("current_snapshot")).get("phase", "")) == "route")
	assert(route_main_instance.call("get_feature_controller", &"battle") == null)
	assert(route_main_instance.call("get_active_feature_view") == null)
	route_main_instance.queue_free()
	await process_frame

	var main_instance := main_scene.instantiate()
	main_instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main_instance)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await create_timer(1.0).timeout

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

	var visible_pet_count := 0
	var trimmed_pet_count := 0
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
		if not selected_first_pet:
			var grid := cell.call("get_grid_position") as Vector2i
			cell.cell_selected.emit(grid.x, grid.y)
			selected_first_pet = true
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	assert(visible_pet_count > 0)
	assert(trimmed_pet_count > 0)
	assert((battle_view.get_node("CellDetail/BattlePetDetailPanel") as Control).visible)

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
	assert(assets.pet_image_by_id.size() == 103)
	var cases := [
		[{"unitId": "player_hero", "unitName": "孙悟空"}, "hero_leader", "hero_wukong.png"],
		[{"unitId": "hero_tang_monk", "unitName": "唐僧"}, "hero_leader", "hero_tang_monk.png"],
		[{"unitId": "hero_rabbit", "unitName": "玉兔"}, "hero_leader", "hero_rabbit.png"],
		[{"unitId": "enemy_hero", "unitName": "蜘蛛精"}, "boss", "hero_spider.png"],
		[{"pet_id": "pal_103"}, "player", "shop_creature_103_earth_riftknuckle.png"],
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


func _assert_hit_sync_primitives() -> void:
	var projectile := BattleProjectileScript.new() as Node2D
	assert(projectile != null)
	assert(projectile.has_signal("impact_reached"))
	root.add_child(projectile)
	await process_frame
	_projectile_impact_count = 0
	projectile.connect("impact_reached", _on_test_projectile_impact)
	projectile.call("_finish_flight")
	projectile.call("_finish_flight")
	assert(_projectile_impact_count == 1)

	var bite := BattleBiteVfxScript.new() as Control
	assert(bite != null)
	assert(bite.has_signal("hit_frame_reached"))
	root.add_child(bite)
	await process_frame
	_bite_hit_count = 0
	bite.connect("hit_frame_reached", _on_test_bite_hit)
	bite.call("_emit_hit_if_needed")
	bite.call("_emit_hit_if_needed")
	assert(_bite_hit_count == 1)

	var damage_number := BattleDamageNumberScript.new() as Control
	assert(damage_number != null)
	root.add_child(damage_number)
	damage_number.size = Vector2(140.0, 40.0)
	damage_number.call("show_damage", 7)
	assert(String(damage_number.get("text")) == "-7")
	assert(is_equal_approx(damage_number.scale.x, 0.72))
	damage_number.queue_free()


func _assert_prefab_effect_ownership() -> void:
	var pet := BattleUnitScene.instantiate() as Control
	assert(pet != null)
	root.add_child(pet)
	await process_frame
	assert(pet.has_method("play_cross_cell_projectile"))
	assert(pet.has_method("play_damage_feedback"))
	assert(pet.has_method("play_grid_movement"))
	assert(pet.has_method("play_death_fade"))
	var projectile := pet.call(
		"play_cross_cell_projectile",
		"fire",
		Vector2(20.0, 20.0),
		Vector2(120.0, 80.0),
		0.32,
		72.0
	) as Node
	var damage := pet.call("play_damage_number", 7) as Node
	var bite := pet.call("play_bite_impact") as Node
	assert(projectile != null)
	assert(projectile.get_parent().name == "ProjectileLayer")
	assert(damage != null)
	assert(damage.get_parent().name == "DamageNumberLayer")
	assert(bite != null)
	assert(bite.get_parent().name == "HitLayer")

	var terrain := BattleTerrainScene.instantiate() as Control
	assert(terrain != null)
	root.add_child(terrain)
	await process_frame
	assert(terrain.has_method("play_element_impact"))
	var impact := terrain.call("play_element_impact", "fire", null, false) as Node
	assert(impact != null)
	assert(impact.get_parent().name == "ImpactLayer")
	assert(terrain.get_node_or_null("GroundElementEffects/PersistentMarker") != null)
	pet.queue_free()
	terrain.queue_free()
	await process_frame


func _on_test_projectile_impact() -> void:
	_projectile_impact_count += 1


func _on_test_bite_hit() -> void:
	_bite_hit_count += 1


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
