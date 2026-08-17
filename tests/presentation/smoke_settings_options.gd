extends SceneTree

const SettingsScene := preload("res://art/prefabs/menu/screens/menu_settings.tscn")
const VISUAL_ROOT := "CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/"
const CONTENT_ROOT := VISUAL_ROOT + "ContentArea/ContentScroll/ContentStack/"
const ShortcutCatalog := preload("res://core_ui/scripts/shared/shortcut_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var settings := SettingsScene.instantiate() as Control
	root.add_child(settings)
	await process_frame
	await process_frame
	settings.call("open")
	await process_frame

	var section_names := [
		"AudioSection",
		"GraphicsSection",
		"GameplaySection",
		"KeybindsSection",
		"AccessibilitySection",
		"SupportSection",
	]
	var previous_y := -1.0
	for section_name in section_names:
		var section := settings.get_node(CONTENT_ROOT + section_name) as Control
		assert(section != null)
		assert(section.position.y > previous_y)
		previous_y = section.position.y

	var master_volume := settings.get_node(CONTENT_ROOT + "AudioSection/MasterVolumeSlider") as HSlider
	master_volume.value = 37.0
	assert(is_equal_approx(master_volume.value, 37.0))

	var resolution := settings.get_node(CONTENT_ROOT + "GraphicsSection/ResolutionOption") as OptionButton
	resolution.select(2)
	assert(resolution.selected == 2)
	assert(resolution.get_item_text(2) == "1366 × 768")
	assert(resolution.get_theme_font_size("font_size") == 32)
	var resolution_popup := resolution.get_popup()
	assert(resolution_popup.get_theme_font_size("font_size", "PopupMenu") == 32)
	var popup_panel := resolution_popup.get_theme_stylebox("panel", "PopupMenu") as StyleBoxFlat
	assert(popup_panel != null)
	assert(popup_panel.bg_color.is_equal_approx(Color(0.015, 0.035, 0.13, 0.98)))

	var skip_intro := settings.get_node(CONTENT_ROOT + "GraphicsSection/SkipIntroCheck") as CheckBox
	skip_intro.button_pressed = false
	assert(not skip_intro.button_pressed)

	var language := settings.get_node(CONTENT_ROOT + "GameplaySection/LanguageOption") as OptionButton
	language.select(2)
	assert(language.selected == 2)
	assert(language.get_item_text(2) == "English")
	var shortcut_hints_check := settings.get_node(
		CONTENT_ROOT + "GameplaySection/ShortcutHintsCheck"
	) as CheckBox
	assert(shortcut_hints_check.button_pressed)
	var shortcut_hint_values: Array[bool] = []
	settings.connect(
		"button_shortcut_hints_toggled",
		func(hints_visible: bool) -> void: shortcut_hint_values.append(hints_visible)
	)
	shortcut_hints_check.button_pressed = false
	assert(not settings.call("are_button_shortcut_hints_visible"))
	assert(shortcut_hint_values == [false])

	for binding_value in ShortcutCatalog.DISPLAY_BINDINGS:
		var binding := Dictionary(binding_value)
		var node_prefix := String(binding.get("node", ""))
		var label := settings.get_node(CONTENT_ROOT + "KeybindsSection/%sLabel" % node_prefix) as Label
		var key_button := settings.get_node(CONTENT_ROOT + "KeybindsSection/%sKeyButton" % node_prefix) as Button
		var reset_button := settings.get_node(CONTENT_ROOT + "KeybindsSection/%sResetButton" % node_prefix) as Button
		assert(label.text == String(binding.get("label", "")))
		assert(key_button.text == ShortcutCatalog.display_key_name(binding.get("keycode", KEY_NONE) as Key))
		assert(not reset_button.visible)
		assert(key_button.size.x >= 260.0)
		assert(key_button.position.x + key_button.size.x < reset_button.position.x)
		assert(reset_button.position.x + reset_button.size.x <= 920.0)

	var changed_bindings: Array[Dictionary] = []
	settings.connect(
		"shortcut_bindings_changed",
		func(bindings: Dictionary) -> void: changed_bindings.append(bindings)
	)
	var settings_key_button := settings.get_node(
		CONTENT_ROOT + "KeybindsSection/SettingsKeyButton"
	) as Button
	var settings_reset_button := settings.get_node(
		CONTENT_ROOT + "KeybindsSection/SettingsResetButton"
	) as Button
	settings_key_button.pressed.emit()
	assert(settings_key_button.text == "按下按键以设置")
	var prompt_width := settings_key_button.get_theme_font("font").get_string_size(
		settings_key_button.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		settings_key_button.get_theme_font_size("font_size")
	).x
	assert(prompt_width <= settings_key_button.size.x - 16.0)
	var right_mouse := InputEventMouseButton.new()
	right_mouse.button_index = MOUSE_BUTTON_RIGHT
	right_mouse.pressed = true
	settings.call("_input", right_mouse)
	assert(settings_key_button.text == "RMB")
	assert(settings_reset_button.visible)
	assert(ShortcutCatalog.event_matches_action(right_mouse, ShortcutCatalog.ACTION_SETTINGS))
	assert(changed_bindings.size() == 1)
	settings_reset_button.pressed.emit()
	assert(settings_key_button.text == "ESC")
	assert(not settings_reset_button.visible)
	assert(changed_bindings.size() == 2)
	assert(settings.get_node_or_null(CONTENT_ROOT + "KeybindsSection/InventoryLabel") == null)
	assert(settings.get_node_or_null(CONTENT_ROOT + "KeybindsSection/HintLabel") == null)

	var keybind_tab := settings.get_node(VISUAL_ROOT + "LeftButtonArea/Buttons/Option04") as Button
	keybind_tab.pressed.emit()
	await process_frame
	var content_scroll := settings.get_node(VISUAL_ROOT + "ContentArea/ContentScroll") as ScrollContainer
	var keybind_section := settings.get_node(CONTENT_ROOT + "KeybindsSection") as Control
	assert(content_scroll.scroll_vertical >= int(keybind_section.position.y) - 1)
	assert(keybind_tab.button_pressed)

	var support_button := settings.get_node(CONTENT_ROOT + "SupportSection/ContactSupportButton") as Button
	assert(not support_button.disabled)
	support_button.pressed.emit()
	var support_tab := settings.get_node(VISUAL_ROOT + "LeftButtonArea/Buttons/Option06") as Button
	support_tab.pressed.emit()
	await process_frame
	assert(support_tab.button_pressed)

	print("SMOKE_SETTINGS_OPTIONS_PASS")
	quit(0)
