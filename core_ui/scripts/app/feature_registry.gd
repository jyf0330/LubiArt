extends RefCounted

## Explicit feature-to-scene registry for the game composition shell. New
## top-level features register here instead of adding another branch to the
## shell or router.

const ARTIST_FLOW_SCENE := preload("res://art/scenes/artist_flow/artist_flow_view.tscn")
const DEFAULT_FEATURE := &"artist_flow"

var _scenes: Dictionary = {}


func _init(register_defaults: bool = true) -> void:
	if register_defaults:
		register_feature(DEFAULT_FEATURE, ARTIST_FLOW_SCENE)


func register_feature(feature_id: StringName, scene: PackedScene, replace_existing: bool = false) -> bool:
	if String(feature_id).is_empty() or scene == null:
		return false
	if _scenes.has(feature_id) and not replace_existing:
		return false
	_scenes[feature_id] = scene
	return true


func unregister_feature(feature_id: StringName) -> bool:
	return _scenes.erase(feature_id)


func has_feature(feature_id: StringName) -> bool:
	return _scenes.has(feature_id)


func scene_for(feature_id: StringName) -> PackedScene:
	return _scenes.get(feature_id) as PackedScene


func feature_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for feature_id in _scenes.keys():
		ids.append(StringName(feature_id))
	ids.sort()
	return ids
