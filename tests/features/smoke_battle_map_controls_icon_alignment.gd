extends SceneTree

const MapControlsScene := preload("res://art/prefabs/battle/hud/battle_map_controls.tscn")
const ShortcutHintsPath := "res://art/images/battle/map_controls/shortcut_hints.png"
const ExpectedShortcutHintsSha256 := "ec13a334cde0eab36bc66674aa30088d178fbd8ea5bac6c6b0699b84c4b94f9b"


func _init() -> void:
	var controls := MapControlsScene.instantiate() as Control
	root.add_child(controls)
	await process_frame

	var attack_order := controls.get_node("AttackOrderButton") as TextureButton
	var auto_arrange := controls.get_node("AutoArrangeButton") as TextureButton
	var reset := controls.get_node("ResetButton") as TextureButton
	var bag := controls.get_node("BagButton") as TextureButton

	assert(reset.offset_left == 1704.0 and reset.offset_right == 1770.0, "R rewind position changed")
	assert(attack_order.offset_left == 1773.0 and attack_order.offset_right == 1838.0, "TAB attack-order position changed")
	assert(auto_arrange.offset_left == 1841.0 and auto_arrange.offset_right == 1907.0, "A auto-arrange position changed")
	assert(attack_order.offset_left - reset.offset_right == 3.0, "R-to-TAB gap is not 3px")
	assert(auto_arrange.offset_left - attack_order.offset_right == 3.0, "TAB-to-A gap is not 3px")
	assert(attack_order.texture_normal.resource_path.ends_with("/attack_order_normal.png"), "attack-order function icon changed")
	assert(auto_arrange.texture_normal.resource_path.ends_with("/auto_arrange_normal.png"), "auto-arrange function icon changed")
	assert(reset.texture_normal.resource_path.ends_with("/reset_normal.png"), "reset function icon changed")
	assert(not bag.visible, "battle bag icon is still visible")
	assert(FileAccess.get_sha256(ShortcutHintsPath) == ExpectedShortcutHintsSha256, "R / TAB / A shortcut-hint image mapping changed")
	assert(controls.call("get_keyboard_shortcuts") == {
		"A": "AutoArrangeButton",
		"R": "ResetButton",
		"D": "SpeedButton",
		"Tab": "AttackOrderButton",
		"B": "BagButton",
		"Escape": "SettingsButton",
		"Space": "AllOutButton",
	}, "shortcut/function bindings changed")

	var emitted: Array[String] = []
	controls.reset_requested.connect(func() -> void: emitted.append("reset"))
	controls.attack_order_requested.connect(func() -> void: emitted.append("attack_order"))
	controls.auto_arrange_requested.connect(func() -> void: emitted.append("auto_arrange"))
	reset.pressed.emit()
	attack_order.pressed.emit()
	auto_arrange.pressed.emit()
	assert(emitted == ["reset", "attack_order", "auto_arrange"], "button/function signals do not match R / TAB / A positions")

	emitted.clear()
	_tap_shortcut(controls, KEY_R)
	_tap_shortcut(controls, KEY_TAB)
	_tap_shortcut(controls, KEY_A)
	assert(emitted == ["reset", "attack_order", "auto_arrange"], "R / TAB / A shortcuts do not activate the matching functions")

	print("SMOKE_BATTLE_MAP_CONTROLS_ICON_ALIGNMENT_OK")
	quit(0)


func _tap_shortcut(controls: Control, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	assert(bool(controls.call("handle_shortcut_input", press)))
	var release := InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	assert(bool(controls.call("handle_shortcut_input", release)))
