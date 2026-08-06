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
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")


class RoutingSession:
	extends RefCounted

	signal snapshot_received(snapshot: Dictionary, metadata: Dictionary)

	var _route_snapshot: Dictionary
	var _battle_snapshot: Dictionary
	var _snapshot: Dictionary


	func _init(route_snapshot: Dictionary, battle_snapshot: Dictionary) -> void:
		_route_snapshot = route_snapshot.duplicate(true)
		_battle_snapshot = battle_snapshot.duplicate(true)
		_snapshot = _route_snapshot.duplicate(true)


	func current_snapshot() -> Dictionary:
		return _snapshot.duplicate(true)


	func submit_command_and_wait(command: Dictionary) -> Dictionary:
		match String(command.get("type", "")):
			"TEST_ENTER_BATTLE":
				_snapshot = _battle_snapshot.duplicate(true)
			"TEST_LEAVE_BATTLE":
				_snapshot = _route_snapshot.duplicate(true)
		return {
			"accepted": true,
			"command": String(command.get("type", "")),
			"snapshot": current_snapshot()
		}


	func supports_persistence() -> bool:
		return false


	func persistence_slot_count() -> int:
		return 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_presentation_patterns_load()
	_assert_new_unit_assets()
	await _assert_defensive_stat_semantics()
	await _assert_damage_preview_cycle()
	await _assert_incoming_damage_badge()
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

	var default_session := MockSession.new()
	assert(String(Dictionary(default_session.current_snapshot()).get("phase", "")) == "route")
	var isolated_session := MockSession.new({"start_phase": "battle"})
	var boot_snapshot := Dictionary(isolated_session.current_snapshot())
	_assert_snapshot_contract(boot_snapshot)
	var boot_skill_queue := Array(boot_snapshot.get("skillControlBar", []))
	assert(boot_skill_queue.size() == 8)
	assert(_skill_bar_unit_ids(boot_skill_queue).size() == 4)
	assert(_skill_bar_slots(boot_skill_queue) == ["a", "b", "a", "b", "a", "b", "a", "b"])
	assert(Array(boot_snapshot.get("selectedTraits", [])).size() == 1)
	assert(Array(boot_snapshot.get("selectedSkillCombos", [])).size() == 1)
	var reversed_entry_ids: Array = []
	var default_entry_ids := _skill_control_entry_ids(boot_skill_queue)
	for index in range(1, default_entry_ids.size(), 2):
		reversed_entry_ids.append(default_entry_ids[index])
	for index in range(0, default_entry_ids.size(), 2):
		reversed_entry_ids.append(default_entry_ids[index])
	var reorder_response := Dictionary(isolated_session.submit_command({
		"type": "SET_SKILL_CONTROL_ORDER",
		"orderedEntryIds": reversed_entry_ids,
	}))
	assert(bool(reorder_response.get("accepted", false)))
	assert(_skill_control_entry_ids(Array(isolated_session.current_snapshot().get("skillControlBar", []))) == reversed_entry_ids)
	assert(Array(isolated_session.current_snapshot().get("selectedSkillCombos", [])).is_empty())
	assert(isolated_session.replay_step_index() == 0)
	isolated_session.reset(false)
	boot_snapshot = Dictionary(isolated_session.current_snapshot())
	var captured_initial := Dictionary(capture.get("initial_snapshot", {}))
	assert(_same_snapshot_identity(boot_snapshot, captured_initial))
	assert(String(boot_snapshot.get("phase", "")) == "battle")
	assert(not _has_dictionary_key_with_prefix(boot_snapshot, "mock_"))
	assert(_public_target_preview_count(boot_snapshot) > 0)
	assert(Dictionary(boot_snapshot.get("placement_damage_by_unit", {})).is_empty())
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
	var finished_response := Dictionary(isolated_session.submit_command({"type": "AUTO_POSITION_HEROES"}))
	assert(bool(finished_response.get("accepted", false)))
	assert(bool(Dictionary(finished_response.get("result", {})).get("mock_noop", false)))
	isolated_session.reset(false)
	assert(_same_snapshot_identity(isolated_session.current_snapshot(), captured_initial))
	var mismatch_response := Dictionary(isolated_session.submit_command({"type": "DROP_ITEM_ON_TARGET"}))
	assert(bool(mismatch_response.get("accepted", false)))
	assert(bool(Dictionary(mismatch_response.get("result", {})).get("mock_noop", false)))
	assert(_same_snapshot_identity(isolated_session.current_snapshot(), captured_initial))
	var inventory_presenter: RefCounted = load("res://core_ui/scripts/inventory/presenters/inventory_presenter.gd").new()
	var sparse_bag_page := Dictionary(inventory_presenter.call("page", {
		"roster": [
			{"id": "active_pet", "active": true, "slot": 1},
			{"id": "bag_slot_5_pet", "active": false, "bag_slot": 5},
			{"id": "bag_slot_1_pet", "active": false, "bag_slot": 1},
		],
	}, 0, 8))
	var sparse_bag_items := Array(sparse_bag_page.get("items", []))
	assert(sparse_bag_items.size() == 8)
	assert(Dictionary(sparse_bag_items[0]).is_empty())
	assert(String(Dictionary(sparse_bag_items[1]).get("id", "")) == "bag_slot_1_pet")
	assert(Dictionary(sparse_bag_items[2]).is_empty())
	assert(String(Dictionary(sparse_bag_items[5]).get("id", "")) == "bag_slot_5_pet")
	assert(int(sparse_bag_page.get("total_count", 0)) == 2)
	var direct_round_response := Dictionary(isolated_session.submit_command({"type": "RUN_COMBAT_ROUND"}))
	assert(bool(direct_round_response.get("accepted", false)))
	assert(int(direct_round_response.get("captureStep", 0)) == 2)
	assert(not isolated_session.supports_persistence())
	var session_source := FileAccess.get_file_as_string("res://session/mock_game_session.gd")
	assert(not session_source.contains("MOCK_ELEMENT_CELLS"))
	assert(not session_source.contains("_run_combat_round"))
	assert(not session_source.contains("_damage_trace"))

	var three_choice_scene := load("res://art/scenes/three_choice/three_choice_scene.tscn") as PackedScene
	assert(three_choice_scene != null)
	var three_choice_source := FileAccess.get_file_as_string("res://art/scenes/three_choice/three_choice_scene.tscn")
	assert(three_choice_source.count("[ext_resource type=\"Script\"") == 1)
	assert(three_choice_source.contains("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd"))
	assert(not three_choice_source.contains("game_controller.gd"))
	assert(not three_choice_source.contains("three_choice_surface.gd"))
	assert(not three_choice_source.contains("artist_flow_controller.gd"))
	assert(three_choice_source.contains("[node name=\"ItemSlotHoverHighlight\" type=\"TextureRect\" parent=\".\""))
	assert(not three_choice_source.contains("[node name=\"DragPreview\""))
	assert(not three_choice_source.contains("[node name=\"AnimationPlayer\""))
	assert(not three_choice_source.contains("[node name=\"Shop_Slot\""))
	assert(not three_choice_source.contains("[node name=\"Bag_Slot\""))
	assert(three_choice_source.contains("[node name=\"Party_Slot\" type=\"TextureButton\" parent=\"MainBG/Containers/Party/Party_Container\""))
	for index in range(2, 5):
		assert(three_choice_source.contains("[node name=\"Party_Slot%d\" type=\"TextureButton\" parent=\"MainBG/Containers/Party/Party_Container\"" % index))
	assert(not three_choice_source.contains("res://art/prefabs/pet/pet.tscn"))
	assert(three_choice_source.count("instance=ExtResource(\"5_card\")") == 3)
	var asset_registry_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/artist_flow_asset_registry.gd")
	assert(asset_registry_source.contains("route_portrait_shop.png"))
	assert(asset_registry_source.contains("route_portrait_event.png"))
	assert(asset_registry_source.contains("route_portrait_reward.png"))
	_assert_three_choice_scene_hierarchy(three_choice_source)
	var three_choice_script_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd")
	var three_choice_drag_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")
	assert(not three_choice_script_source.contains("_ensure_item_slot_hover_highlight"))
	assert(not three_choice_script_source.contains("ThreeChoiceCardScene.instantiate()"))
	assert(three_choice_script_source.contains("TextureButton.new()"))
	assert(three_choice_drag_source.contains("TextureRect.new()"))
	assert(three_choice_script_source.contains("signal presentation_settled"))
	assert(not three_choice_script_source.contains("feature_view_requested"))
	assert(not three_choice_script_source.contains("feature_view_release_requested"))
	assert(not three_choice_script_source.contains("_ensure_battle_view"))
	assert(not three_choice_script_source.contains("battle_art_scene.tscn"))
	_assert_three_choice_runtime_slot_policy(three_choice_script_source)
	var card_script_source := FileAccess.get_file_as_string("res://core_ui/scripts/route/prefabs/three_choice_card.gd")
	assert(not card_script_source.contains("SLOT_LAYOUTS"))
	assert(not card_script_source.contains("_apply_slot_layout"))
	assert(not card_script_source.contains("@tool"))
	var pet_detail_scene_source := FileAccess.get_file_as_string("res://art/prefabs/pet/pet_detail.tscn")
	var pet_detail_script_source := FileAccess.get_file_as_string("res://core_ui/scripts/shared/pet/pet_detail_panel.gd")
	assert(not pet_detail_scene_source.contains("DebugPanel"))
	assert(not pet_detail_scene_source.contains("DebugToggleButton"))
	assert(not pet_detail_scene_source.contains("pet_info_debug_panel.gd"))
	assert(not pet_detail_script_source.contains("SessionFactory"))
	assert(not pet_detail_script_source.contains("set_debug_enabled"))
	assert(not three_choice_script_source.contains("PET_DETAIL_PANEL_SCENE.instantiate"))
	var main_scene := load("res://art/scenes/app/game.tscn") as PackedScene
	assert(main_scene != null)
	var game_scene_source := FileAccess.get_file_as_string("res://art/scenes/app/game.tscn")
	var game_script_source := FileAccess.get_file_as_string("res://core_ui/scripts/app/game_controller.gd")
	var router_script_source := FileAccess.get_file_as_string("res://core_ui/scripts/app/scene_router.gd")
	var bridge_script_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd")
	assert(game_scene_source.count("[ext_resource type=\"Script\"") == 1)
	assert(game_script_source.contains("_required_feature_for_snapshot"))
	assert(game_script_source.contains("_prepare_feature_for_snapshot"))
	assert(game_script_source.contains("_release_features_not_required"))
	assert(game_script_source.contains("SceneRouterScript.new(feature_host, feature_registry)"))
	assert(not game_script_source.contains("_on_feature_view_requested"))
	assert(not game_script_source.contains("_on_feature_view_release_requested"))
	assert(not router_script_source.contains("snapshot"))
	assert(not router_script_source.contains("phase"))
	assert(not router_script_source.contains("session"))
	assert(not bridge_script_source.contains("SessionFactory"))
	assert(not bridge_script_source.contains("create_local("))
	var battle_scene := load("res://art/scenes/battle/battle_art_scene.tscn") as PackedScene
	assert(battle_scene != null)
	var battle_scene_source := FileAccess.get_file_as_string("res://art/scenes/battle/battle_art_scene.tscn")
	var battle_script_source := FileAccess.get_file_as_string("res://core_ui/scripts/battle/scenes/battle_scene.gd")
	assert(battle_scene_source.contains("res://core_ui/scripts/battle/scenes/battle_scene.gd"))
	assert(not battle_script_source.contains("SessionFactoryScript"))
	assert(not battle_script_source.contains("create_local("))
	assert(not battle_script_source.contains("submit_command_and_wait"))
	assert(not battle_script_source.contains("func get_game_session"))

	var standalone_battle_instance := battle_scene.instantiate() as Control
	root.add_child(standalone_battle_instance)
	var standalone_battle_session := MockSession.new({"start_phase": "battle"})
	standalone_battle_instance.call("render_snapshot", standalone_battle_session.current_snapshot())
	for _frame in range(8):
		await process_frame
	var standalone_battle_snapshot := Dictionary(standalone_battle_session.call("current_snapshot"))
	var standalone_probe := BattleSceneProbe.new(standalone_battle_instance)
	assert(standalone_probe.is_ready())
	assert(String(standalone_battle_snapshot.get("phase", "")) == "battle")
	assert(Array(standalone_battle_snapshot.get("units", [])).size() > 0)
	assert(Array(Dictionary(standalone_battle_snapshot.get("board", {})).get("cells", [])).size() > 0)
	assert(standalone_probe.rendered_cell_count() > 0)
	var standalone_commands: Array[Dictionary] = []
	standalone_battle_instance.connect("command_requested", func(command: Dictionary) -> void:
		standalone_commands.append(command.duplicate(true))
	)
	standalone_probe.press_hud_command(&"AUTO_POSITION_HEROES")
	await process_frame
	assert(standalone_commands.size() == 1)
	assert(String(standalone_commands[0].get("type", "")) == "AUTO_POSITION_HEROES")
	var first_auto_response := Dictionary(standalone_battle_session.call(
		"submit_command",
		standalone_commands[0]
	))
	standalone_battle_instance.call(
		"render_command_response",
		standalone_commands[0],
		first_auto_response
	)
	standalone_battle_instance.call("render_snapshot", first_auto_response.get("snapshot", {}))
	await process_frame
	assert(int(standalone_battle_session.call("replay_step_index")) == 1)
	standalone_probe.press_hud_command(&"AUTO_POSITION_HEROES")
	await process_frame
	assert(standalone_commands.size() == 2)
	var repeated_auto_response := Dictionary(standalone_battle_session.call(
		"submit_command",
		standalone_commands[1]
	))
	assert(bool(Dictionary(repeated_auto_response.get("result", {})).get("mock_noop", false)))
	standalone_battle_instance.call(
		"render_command_response",
		standalone_commands[1],
		repeated_auto_response
	)
	await process_frame
	var standalone_difficulty_button := standalone_battle_instance.get_node(
		"Hud/BattleActionPanel/Margin/Content/PositionDifficultyButton"
	) as Button
	assert(standalone_difficulty_button.text != "摆位计算中…")
	assert(standalone_difficulty_button.text.contains("未执行"))
	assert(not standalone_difficulty_button.disabled)
	standalone_battle_instance.queue_free()
	await process_frame

	var startup_main_instance := main_scene.instantiate()
	root.add_child(startup_main_instance)
	for _frame in range(8):
		await process_frame
	var startup_session := startup_main_instance.call("get_game_session") as RefCounted
	assert(startup_session != null)
	assert(String(Dictionary(startup_session.call("current_snapshot")).get("phase", "")) == "battle")
	assert(StringName(startup_main_instance.call("get_active_feature_id")) == &"battle")
	assert(startup_main_instance.call("get_active_feature_view") != null)
	startup_main_instance.queue_free()
	await process_frame

	var route_main_instance := main_scene.instantiate()
	route_main_instance.call("set_game_session", MockSession.new({"start_phase": "route"}))
	root.add_child(route_main_instance)
	for _frame in range(8):
		await process_frame
	await create_timer(0.25).timeout
	var route_game_session := route_main_instance.call("get_game_session") as RefCounted
	assert(route_game_session != null)
	var route_three_choice_view := route_main_instance.call("get_three_choice_view") as Control
	assert(route_three_choice_view != null)
	assert(not route_three_choice_view.has_method("get_game_session"))
	var route_snapshot := Dictionary(route_game_session.call("current_snapshot"))
	assert(String(route_snapshot.get("phase", "")) == "route")
	assert(Array(route_snapshot.get("route_options", [])).size() == 3)
	assert(Array(route_snapshot.get("roster", [])).size() > 0)
	assert(int(Dictionary(route_snapshot.get("inventory", {})).get("max_bench", 0)) > 0)
	assert(route_three_choice_view.get_node_or_null("DragPreview") == null)
	var route_card_grid := route_three_choice_view.get_node("MainBG/Containers/Middle/Middle_Three_Option/CardGrid")
	assert(route_card_grid.get_child_count() == 3)
	var shop_slot_grid := route_three_choice_view.get_node("MainBG/Containers/Middle/Middle_Shop/Slots")
	var bag_slot_grid := route_three_choice_view.get_node("MainBG/Containers/Middle/Middle_Bag/Slots")
	var party_slot_grid := route_three_choice_view.get_node("MainBG/Containers/Party/Party_Container")
	assert(shop_slot_grid.get_child_count() == 8)
	assert(bag_slot_grid.get_child_count() == 8)
	assert(party_slot_grid.get_child_count() == 4)
	assert(shop_slot_grid.get_child(0) is TextureButton)
	assert(bag_slot_grid.get_child(0) is TextureButton)
	assert(party_slot_grid.get_child(0) is TextureButton)
	assert(shop_slot_grid.get_child(0).get_child_count() == 0)
	assert(bag_slot_grid.get_child(0).get_child_count() == 0)
	assert(party_slot_grid.get_child(0).get_child_count() == 0)
	var drag_controller := route_three_choice_view.get("_drag_controller") as RefCounted
	assert(drag_controller != null)
	assert(bool(drag_controller.call("begin_storage", &"party", 0, true, true)))
	var drag_preview := route_three_choice_view.get_node("DragPreview") as TextureRect
	assert(drag_preview.visible)
	assert(drag_preview.texture != null)
	assert(drag_preview.size.is_equal_approx(Vector2(96, 96)))
	drag_controller.call("clear")
	await process_frame
	assert(route_three_choice_view.get_node_or_null("DragPreview") == null)
	assert(route_main_instance.call("get_feature_controller", &"battle") == null)
	assert(route_main_instance.call("get_active_feature_view") == null)
	route_main_instance.queue_free()
	await process_frame

	var routing_session := RoutingSession.new(
		MockSession.new().current_snapshot(),
		MockSession.new({"start_phase": "battle"}).current_snapshot()
	)
	var routing_main_instance := main_scene.instantiate()
	routing_main_instance.call("set_game_session", routing_session)
	root.add_child(routing_main_instance)
	for _frame in range(8):
		await process_frame
	var routing_view := routing_main_instance.call("get_three_choice_view") as Control
	assert(routing_main_instance.call("get_active_feature_view") == null)
	routing_view.command_requested.emit({"type": "TEST_ENTER_BATTLE"}, 7001)
	for _frame in range(8):
		await process_frame
	assert(StringName(routing_main_instance.call("get_active_feature_id")) == &"battle")
	assert(routing_main_instance.call("get_active_feature_view") != null)
	routing_view.command_requested.emit({"type": "TEST_LEAVE_BATTLE"}, 7002)
	for _frame in range(4):
		await process_frame
	assert(routing_main_instance.call("get_active_feature_view") != null)
	routing_view.call("render_snapshot", routing_session.current_snapshot(), false)
	await process_frame
	assert(routing_main_instance.call("get_active_feature_view") == null)
	routing_main_instance.queue_free()
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
	var game_cursor := main_instance.get_node_or_null("GameCursor")
	assert(game_cursor != null)
	var cursor_visual := game_cursor.get_node_or_null("CursorVisual") as Control
	assert(cursor_visual != null)
	assert(not cursor_visual.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
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
	var battle_probe := BattleSceneProbe.new(battle_view)
	assert(battle_probe.is_ready())
	assert(battle_view.get_node_or_null("Board/VfxHost") != null)
	var action_panel := battle_view.get_node_or_null("Hud/BattleActionPanel") as Control
	assert(action_panel != null)
	assert(action_panel.get_node_or_null("Margin/Content/FlowState") != null)
	assert(action_panel.get_node_or_null("Margin/Content/MapDebugButton") != null)
	assert(action_panel.get_node_or_null("Margin/Content/PositionDifficultyButton") != null)
	assert(battle_view.get_node_or_null("Hud/DebugDrawerToggleButton") != null)
	assert(battle_view.get_node("Hud/BattleActionPanel/Margin/Content/SkillQueueGrid").get_child_count() == 8)
	assert(battle_view.get_node_or_null("OverlayHost/BattlePetDetailPanel") != null)

	var game_session := main_instance.call("get_game_session") as RefCounted
	assert(game_session != null)
	assert(not battle_view.has_method("get_game_session"))
	assert(String(Dictionary(game_session.call("current_snapshot")).get("phase", "")) == "battle")
	var reset_button := battle_view.get_node("MapControls/ResetButton") as TextureButton
	var reset_cooldown_label := reset_button.get_node("ResetCooldownLabel") as Label
	assert(int(reset_button.get_meta("charges")) == 1)
	assert(not bool(reset_button.get_meta("cooling_down")))
	assert(not bool(reset_button.get_meta("waiting_for_charge")))
	assert(not reset_cooldown_label.visible)
	assert(reset_cooldown_label.text == "")
	assert(int(game_session.call("replay_step_index")) == 0)
	var board_grid := battle_view.get_node("Board/CellHost") as Control
	assert(board_grid.get_child_count() == 56)
	assert(main_instance.call("get_active_view") == main_instance)
	assert(main_instance.call("get_active_feature_view") == battle_view)
	var replay_step_before_empty_select := int(game_session.call("replay_step_index"))
	var empty_select_response := Dictionary(game_session.call(
		"submit_command",
		{"type": "SELECT_CELL", "x": 4, "y": 4}
	))
	assert(not bool(empty_select_response.get("accepted", true)))
	assert(int(game_session.call("replay_step_index")) == replay_step_before_empty_select)
	assert(battle_view.get_node_or_null("Hud/AttackDirectionDrawer") == null)
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
		_assert_cell_stat_column(cell, pet_view)
		if grid.y == front_row_y:
			front_row_pet_count += 1
			assert(health_group.size.is_equal_approx(Vector2(88.0, 24.0)))
			assert(health_group.scale == Vector2.ONE)
		else:
			back_row_pet_count += 1
			assert(health_group.scale.x < 1.0)
			assert(is_equal_approx(health_group.scale.x, health_group.scale.y))
		if not selected_first_pet and bool(cell.call("has_player_unit")):
			cell.cell_selected.emit(grid.x, grid.y)
			selected_first_pet = true
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	assert(visible_pet_count > 0)
	assert(trimmed_pet_count == 0)
	assert(front_row_pet_count > 0)
	assert(back_row_pet_count > 0)
	assert((battle_view.get_node("OverlayHost/BattlePetDetailPanel") as Control).visible)
	assert(int(game_session.call("replay_step_index")) == 0)
	var selected_snapshot := Dictionary(game_session.call("current_snapshot"))
	assert(String(selected_snapshot.get("selected_unit_id", "")) != "")
	var preview_state := Dictionary(action_panel.call("visual_state_summary"))
	assert(String(preview_state.get("state", "")) == "preview")
	assert(String(preview_state.get("flow_text", "")).contains("红色范围"))
	var first_skill_slot := action_panel.get_node("Margin/Content/SkillQueueGrid/SkillSlot1") as Button
	first_skill_slot.pressed.emit()
	assert(bool(first_skill_slot.call("is_picked")))
	assert(int(Dictionary(action_panel.call("visual_state_summary")).get("picked_skill_index", -1)) == 0)
	first_skill_slot.pressed.emit()
	assert(not bool(first_skill_slot.call("is_picked")))
	var range_summary := battle_probe.selected_action_range_summary(selected_snapshot)
	assert(String(range_summary.get("unitId", "")) == String(selected_snapshot.get("selected_unit_id", "")))
	assert(int(range_summary.get("visibleCellCount", 0)) > 0)
	assert(_visible_range_fill_count(board_grid) == int(range_summary.get("visibleCellCount", 0)))
	assert(_visible_attack_highlight_count(board_grid) == 0)
	_assert_corner_heroes_are_locked(battle_probe, board_grid, current_board)

	var drag_origin: Control = null
	var drag_target: Control = null
	var occupied_target: Control = null
	var blank_detail_target: Control = null
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell == null or not cell.visible:
			continue
		var unit_id := _cell_unit_id(cell)
		if drag_origin == null and _cell_data_is_draggable(Dictionary(cell.get("cell_data"))):
			drag_origin = cell
		elif drag_target == null and unit_id == "":
			drag_target = cell
		elif occupied_target == null and unit_id != "":
			occupied_target = cell
		if blank_detail_target == null and unit_id == "":
			if not _has_visible_elements(Dictionary(cell.get("cell_data")).get("elements", {})):
				blank_detail_target = cell
	var preferred_drag_case := battle_probe.first_player_drag_case(
		Dictionary(game_session.call("current_snapshot"))
	)
	if not preferred_drag_case.is_empty():
		var preferred_origin := Dictionary(preferred_drag_case.get("origin", {}))
		var preferred_target := Dictionary(preferred_drag_case.get("target", {}))
		drag_origin = battle_probe.cell_at(Vector2i(
			int(preferred_origin.get("x", -1)), int(preferred_origin.get("y", -1))
		))
		drag_target = battle_probe.cell_at(Vector2i(
			int(preferred_target.get("x", -1)), int(preferred_target.get("y", -1))
		))
	for cell_value in board_grid.get_children():
		var occupied_candidate := cell_value as Control
		if occupied_candidate != null and occupied_candidate != drag_origin \
				and occupied_candidate != drag_target and _cell_unit_id(occupied_candidate) != "":
			occupied_target = occupied_candidate
			break
	assert(drag_origin != null and drag_target != null and occupied_target != null and blank_detail_target != null)
	var blank_grid := blank_detail_target.call("get_grid_position") as Vector2i
	blank_detail_target.cell_selected.emit(blank_grid.x, blank_grid.y)
	await process_frame
	assert(not bool(battle_probe.detail_summary().get("visible", true)))

	var detail_grid := drag_origin.call("get_grid_position") as Vector2i
	drag_origin.cell_selected.emit(detail_grid.x, detail_grid.y)
	await process_frame
	await process_frame
	assert((battle_view.get_node("OverlayHost/BattlePetDetailPanel") as Control).visible)
	var cancel_event := InputEventKey.new()
	cancel_event.keycode = KEY_ESCAPE
	cancel_event.pressed = true
	battle_view.get_viewport().push_input(cancel_event, true)
	await process_frame
	assert(not bool(battle_probe.detail_summary().get("visible", true)))

	var dragged_unit_id := _cell_unit_id(drag_origin)
	var drag_origin_grid := drag_origin.call("get_grid_position") as Vector2i
	var drag_target_grid := drag_target.call("get_grid_position") as Vector2i
	var occupied_grid := occupied_target.call("get_grid_position") as Vector2i
	var occupied_unit_id := _cell_unit_id(occupied_target)
	assert(bool(battle_probe.start_drag(drag_origin_grid, drag_target_grid).get("started", false)))
	assert(StringName(game_cursor.call("debug_state")) == &"grabbing")
	await battle_probe.update_drag(drag_target_grid, Dictionary(game_session.call("current_snapshot")))
	assert(_visible_attack_highlight_count(board_grid) > 0)
	var move_command := battle_probe.finish_drag(drag_target_grid)
	assert(String(move_command.get("type", "")) == "MOVE_HERO")
	assert(String(move_command.get("unitId", "")) == dragged_unit_id)
	assert(StringName(game_cursor.call("debug_state")) == &"pointer")
	assert(_cell_unit_id(drag_origin) == "")
	assert(_cell_unit_id(drag_target) == dragged_unit_id)
	assert(_visible_attack_highlight_count(board_grid) == 0)
	assert(int(game_session.call("replay_step_index")) == 0)
	await create_timer(0.2).timeout
	assert(bool(battle_probe.start_drag(drag_target_grid, occupied_grid).get("started", false)))
	await battle_probe.update_drag(occupied_grid, Dictionary(game_session.call("current_snapshot")))
	assert(not bool(occupied_target.call("is_hover_highlight_visible")))
	assert(_visible_attack_highlight_count(board_grid) == 0)
	var rejected_command := battle_probe.finish_drag(occupied_grid)
	assert(rejected_command.is_empty())
	assert(_cell_unit_id(drag_target) == dragged_unit_id)
	assert(_cell_unit_id(occupied_target) == occupied_unit_id)
	await create_timer(0.2).timeout

	var player_unit_id := _first_player_unit_id(Dictionary(game_session.call("current_snapshot")))
	assert(player_unit_id != "")
	var main_before_position := _unit_position(
		Dictionary(game_session.call("current_snapshot")),
		player_unit_id
	)
	(battle_view.get_node("MapControls/AutoArrangeButton") as TextureButton).pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	var main_positioned := Dictionary(game_session.call("current_snapshot"))
	assert(_unit_position(main_positioned, player_unit_id) != main_before_position)
	assert(int(game_session.call("replay_step_index")) == 1)
	_assert_active_damage_previews_synchronized(board_grid)

	var main_before_round := int(main_positioned.get("battle_round", 0))
	(battle_view.get_node("MapControls/AllOutButton") as TextureButton).pressed.emit()
	await process_frame
	assert(String(Dictionary(action_panel.call("visual_state_summary")).get("state", "")) == "executing")
	assert(String(Dictionary(action_panel.call("visual_state_summary")).get("flow_text", "")).contains("执行中"))
	await process_frame
	await process_frame
	assert(
		int(Dictionary(game_session.call("current_snapshot")).get("battle_round", 0))
		== main_before_round + 1
	)
	assert(int(game_session.call("replay_step_index")) == 2)
	var vfx_player := battle_view.get_node("Board/VfxHost")
	var trace_deadline_msec := Time.get_ticks_msec() + 30000
	while bool(vfx_player.get("_trace_sequence_playing")) and Time.get_ticks_msec() < trace_deadline_msec:
		await process_frame
	assert(not bool(vfx_player.get("_trace_sequence_playing")))
	assert(Array(vfx_player.get("_trace_queue")).is_empty())
	assert(String(Dictionary(action_panel.call("visual_state_summary")).get("state", "")) == "result")
	assert(String(Dictionary(action_panel.call("visual_state_summary")).get("flow_text", "")).contains("执行完成"))
	print("MOCK_BATTLE_PROJECT_SMOKE_PASS")
	quit(0)


func _skill_control_entry_ids(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		result.append(String(Dictionary(entry_value).get("entryId", "")))
	return result


func _skill_bar_unit_ids(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		var unit_id := String(Dictionary(entry_value).get("unitId", ""))
		if unit_id != "" and not result.has(unit_id):
			result.append(unit_id)
	return result


func _skill_bar_slots(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		result.append(String(Dictionary(entry_value).get("skillSlot", "")))
	return result


func _assert_presentation_patterns_load() -> void:
	assert(FeatureRegistry.new() != null)
	assert(SceneRouter.new() != null)
	assert(BattleBoardController.new() != null)
	assert(BattleHudController.new() != null)
	assert(BattleDetailController.new() != null)
	assert(BattleCommandBuilder.new() != null)
	var battle_scene_script := FileAccess.get_file_as_string("res://core_ui/scripts/battle/scenes/battle_scene.gd")
	assert(battle_scene_script.contains("command_requested.emit(command.duplicate(true))"))
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
	assert(lock_value.text == "CAP:8")
	assert(shield_value.text == "SHLD:2")

	pet.call("set_unit_data", {
		"unitId": "active_guard_test",
		"hp": 20,
		"shield": 2,
		"atk": 5,
		"buffs": [{"id": "pet_guard", "active": true, "max_damage_per_hit": 4}],
	}, "player", null)
	assert(lock_group.visible)
	assert(lock_value.text == "CAP:4")

	pet.call("set_unit_data", {
		"unitId": "no_cap_test",
		"hp": 20,
		"shield": 2,
		"atk": 5,
		"threat": {"totalDamage": 10},
	}, "player", null)
	assert(not lock_group.visible)
	assert(lock_value.text == "")
	assert(shield_value.text == "SHLD:2")
	pet.queue_free()


func _assert_damage_preview_cycle() -> void:
	var pet := BattleUnitScene.instantiate() as Control
	assert(pet != null)
	root.add_child(pet)
	await process_frame
	pet.call("set_unit_data", {
		"unitId": "damage_preview_test",
		"hp": 20,
		"max_hp": 20,
		"shield": 0,
		"atk": 5,
	}, "enemy", null)
	pet.call("start_damage_preview", 20, 7, -1, 15, 2, 0, 20)
	var stats_root := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var health_value := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/Value_Text") as Label
	var badge := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/IncomingDamagePreview") as Control
	var badge_value := badge.get_node("Value") as Label
	var preview := Dictionary(pet.call("get_damage_preview_snapshot"))
	assert(bool(preview.get("active", false)))
	assert(bool(preview.get("pinned", false)))
	assert(bool(preview.get("uses_badge", false)))
	assert(String(preview.get("state", "")) == "visible")
	assert(int(preview.get("predicted_damage", 0)) == 15)
	assert(int(preview.get("projected_shield", -1)) == 0)
	assert(int(preview.get("displayed_hp", -1)) == 20)
	assert(int(preview.get("displayed_damage", -1)) == 15)
	assert(stats_root.visible)
	assert(health_value.text == "HP:20")
	assert(badge.visible)
	assert(badge_value.text == "15")
	pet.call("_on_damage_preview_timeout")
	await create_timer(1.25).timeout
	assert(String(Dictionary(pet.call("get_damage_preview_snapshot")).get("state", "")) == "visible")
	assert(is_zero_approx(float(Dictionary(pet.call(
		"get_damage_preview_snapshot"
	)).get("seconds_to_switch", -1.0))))
	assert(badge.modulate.a > 0.99)
	pet.call("stop_damage_preview")
	assert(health_value.text == "HP:20")
	assert(stats_root.visible)
	assert(not badge.visible)
	assert(not bool(Dictionary(pet.call("get_damage_preview_snapshot")).get("active", true)))
	pet.queue_free()
	await process_frame


func _assert_incoming_damage_badge() -> void:
	var pet := BattleUnitScene.instantiate() as Control
	assert(pet != null)
	root.add_child(pet)
	await process_frame
	pet.call("set_unit_data", {
		"unitId": "incoming_damage_badge_test",
		"hp": 20,
		"max_hp": 20,
		"shield": 2,
		"atk": 5,
	}, "player", null)
	pet.call("start_damage_preview", 20, 7, -1, 15, 2, 0, 20, true)
	var badge := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/IncomingDamagePreview") as Control
	var value := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/IncomingDamagePreview/Value") as Label
	var stats_root := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var preview := Dictionary(pet.call("get_damage_preview_snapshot"))
	assert(bool(preview.get("active", false)))
	assert(bool(preview.get("uses_badge", false)))
	assert(int(preview.get("displayed_damage", -1)) == 15)
	assert(int(preview.get("displayed_hp", -1)) == 20)
	assert(badge.visible)
	assert(value.text == "15")
	assert(value.self_modulate == Color.WHITE)
	assert(stats_root.visible)
	assert(is_equal_approx(badge.position.x, pet.size.x - badge.size.x * 0.75))
	assert(is_equal_approx(badge.position.y + badge.size.y, 4.0))
	assert(badge.position.y < 0.0)
	pet.call("stop_damage_preview")
	assert(not badge.visible)
	assert(value.text == "")
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


func _cell_data_is_draggable(data: Dictionary) -> bool:
	var unit_id := String(data.get("unitId", data.get("unit_id", "")))
	var side := String(data.get("side", data.get("unitSide", "")))
	var unit_type := String(data.get("type", data.get("unitType", data.get("unit_type", "")))).to_lower()
	return unit_id != "" and side in ["player", "ally"] \
		and unit_type != "hero" and unit_id not in ["player_hero", "enemy_hero"]


func _has_visible_elements(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for amount in Dictionary(value).values():
		if int(amount) > 0:
			return true
	return false


func _public_target_preview_count(snapshot: Dictionary) -> int:
	var count := 0
	for cell_value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		count += Array(Dictionary(cell_value).get("previews", [])).size()
	return count


func _has_dictionary_key_with_prefix(value: Variant, prefix: String) -> bool:
	if value is Dictionary:
		for key_value in Dictionary(value).keys():
			if String(key_value).begins_with(prefix) \
					or _has_dictionary_key_with_prefix(Dictionary(value)[key_value], prefix):
				return true
	elif value is Array:
		for entry in Array(value):
			if _has_dictionary_key_with_prefix(entry, prefix):
				return true
	return false


func _assert_corner_heroes_are_locked(
	battle_probe: RefCounted,
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
		var drag_state := Dictionary(battle_probe.call("start_drag", grid, grid))
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
		var border := cell.get_node_or_null("AttackHighlightBorder") as Line2D
		if border != null and border.visible:
			count += 1
	return count


func _visible_range_fill_count(board_grid: Control) -> int:
	var count := 0
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell == null or not cell.visible:
			continue
		var fill := cell.get_node_or_null("AttackHighlight") as Polygon2D
		var border := cell.get_node_or_null("AttackHighlightBorder") as Line2D
		if fill != null and fill.visible and border != null and not border.visible:
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
		assert(epoch_msec >= 0)
		assert(bool(preview.get("pinned", false)))
		assert(bool(preview.get("uses_badge", false)))
		assert(String(preview.get("state", "")) == "visible")
		assert(is_zero_approx(float(preview.get("seconds_to_switch", -1.0))))
		if active_count == 0:
			shared_epoch_msec = epoch_msec
		else:
			assert(epoch_msec == shared_epoch_msec)
		active_count += 1
	assert(active_count > 1)


func _assert_cell_stat_column(cell: Control, pet: Control) -> void:
	var corners: PackedVector2Array = cell.get("polygon")
	assert(corners.size() == 4)
	var stats := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var health := stats.get_node("Health") as Control
	var shield := stats.get_node("Shield") as Control
	var attack := stats.get_node("Attack") as Control
	var damage_cap := stats.get_node("DamageCap") as Control
	var groups: Array[Control] = [health, attack, shield, damage_cap]
	var previous_bottom := -INF
	var aligned_right := -INF
	for group in groups:
		var icon := group.get_node("Icon") as Control
		var label := group.get_node("Value_Text") as Control
		assert(not icon.visible)
		var row_bounds := Rect2(group.position, group.size * group.scale)
		assert(row_bounds.position.y > previous_bottom)
		var row_center_y := row_bounds.get_center().y
		var left_at_center := _stat_edge_x_at_y(corners[0], corners[3], row_center_y)
		var right_at_center := _stat_edge_x_at_y(corners[1], corners[2], row_center_y)
		assert(row_bounds.get_center().x > (left_at_center + right_at_center) * 0.5)
		if is_inf(aligned_right):
			aligned_right = row_bounds.end.x
		else:
			assert(is_equal_approx(row_bounds.end.x, aligned_right))
		assert(is_zero_approx(group.rotation))
		assert(is_zero_approx(label.rotation))
		previous_bottom = row_bounds.end.y
	var column_top := groups[0].position.y
	assert(is_equal_approx(column_top, minf(corners[0].y, corners[1].y)))
	var last_group := groups[groups.size() - 1]
	var column_bottom := last_group.position.y + last_group.size.y * last_group.scale.y
	var shared_right_edge := minf(
		_stat_edge_x_at_y(corners[1], corners[2], column_top),
		_stat_edge_x_at_y(corners[1], corners[2], column_bottom)
	)
	assert(is_equal_approx(shared_right_edge - aligned_right, 4.0 * groups[0].scale.x))


func _stat_edge_x_at_y(edge_start: Vector2, edge_end: Vector2, y: float) -> float:
	if is_zero_approx(edge_end.y - edge_start.y):
		return edge_start.x
	var weight := clampf((y - edge_start.y) / (edge_end.y - edge_start.y), 0.0, 1.0)
	return lerpf(edge_start.x, edge_end.x, weight)


func _assert_three_choice_scene_hierarchy(scene_source: String) -> void:
	assert(scene_source.contains("[node name=\"Middle\" type=\"Control\" parent=\"MainBG/Containers\""))
	assert(_node_parent(scene_source, "Middle_Three_Option") == "MainBG/Containers/Middle")
	assert(_node_parent(scene_source, "BagOverlayMask") == "MainBG/Containers/Middle")
	assert(_node_parent(scene_source, "Middle_Shop") == "MainBG/Containers/Middle")
	assert(_node_parent(scene_source, "Middle_Bag") == "MainBG/Containers/Middle")
	assert(_node_parent(scene_source, "Bags") == "MainBG/Containers")

	var middle_children := _direct_scene_children(scene_source, "MainBG/Containers/Middle")
	assert(middle_children.size() == 4)
	assert(middle_children[0] == "Middle_Three_Option")
	assert(middle_children[1] == "BagOverlayMask")
	assert(middle_children[2] == "Middle_Shop")
	assert(middle_children[3] == "Middle_Bag")

	var bag_children := _direct_scene_children(scene_source, "MainBG/Containers/Bags")
	assert(bag_children.size() == 2)
	assert(bag_children[0] == "Bag_Button")
	assert(bag_children[1] == "BagStorageState")
	assert(scene_source.contains("[node name=\"Top_Sell\" type=\"TextureButton\" parent=\"MainBG/Containers/Top\""))
	assert(not scene_source.contains("[node name=\"SellHighlight\""))


func _assert_three_choice_runtime_slot_policy(script_source: String) -> void:
	assert(script_source.contains("_build_slot_buttons(shop_slots, \"Shop_Slot\", SHOP_SLOT_COUNT, SHOP_SLOT_SIZE, SLOT_LAYOUT_SHOP)"))
	assert(script_source.contains("_build_slot_buttons(bag_slots, \"Bag_Slot\", BAG_SLOT_COUNT, BAG_SLOT_SIZE, SLOT_LAYOUT_COLLECTION)"))
	assert(script_source.contains("_configure_authored_slot_buttons(party_container, \"Party_Slot\", PARTY_SLOT_COUNT, PARTY_SLOT_SIZE, SLOT_LAYOUT_PARTY)"))
	assert(script_source.contains("var button := TextureButton.new()"))
	assert(script_source.contains("container.add_child(button)"))
	assert(not script_source.contains("res://art/prefabs/route/shop_slot"))
	assert(not script_source.contains("res://art/prefabs/route/bag_slot"))
	assert(not script_source.contains("res://art/prefabs/route/party_slot"))


func _node_parent(scene_source: String, node_name: String) -> String:
	var marker := "[node name=\"%s\"" % node_name
	var start := scene_source.find(marker)
	assert(start >= 0)
	var line_end := scene_source.find("\n", start)
	var line := scene_source.substr(start, line_end - start)
	var parent_marker := " parent=\""
	var parent_start := line.find(parent_marker)
	assert(parent_start >= 0)
	parent_start += parent_marker.length()
	var parent_end := line.find("\"", parent_start)
	assert(parent_end >= 0)
	return line.substr(parent_start, parent_end - parent_start)


func _direct_scene_children(scene_source: String, parent_path: String) -> Array[String]:
	var children: Array[String] = []
	var search_from := 0
	while true:
		var start := scene_source.find("[node name=\"", search_from)
		if start < 0:
			break
		var line_end := scene_source.find("\n", start)
		var line := scene_source.substr(start, line_end - start)
		var parent_marker := " parent=\"%s\"" % parent_path
		if line.contains(parent_marker):
			var name_start := line.find("[node name=\"") + String("[node name=\"").length()
			var name_end := line.find("\"", name_start)
			children.append(line.substr(name_start, name_end - name_start))
		search_from = line_end + 1
	return children
