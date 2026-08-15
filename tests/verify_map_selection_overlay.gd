extends SceneTree


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://art/scenes/battle/battle_art_scene.tscn") as PackedScene
	if packed == null:
		_fail("battle scene did not load")
		return
	var battle := packed.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame

	var open_button := battle.get_node_or_null(
		"Hud/BattleActionPanel/Margin/Content/MapDebugButton"
	) as Button
	var overlay := battle.get_node_or_null("OverlayHost/MapSelectionOverlay") as Control
	var map_controls := battle.get_node_or_null("MapControls") as Control
	if open_button == null or overlay == null or map_controls == null:
		_fail("map selection nodes are missing")
		return
	if overlay.visible or int(overlay.call("get_map_button_count")) != 11:
		_fail("map selection initial state is invalid")
		return
	if String(map_controls.call("get_map_id")) != "mountain_new":
		_fail("the third new map is not the battle default")
		return
	var default_texture := map_controls.call("get_map_texture") as Texture2D
	if default_texture == null or default_texture.resource_path.get_file() != "mountain_new.png":
		_fail("default mountain texture is incorrect")
		return

	# 操作 1：战斗界面的地图按钮打开选择界面。
	open_button.pressed.emit()
	await process_frame
	if not overlay.visible:
		_fail("map selection did not open")
		return

	# 操作 2：选中池塘（早），并让战斗背景立即切换。
	var pond_button := overlay.get_node(
		"Panel/Margin/Content/MapGrid/PondMorning"
	) as TextureButton
	pond_button.pressed.emit()
	await process_frame
	if overlay.visible or String(map_controls.call("get_map_id")) != "pond_morning":
		_fail("pond morning selection did not apply")
		return
	if open_button.text != "选择地图：池塘（早）":
		_fail("map button label did not update")
		return
	var selected_texture := map_controls.call("get_map_texture") as Texture2D
	if selected_texture == null or selected_texture.resource_path.get_file() != "pond_morning.png":
		_fail("selected map texture is incorrect")
		return

	# 操作 3：再次打开时，当前地图必须有金色选中框。
	open_button.pressed.emit()
	await process_frame
	var selection_border := pond_button.get_node("SelectionBorder") as Panel
	if not overlay.visible or not selection_border.visible:
		_fail("current map selection border is missing")
		return

	# 操作 4：关闭按钮只关闭面板，不改变已选地图。
	var close_button := overlay.get_node("Panel/Margin/Content/Header/CloseButton") as Button
	close_button.pressed.emit()
	await process_frame
	if overlay.visible or String(map_controls.call("get_map_id")) != "pond_morning":
		_fail("close button changed selection or failed to close")
		return

	# 操作 5：Esc 也能关闭面板。
	open_button.pressed.emit()
	await process_frame
	var cancel_event := InputEventKey.new()
	cancel_event.keycode = KEY_ESCAPE
	cancel_event.pressed = true
	overlay.call("_unhandled_key_input", cancel_event)
	await process_frame
	if overlay.visible:
		_fail("escape did not close map selection")
		return

	print("MAP_SELECTION_OVERLAY_PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
