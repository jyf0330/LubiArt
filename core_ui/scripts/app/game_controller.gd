extends Control

const SessionFactoryScript := preload("res://session/session_factory.gd")
const FeatureRegistryScript := preload("res://core_ui/scripts/app/feature_registry.gd")
const SceneRouterScript := preload("res://core_ui/scripts/app/scene_router.gd")
const DEFAULT_RUN_SEED := "ysbzs-test-play-20260715-v1"

@onready var view_host: Control = $ViewHost

var state: RefCounted:
	get:
		if game_session != null and game_session.has_method("get_authority"):
			return game_session.call("get_authority") as RefCounted
		return null
	set(value):
		if value != null:
			set_game_session(SessionFactoryScript.wrap_local_authority(value))

var game_session: RefCounted = null
var feature_registry: RefCounted = null
var _scene_router: RefCounted = null


func _ready() -> void:
	if feature_registry == null:
		feature_registry = FeatureRegistryScript.new()
	if game_session == null:
		game_session = SessionFactoryScript.create_local({
			"run_seed": DEFAULT_RUN_SEED,
			"board_dimensions": SessionFactoryScript.command_line_board_dimensions()
		})
	_scene_router = SceneRouterScript.new(view_host, feature_registry)
	_scene_router.mount_feature(FeatureRegistryScript.DEFAULT_FEATURE, game_session)


func set_game_session(session: RefCounted) -> void:
	if session == null:
		return
	game_session = session
	_configure_active_view()


func set_feature_registry(registry: RefCounted) -> void:
	if registry == null:
		return
	feature_registry = registry
	if _scene_router != null:
		_scene_router.bind_registry(feature_registry)


func mount_feature(feature_id: StringName) -> Node:
	if _scene_router == null:
		return null
	return _scene_router.mount_feature(feature_id, game_session)


func get_game_session() -> RefCounted:
	return game_session


func get_active_view() -> Node:
	return _scene_router.active_view() if _scene_router != null else null


func get_feature_controller(feature_name: StringName) -> Variant:
	var view: Node = get_active_view()
	if view != null and view.has_method("get_feature_controller"):
		return view.call("get_feature_controller", feature_name)
	return null


func render_current_view() -> void:
	var view: Node = get_active_view()
	if view != null and view.has_method("render_current_snapshot"):
		view.call("render_current_snapshot")


func _configure_active_view() -> void:
	if not is_node_ready():
		return
	var view: Node = get_active_view()
	if view != null and view.has_method("configure"):
		view.call("configure", game_session)
