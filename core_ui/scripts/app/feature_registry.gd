extends RefCounted

## Registry for the only Scene mounted by the three-choice composition root.
## The three-choice Scene is already alive, so it is not registered as a child.

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const THREE_CHOICE_FEATURE := &"three_choice"
const BATTLE_FEATURE := &"battle"

var _scenes: Dictionary = {}


func _init(register_defaults: bool = true) -> void:
	if register_defaults:
		register_feature(BATTLE_FEATURE, BATTLE_SCENE)


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
