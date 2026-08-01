extends "res://core_ui/scripts/artist_flow/controllers/artist_flow_view_adapter.gd"

## The three-choice Scene is both the authored route surface and the
## composition root. It owns the single GameSession and only mounts the battle
## Scene when the authoritative phase requires it.

const SessionFactoryScript := preload("res://session/session_factory.gd")
const FeatureRegistryScript := preload("res://core_ui/scripts/app/feature_registry.gd")
const SceneRouterScript := preload("res://core_ui/scripts/app/scene_router.gd")
const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")
const DEFAULT_RUN_SEED := "ysbzs-test-play-20260715-v1"

@onready var feature_host: Control = $FeatureHost

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
var _feature_router: RefCounted = null


func _ready() -> void:
	RuntimeUiPolicy.install()
	var debug_button := get_node_or_null("MainBG/DebugButton") as Control
	if debug_button != null:
		debug_button.visible = RuntimeUiPolicy.developer_tools_enabled()
		debug_button.mouse_filter = Control.MOUSE_FILTER_STOP if debug_button.visible else Control.MOUSE_FILTER_IGNORE
	if feature_registry == null:
		feature_registry = FeatureRegistryScript.new()
	if game_session == null:
		game_session = SessionFactoryScript.create_local({
			"run_seed": DEFAULT_RUN_SEED,
			"board_dimensions": SessionFactoryScript.command_line_board_dimensions()
		})
	_feature_router = SceneRouterScript.new(feature_host, feature_registry)
	super()
	if not feature_view_requested.is_connected(_on_feature_view_requested):
		feature_view_requested.connect(_on_feature_view_requested)
	if not feature_view_release_requested.is_connected(_on_feature_view_release_requested):
		feature_view_release_requested.connect(_on_feature_view_release_requested)
	configure(game_session)
	_sync_phase_feature()


func set_game_session(session: RefCounted) -> void:
	if session == null:
		return
	game_session = session
	configure(game_session)
	_sync_phase_feature()


func set_feature_registry(registry: RefCounted) -> void:
	if registry == null:
		return
	feature_registry = registry
	if _feature_router != null:
		_feature_router.bind_registry(feature_registry)


func mount_feature(feature_id: StringName) -> Node:
	if feature_id == FeatureRegistryScript.THREE_CHOICE_FEATURE:
		return self
	if feature_id == FeatureRegistryScript.BATTLE_FEATURE:
		return _mount_battle()
	return null


func get_game_session() -> RefCounted:
	return game_session


func get_active_view() -> Node:
	return self


func get_active_feature_view() -> Node:
	return _feature_router.active_view() if _feature_router != null else null


func get_active_feature_id() -> StringName:
	return _feature_router.active_feature() if _feature_router != null else &""


func render_current_view() -> void:
	render_current_snapshot()


func _on_feature_view_requested(feature_id: StringName) -> void:
	if feature_id == FeatureRegistryScript.BATTLE_FEATURE:
		_mount_battle()


func _on_feature_view_release_requested(feature_id: StringName) -> void:
	if _feature_router != null and _feature_router.active_feature() == feature_id:
		_clear_battle()


func _mount_battle() -> Node:
	if _feature_router == null:
		return null
	if _feature_router.active_feature() == FeatureRegistryScript.BATTLE_FEATURE:
		return _feature_router.active_view()
	_clear_battle()
	var battle_scene: Node = _feature_router.mount_feature(FeatureRegistryScript.BATTLE_FEATURE, game_session)
	if battle_scene != null:
		attach_feature_view(FeatureRegistryScript.BATTLE_FEATURE, battle_scene)
	return battle_scene


func _clear_battle() -> void:
	if _feature_router == null:
		return
	var feature_id: StringName = _feature_router.active_feature()
	var feature_view: Node = _feature_router.active_view()
	if is_instance_valid(feature_view):
		detach_feature_view(feature_id, feature_view)
	_feature_router.clear()


func _sync_phase_feature() -> void:
	if not is_node_ready() or game_session == null or not game_session.has_method("current_snapshot"):
		return
	var snap := Dictionary(game_session.call("current_snapshot"))
	if String(snap.get("phase", "")) == "battle":
		var battle_scene := _mount_battle()
		if battle_scene != null:
			call_deferred("render_current_snapshot")
	elif _feature_router != null and _feature_router.active_feature() == FeatureRegistryScript.BATTLE_FEATURE:
		_clear_battle()
