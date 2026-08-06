extends RefCounted

## Local presentation preferences only. This file never reads or writes formal
## save slots, battle Snapshot data, Session state, or balance configuration.

const DEFAULT_PATH := "user://ui_preferences.cfg"
const PATH_OVERRIDE_ENV := "YSBZS_UI_PREFERENCES_PATH"
const BATTLE_UI_SECTION := "battle_ui"
const SHORTCUT_HINTS_KEY := "show_button_shortcut_hints"
const KEYBINDS_SECTION := "keybinds"

var _path := DEFAULT_PATH


func _init() -> void:
	var override_path := OS.get_environment(PATH_OVERRIDE_ENV).strip_edges()
	if override_path != "":
		_path = override_path


func load_button_shortcut_hints_visible(default_value := true) -> bool:
	var config := ConfigFile.new()
	var load_error := config.load(_path)
	if load_error == ERR_FILE_NOT_FOUND:
		return default_value
	if load_error != OK:
		push_warning("UI_PREFERENCES_LOAD_FAILED: %s" % error_string(load_error))
		return default_value
	return bool(config.get_value(BATTLE_UI_SECTION, SHORTCUT_HINTS_KEY, default_value))


func save_button_shortcut_hints_visible(hints_visible: bool) -> bool:
	var config := ConfigFile.new()
	var load_error := config.load(_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("UI_PREFERENCES_EXISTING_FILE_LOAD_FAILED: %s" % error_string(load_error))
	config.set_value(BATTLE_UI_SECTION, SHORTCUT_HINTS_KEY, hints_visible)
	var save_error := config.save(_path)
	if save_error != OK:
		push_warning("UI_PREFERENCES_SAVE_FAILED: %s" % error_string(save_error))
		return false
	return true


func load_shortcut_bindings() -> Dictionary:
	var config := ConfigFile.new()
	var load_error := config.load(_path)
	if load_error == ERR_FILE_NOT_FOUND:
		return {}
	if load_error != OK:
		push_warning("UI_PREFERENCES_LOAD_FAILED: %s" % error_string(load_error))
		return {}
	if not config.has_section(KEYBINDS_SECTION):
		return {}
	var bindings := {}
	for action_id in config.get_section_keys(KEYBINDS_SECTION):
		var binding: Variant = config.get_value(KEYBINDS_SECTION, action_id, {})
		if binding is Dictionary:
			bindings[action_id] = Dictionary(binding)
	return bindings


func save_shortcut_bindings(bindings: Dictionary) -> bool:
	var config := ConfigFile.new()
	var load_error := config.load(_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("UI_PREFERENCES_EXISTING_FILE_LOAD_FAILED: %s" % error_string(load_error))
	if config.has_section(KEYBINDS_SECTION):
		config.erase_section(KEYBINDS_SECTION)
	for action_value in bindings:
		var binding: Variant = bindings[action_value]
		if binding is Dictionary:
			config.set_value(KEYBINDS_SECTION, String(action_value), Dictionary(binding))
	var save_error := config.save(_path)
	if save_error != OK:
		push_warning("UI_PREFERENCES_SAVE_FAILED: %s" % error_string(save_error))
		return false
	return true
