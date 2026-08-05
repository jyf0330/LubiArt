extends SceneTree

const AttackTimelineScene := preload("res://art/prefabs/battle/hud/attack_timeline.tscn")
const GameCursorScene := preload("res://art/prefabs/shared/cursor/game_cursor.tscn")
const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_cursor := GameCursorScene.instantiate()
	root.add_child(game_cursor)
	var timeline := AttackTimelineScene.instantiate() as Control
	root.add_child(timeline)
	await process_frame
	await process_frame
	var panel_style := timeline.get_theme_stylebox("panel") as StyleBoxTexture
	assert(panel_style != null)
	assert(panel_style.texture != null)
	assert(is_equal_approx(panel_style.modulate_color.a, 0.78))
	assert(is_equal_approx(panel_style.texture_margin_left, 24.0))
	assert(is_equal_approx(panel_style.texture_margin_top, 24.0))
	assert((timeline.get_node("Subtitle") as Label).position.y == 91.0)
	assert((timeline.get_node("Subtitle") as Label).size.y == 35.0)
	assert((timeline.get_node("StatusPanel") as Panel).position.y == 548.0)
	assert((timeline.get_node("StatusPanel") as Panel).size.y == 60.0)
	assert((timeline.get_node("ResetButton") as Button).position.y == 660.0)
	var snapshot := Dictionary(MockSession.new({"start_phase": "battle"}).call("current_snapshot"))
	timeline.call("render_snapshot", snapshot)
	await process_frame
	var expected_entry_ids: Array[String] = []
	for entry_value in Array(snapshot.get("skillControlBar", [])):
		expected_entry_ids.append(String(Dictionary(entry_value).get("entryId", "")))
	var initial_order := Array(timeline.call("debug_order_ids"))
	assert(int(timeline.call("debug_marker_count")) == expected_entry_ids.size())
	assert(initial_order == expected_entry_ids)
	assert(timeline.get_node("TimelineArea/MarkerLayer").get_child_count() == 10)
	assert(timeline.get_node("TimelineArea/MarkerLayer/Marker1/PetFrame") != null)
	assert((timeline.get_node("TimelineArea/MarkerLayer/Marker1/OrderBadge") as Label).position == Vector2(-6.0, -7.0))
	var first_pet_frame := timeline.get_node("TimelineArea/MarkerLayer/Marker1/PetFrame") as TextureButton
	var first_order_badge := timeline.get_node("TimelineArea/MarkerLayer/Marker1/OrderBadge") as Label
	first_pet_frame.call("set_drag_visual", true)
	assert(first_order_badge.z_index > first_pet_frame.z_index)
	assert(first_pet_frame.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	first_pet_frame.call("set_drag_visual", false)
	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	timeline.call("_on_marker_gui_input", drag_press, timeline.get_node("TimelineArea/MarkerLayer/Marker1"))
	assert(StringName(game_cursor.call("debug_state")) == &"grabbing")
	timeline.visible = false
	assert(StringName(game_cursor.call("debug_state")) == &"pointer")
	timeline.visible = true
	var track_shadow := timeline.get_node("TimelineArea/TrackShadow") as Panel
	var first_name_label := timeline.get_node("TimelineArea/MarkerLayer/Marker1/NameLabel") as Label
	assert(first_name_label.position.y > track_shadow.position.y + track_shadow.size.y)
	for marker in timeline.get_node("TimelineArea/MarkerLayer").get_children():
		if marker.visible:
			assert(is_equal_approx((marker as Control).position.y, 4.0))
	var first_background := timeline.get_node("TimelineArea/MarkerLayer/Marker1/PetFrame/Background") as TextureRect
	var first_frame := timeline.get_node("TimelineArea/MarkerLayer/Marker1/PetFrame/Frame") as TextureRect
	assert(first_background.position == Vector2(2.0, 2.0))
	assert(first_background.size == Vector2(166.0, 166.0))
	assert(first_frame.position == Vector2.ZERO)
	assert(first_frame.size == Vector2(170.0, 170.0))
	assert(timeline.call("debug_set_marker_position", expected_entry_ids[0], 1.0))
	var reordered := Array(timeline.call("debug_order_ids"))
	assert(reordered.size() == expected_entry_ids.size())
	assert(is_equal_approx((timeline.get_node("TimelineArea/MarkerLayer/Marker1") as Control).position.x, 1270.0))
	var commands: Array[Dictionary] = []
	timeline.command_requested.connect(func(command: Dictionary) -> void:
		commands.append(command.duplicate(true))
	)
	timeline.call("debug_commit_order")
	assert(commands.size() == 1)
	assert(commands[0].keys().size() == 2)
	assert(String(commands[0].get("type", "")) == "SET_SKILL_CONTROL_ORDER")
	assert(Array(commands[0].get("orderedEntryIds", [])) == reordered)
	timeline.call("set_interaction_locked", true)
	assert((timeline.get_node("PlayButton") as Button).disabled)
	assert((timeline.get_node("ResetButton") as Button).disabled)
	timeline.call("set_interaction_locked", false)
	assert(not (timeline.get_node("PlayButton") as Button).disabled)
	print("ATTACK_TIMELINE_SMOKE_PASS")
	timeline.queue_free()
	game_cursor.queue_free()
	quit(0)
