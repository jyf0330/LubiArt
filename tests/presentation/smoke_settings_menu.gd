extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame

	var menu := battle.get_node("OverlayHost/SettingsMenu") as Control
	var hud := battle.get_node("Hud") as Control
	var attack_timeline_layer := battle.get_node("Hud/AttackTimelineLayer") as CanvasLayer
	var attack_timeline := battle.get_node("Hud/AttackTimelineLayer/AttackTimeline") as Control
	var settings_button := battle.get_node("MapControls/SettingsButton") as TextureButton
	var attack_order_button := battle.get_node("MapControls/AttackOrderButton") as TextureButton
	assert(menu != null)
	assert(not menu.visible)
	assert(not attack_timeline.visible)

	await _press_key_with_feedback(battle.get_viewport(), KEY_ESCAPE, settings_button)
	assert(menu.visible)

	await _press_key_with_feedback(battle.get_viewport(), KEY_ESCAPE, settings_button)
	assert(not menu.visible)

	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_event.physical_keycode = KEY_TAB
	tab_event.pressed = true
	battle.get_viewport().push_input(tab_event, true)
	await process_frame
	assert(attack_timeline.visible)
	assert(attack_order_button.scale.is_equal_approx(Vector2(0.92, 0.92)))

	var tab_echo := InputEventKey.new()
	tab_echo.keycode = KEY_TAB
	tab_echo.physical_keycode = KEY_TAB
	tab_echo.pressed = true
	tab_echo.echo = true
	battle.get_viewport().push_input(tab_echo, true)
	await process_frame
	assert(attack_timeline.visible)

	var tab_release := InputEventKey.new()
	tab_release.keycode = KEY_TAB
	tab_release.physical_keycode = KEY_TAB
	tab_release.pressed = false
	battle.get_viewport().push_input(tab_release, true)
	await process_frame
	assert(attack_order_button.scale.is_equal_approx(Vector2(0.92, 0.92)))
	await create_timer(0.22).timeout
	assert(attack_order_button.scale.is_equal_approx(Vector2.ONE))

	await _press_key_with_feedback(battle.get_viewport(), KEY_TAB, attack_order_button)
	assert(not attack_timeline.visible)
	assert(not bool(hud.call("debug_is_attack_timeline_open")))

	menu.call("open_menu")
	var continue_button := menu.get_node(
		"CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/Continue"
	) as Button
	continue_button.pressed.emit()
	assert(not menu.visible)

	# Esc closes the current secondary interface before opening settings.
	await _press_key(battle.get_viewport(), KEY_TAB)
	assert(attack_timeline.visible)
	await _press_key(battle.get_viewport(), KEY_ESCAPE)
	assert(menu.visible)
	assert(not attack_timeline.visible)
	assert(not attack_timeline_layer.visible)
	assert(battle.get_viewport().gui_get_focus_owner() != null)

	# While settings owns focus, every other battle shortcut is inert.
	var map_controls := battle.get_node("MapControls") as Control
	var emitted_shortcuts: Array[String] = []
	map_controls.auto_arrange_requested.connect(func() -> void: emitted_shortcuts.append("A"))
	map_controls.reset_requested.connect(func() -> void: emitted_shortcuts.append("R"))
	map_controls.log_requested.connect(func() -> void: emitted_shortcuts.append("D"))
	map_controls.attack_order_requested.connect(func() -> void: emitted_shortcuts.append("Tab"))
	map_controls.bag_requested.connect(func() -> void: emitted_shortcuts.append("B"))
	map_controls.all_out_requested.connect(func() -> void: emitted_shortcuts.append("Space"))
	for blocked_key in [KEY_A, KEY_R, KEY_D, KEY_TAB, KEY_B, KEY_SPACE]:
		await _press_key(battle.get_viewport(), blocked_key)
	assert(emitted_shortcuts.is_empty())
	assert(menu.visible)
	assert(not attack_timeline.visible)
	assert(not attack_timeline_layer.visible)

	await _press_key(battle.get_viewport(), KEY_ESCAPE)
	assert(not menu.visible)
	assert(not attack_timeline.visible)
	assert(attack_timeline_layer.visible)

	print("SMOKE_SETTINGS_MENU_PASS")
	quit(0)


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


func _press_key_with_feedback(
	viewport: Viewport,
	keycode: int,
	button: TextureButton
) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode as Key
	press.physical_keycode = keycode as Key
	press.pressed = true
	viewport.push_input(press, true)
	await process_frame
	assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))

	var release := InputEventKey.new()
	release.keycode = keycode as Key
	release.physical_keycode = keycode as Key
	release.pressed = false
	viewport.push_input(release, true)
	await process_frame
	assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
	await create_timer(0.22).timeout
	assert(button.scale.is_equal_approx(Vector2.ONE))
