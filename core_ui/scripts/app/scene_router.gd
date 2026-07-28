extends RefCounted

## Owns the lifecycle of one view mounted below the three-choice composition.

var _host: Node = null
var _active_view: Node = null
var _registry: RefCounted = null
var _active_feature: StringName = &""


func _init(host: Node = null, registry: RefCounted = null) -> void:
	_host = host
	_registry = registry


func bind_host(host: Node) -> void:
	if _host == host:
		return
	clear()
	_host = host


func bind_registry(registry: RefCounted) -> void:
	_registry = registry


func mount_feature(feature_id: StringName, session: RefCounted = null) -> Node:
	if _registry == null or not _registry.has_method("scene_for"):
		return null
	var scene := _registry.call("scene_for", feature_id) as PackedScene
	var view := mount(scene, session)
	if view != null:
		_active_feature = feature_id
	return view


func mount(scene: PackedScene, session: RefCounted = null) -> Node:
	if _host == null or scene == null:
		return null
	clear()
	_active_view = scene.instantiate()
	if session != null and _active_view.has_method("configure"):
		_active_view.call("configure", session)
	_host.add_child(_active_view)
	return _active_view


func clear() -> void:
	if is_instance_valid(_active_view):
		_active_view.queue_free()
	_active_view = null
	_active_feature = &""


func active_view() -> Node:
	return _active_view if is_instance_valid(_active_view) else null


func active_feature() -> StringName:
	return _active_feature
