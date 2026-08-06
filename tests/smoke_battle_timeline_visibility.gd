extends SceneTree

const BATTLE_SCENE_PATH := "res://art/scenes/battle/battle_art_scene.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var packed := load(BATTLE_SCENE_PATH) as PackedScene
	var battle := packed.instantiate() as Control
	host.add_child(battle)
	await process_frame

	var hud := battle.get_node("Hud") as Control
	var attack_order_button := battle.get_node("MapControls/AttackOrderButton") as TextureButton
	var settings_button := battle.get_node("MapControls/SettingsButton") as TextureButton
	var settings_menu := battle.get_node("OverlayHost/SettingsMenu") as Control
	var layer := hud.get_node("AttackTimelineLayer") as CanvasLayer
	var timeline := hud.get_node("AttackTimelineLayer/AttackTimeline") as Control
	var backdrop := timeline.get_node("Backdrop") as ColorRect
	assert(layer.visible)
	assert(not timeline.visible)
	assert(backdrop.show_behind_parent)
	assert(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(backdrop.position == Vector2(-140.0, -150.0))
	assert(backdrop.size == Vector2(1920.0, 1080.0))
	assert(is_equal_approx(backdrop.color.a, 0.58))
	assert(hud.get_node_or_null("AttackTimelineLayer/AttackTimelineToggleButton") == null)

	host.visible = false
	await process_frame
	assert(not layer.visible)
	attack_order_button.pressed.emit()
	assert(not timeline.visible)

	host.visible = true
	await process_frame
	assert(layer.visible)
	attack_order_button.pressed.emit()
	assert(timeline.visible)
	var map_controls := battle.get_node("MapControls") as Control
	var emitted_shortcuts: Array[String] = []
	map_controls.auto_arrange_requested.connect(func() -> void: emitted_shortcuts.append("A"))
	map_controls.reset_requested.connect(func() -> void: emitted_shortcuts.append("R"))
	map_controls.speed_toggled.connect(func(_active: bool) -> void: emitted_shortcuts.append("D"))
	map_controls.bag_requested.connect(func() -> void: emitted_shortcuts.append("B"))
	map_controls.all_out_requested.connect(func() -> void: emitted_shortcuts.append("Space"))
	for blocked_key in [KEY_A, KEY_R, KEY_D, KEY_B, KEY_SPACE]:
		await _press_key(battle.get_viewport(), blocked_key)
	assert(emitted_shortcuts.is_empty())
	assert(timeline.visible)
	await _click(battle.get_viewport(), Vector2(50.0, 50.0))
	assert(not timeline.visible)
	attack_order_button.pressed.emit()
	assert(timeline.visible)
	await _click(
		battle.get_viewport(),
		settings_button.global_position + settings_button.size * 0.5
	)
	assert(not timeline.visible)
	assert(not settings_menu.visible)
	attack_order_button.pressed.emit()
	assert(timeline.visible)
	attack_order_button.pressed.emit()
	assert(not timeline.visible)

	host.queue_free()
	await process_frame
	print("SMOKE_BATTLE_TIMELINE_VISIBILITY_PASS")
	quit(0)


func _click(viewport: Viewport, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.global_position = position
	press.pressed = true
	viewport.push_input(press, true)
	await process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.global_position = position
	release.pressed = false
	viewport.push_input(release, true)
	await process_frame


func _press_key(viewport: Viewport, keycode: int) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode as Key
	press.physical_keycode = keycode as Key
	press.pressed = true
	viewport.push_input(press, true)
	await process_frame

	var release := InputEventKey.new()
	release.keycode = keycode as Key
	release.physical_keycode = keycode as Key
	release.pressed = false
	viewport.push_input(release, true)
	await process_frame
