extends RefCounted

const ArtistPreviewStateScript := preload("res://core_ui/scripts/debug/artist_preview_state.gd")
const PRESETS_PATH := "res://debug/fixtures/artist_preview_presets.json"
const SNAPSHOTS_PATH := "res://debug/fixtures/artist_preview_snapshots.json"

var _presets: Dictionary = {}
var _snapshots: Dictionary = {}


func _init() -> void:
	_presets = _load_presets()
	_snapshots = _load_json(SNAPSHOTS_PATH, "Artist Studio preview snapshots")


func preset_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key in _presets.keys():
		names.append(StringName(String(key)))
	names.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return names


func preset_label(preset_name: StringName) -> String:
	return String(_preset(preset_name).get("label", String(preset_name)))


func create_state(preset_name: StringName) -> RefCounted:
	return ArtistPreviewStateScript.new(_snapshot(preset_name))


func uses_static_snapshots() -> bool:
	return true


func _preset(preset_name: StringName) -> Dictionary:
	return Dictionary(_presets.get(String(preset_name), {}))


func _snapshot(preset_name: StringName) -> Dictionary:
	return Dictionary(_snapshots.get(String(preset_name), {}))


func _load_presets() -> Dictionary:
	return _load_json(PRESETS_PATH, "Artist Studio preview presets")


func _load_json(path: String, label: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("%s could not be opened: %s" % [label, path])
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%s must be a JSON object." % label)
		return {}
	return Dictionary(parsed)
