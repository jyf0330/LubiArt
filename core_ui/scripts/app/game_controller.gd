extends Control

## Application composition root. The Game Scene owns the single GameSession,
## command execution, persistence operations and feature Scene lifecycle. The
## authored ThreeChoiceScene and BattleArtScene are presentation surfaces and
## never own gameplay state or create sessions of their own.

const SessionFactoryScript := preload("res://session/session_factory.gd")
const DefaultTimepointThreeSaveBootstrapScript := preload("res://core/startup/default_timepoint_three_save_bootstrap.gd")
const SessionBridgeScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd")
const FeatureRegistryScript := preload("res://core_ui/scripts/app/feature_registry.gd")
const SceneRouterScript := preload("res://core_ui/scripts/app/scene_router.gd")
const SettingsMenuScene := preload("res://art/prefabs/battle/settings/settings_menu.tscn")
const PresentationCoordinatorScript := preload("res://core_ui/scripts/app/presentation_coordinator.gd")
const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")
const ShortcutCatalog := preload("res://core_ui/scripts/shared/shortcut_catalog.gd")
const UiPreferencesScript := preload("res://core_ui/scripts/app/ui_preferences.gd")
const RuntimeDiagnosticsScript := preload("res://diagnostics/runtime_diagnostics.gd")
const DEFAULT_RUN_SEED := "ysbzs-test-play-20260715-v1"
const TIMEPOINT_THREE_STARTUP_ARGUMENT := "--startup-save=timepoint-three"

@onready var three_choice_view: Control = $ThreeChoiceScene
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
var _session_bridge := SessionBridgeScript.new()
var _presentation_coordinator := PresentationCoordinatorScript.new()
var _visible_auto_battle_running := false
var _global_settings_menu: Control = null
var _button_shortcut_hints_visible := true
var _ui_preferences: RefCounted = UiPreferencesScript.new()
var _runtime_diagnostics: Node = null


func _ready() -> void:
	_runtime_diagnostics = RuntimeDiagnosticsScript.new()
	_runtime_diagnostics.name = "RuntimeDiagnostics"
	add_child(_runtime_diagnostics)
	_runtime_diagnostics.call("start")
	RuntimeUiPolicy.install()
	ShortcutCatalog.load_bindings(_ui_preferences.call("load_shortcut_bindings"))
	_button_shortcut_hints_visible = bool(
		_ui_preferences.call("load_button_shortcut_hints_visible", true)
	)
	if feature_registry == null:
		feature_registry = FeatureRegistryScript.new()
	if game_session == null:
		var creation := Dictionary(SessionFactoryScript.create_local_result({
			"run_seed": DEFAULT_RUN_SEED,
			"start_phase": "route",
			"board_dimensions": SessionFactoryScript.command_line_board_dimensions()
		}))
		if not bool(creation.get("ok", false)):
			_runtime_diagnostics.call("record_error", "GAME_SESSION_INIT_FAILED", Dictionary(creation.get("initialization", {})))
			push_error("GAME_SESSION_INIT_FAILED:%s" % JSON.stringify(creation.get("initialization", {})))
			return
		game_session = creation.get("session") as RefCounted
		if _should_prepare_direct_startup_save():
			var startup_result := Dictionary(DefaultTimepointThreeSaveBootstrapScript.prepare_and_load(
				game_session,
				DEFAULT_RUN_SEED
			))
			if not bool(startup_result.get("ok", false)):
				_runtime_diagnostics.call("record_error", "GAME_STARTUP_SAVE_FAILED", startup_result)
				push_error("GAME_STARTUP_SAVE_FAILED:%s" % JSON.stringify(startup_result))
				return
	_session_bridge.bind_session(game_session)
	_feature_router = SceneRouterScript.new(feature_host, feature_registry)
	_presentation_coordinator.configure(
		_session_bridge,
		three_choice_view,
		Callable(self, "_prepare_feature_for_snapshot"),
		Callable(self, "_release_features_not_required"),
		Callable(self, "_active_battle_view")
	)
	_connect_three_choice_view()
	_connect_session_bridge()
	var snapshot := _session_bridge.current_snapshot()
	_prepare_feature_for_snapshot(snapshot)
	_configure_three_choice_view(snapshot)
	_presentation_coordinator.adopt_presented_snapshot(snapshot)


func _should_prepare_direct_startup_save(
	arguments: PackedStringArray = PackedStringArray()
) -> bool:
	var resolved_arguments := arguments if not arguments.is_empty() else OS.get_cmdline_user_args()
	for argument_value in resolved_arguments:
		if String(argument_value).strip_edges().to_lower() == TIMEPOINT_THREE_STARTUP_ARGUMENT:
			return true
	return false


func _exit_tree() -> void:
	_presentation_coordinator.dispose()
	_session_bridge.dispose()
	if is_instance_valid(_runtime_diagnostics):
		_runtime_diagnostics.call("finish")


func set_game_session(session: RefCounted) -> void:
	if session == null:
		return
	_presentation_coordinator.reset_for_session()
	game_session = session
	_session_bridge.bind_session(game_session)
	if not is_node_ready():
		return
	_clear_battle()
	var snapshot := _session_bridge.current_snapshot()
	_prepare_feature_for_snapshot(snapshot)
	_configure_three_choice_view(snapshot)
	_presentation_coordinator.adopt_presented_snapshot(snapshot)


func set_feature_registry(registry: RefCounted) -> void:
	if registry == null:
		return
	feature_registry = registry
	if _feature_router != null:
		_feature_router.bind_registry(feature_registry)


func mount_feature(feature_id: StringName) -> Node:
	if feature_id == FeatureRegistryScript.THREE_CHOICE_FEATURE:
		return three_choice_view
	if feature_id == FeatureRegistryScript.BATTLE_FEATURE:
		return _mount_battle()
	return null


func get_game_session() -> RefCounted:
	return game_session


func get_three_choice_view() -> Control:
	return three_choice_view


func get_active_view() -> Node:
	return self


func get_active_feature_view() -> Node:
	return _feature_router.active_view() if _feature_router != null else null


func get_active_feature_id() -> StringName:
	return _feature_router.active_feature() if _feature_router != null else &""


func get_feature_controller(feature_name: StringName) -> Variant:
	if three_choice_view != null and three_choice_view.has_method("get_feature_controller"):
		return three_choice_view.call("get_feature_controller", feature_name)
	return null


func render_current_view() -> void:
	var snapshot := _session_bridge.current_snapshot()
	_presentation_coordinator.enqueue_external_snapshot(snapshot, {
		"reason": "manual_refresh",
		"asynchronous": true,
		"force": true,
		"animate_transition": false,
		"stateVersion": int(snapshot.get("stateVersion", -1)),
		"stateHash": String(snapshot.get("stateHash", "")),
	})


func get_missing_image_report() -> Array:
	if three_choice_view != null and three_choice_view.has_method("get_missing_image_report"):
		return Array(three_choice_view.call("get_missing_image_report"))
	return []


func get_battle_missing_mapping_report() -> Array:
	if three_choice_view != null and three_choice_view.has_method("get_battle_missing_mapping_report"):
		return Array(three_choice_view.call("get_battle_missing_mapping_report"))
	return []


func set_developer_tools_enabled(enabled: bool) -> void:
	if three_choice_view != null and three_choice_view.has_method("set_developer_tools_enabled"):
		three_choice_view.call("set_developer_tools_enabled", enabled)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_shortcut_press(event) \
			or not ShortcutCatalog.event_matches_action(event, ShortcutCatalog.ACTION_SAVE_LOAD):
		return
	if _text_input_has_focus():
		return
	_toggle_quick_save_load_toolbar()
	get_viewport().set_input_as_handled()


func _is_shortcut_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false


func _text_input_has_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


func _toggle_quick_save_load_toolbar() -> void:
	if three_choice_view != null and three_choice_view.has_method("toggle_quick_save_load_toolbar"):
		three_choice_view.call("toggle_quick_save_load_toolbar")


func _toggle_global_save_load_menu() -> void:
	var menu := _active_settings_menu()
	if menu != null and bool(menu.call("is_open")):
		if menu == _global_settings_menu:
			_dispose_global_settings_menu()
		else:
			menu.call("close_menu")
		return
	if menu != null:
		menu.call("open_menu")
		return
	_mount_global_settings_menu()


func _active_settings_menu() -> Control:
	if is_instance_valid(_global_settings_menu):
		return _global_settings_menu
	_global_settings_menu = null
	var feature_view := get_active_feature_view()
	if not is_instance_valid(feature_view):
		return null
	var runtime_view := feature_view
	if feature_view.has_method("get_runtime_view"):
		var candidate := feature_view.call("get_runtime_view") as Node
		if is_instance_valid(candidate):
			runtime_view = candidate
	var menu := runtime_view.get_node_or_null("OverlayHost/SettingsMenu") as Control
	if menu == null or not menu.has_method("open_menu") or not menu.has_method("is_open"):
		return null
	return menu


func _mount_global_settings_menu() -> void:
	var menu := SettingsMenuScene.instantiate() as Control
	if menu == null:
		push_error("GLOBAL_SETTINGS_MENU_INSTANTIATION_FAILED")
		return
	menu.name = "GlobalSettingsMenu"
	menu.visible = false
	_global_settings_menu = menu
	menu.connect(
		"session_operation_requested",
		Callable(self, "_on_battle_session_operation_requested")
	)
	if menu.has_signal("button_shortcut_hints_visibility_changed"):
		menu.connect(
			"button_shortcut_hints_visibility_changed",
			Callable(self, "_on_button_shortcut_hints_visibility_changed")
		)
	if menu.has_signal("shortcut_bindings_changed"):
		menu.connect(
			"shortcut_bindings_changed",
			Callable(self, "_on_shortcut_bindings_changed")
		)
	add_child(menu)
	menu.call("set_button_shortcut_hints_visible", _button_shortcut_hints_visible)
	if menu.has_method("configure_formal_session_mode"):
		menu.call("configure_formal_session_mode")
	menu.call("open_menu")


func _dispose_global_settings_menu() -> void:
	if not is_instance_valid(_global_settings_menu):
		_global_settings_menu = null
		return
	var menu := _global_settings_menu
	_global_settings_menu = null
	menu.call("close_menu")
	menu.queue_free()


func _connect_three_choice_view() -> void:
	var command_callback := Callable(self, "_on_command_requested")
	if three_choice_view.has_signal("command_requested") \
			and not three_choice_view.is_connected("command_requested", command_callback):
		three_choice_view.connect("command_requested", command_callback)
	var session_operation_callback := Callable(self, "_on_session_operation_requested")
	if three_choice_view.has_signal("session_operation_requested") \
			and not three_choice_view.is_connected("session_operation_requested", session_operation_callback):
		three_choice_view.connect("session_operation_requested", session_operation_callback)
func _connect_session_bridge() -> void:
	var callback := Callable(self, "_on_asynchronous_snapshot_received")
	if not _session_bridge.asynchronous_snapshot_received.is_connected(callback):
		_session_bridge.asynchronous_snapshot_received.connect(callback)


func _configure_three_choice_view(snapshot: Dictionary = {}) -> void:
	if three_choice_view == null:
		return
	if three_choice_view.has_method("configure_session_capabilities"):
		three_choice_view.call(
			"configure_session_capabilities",
			_session_bridge.supports_persistence(),
			_session_bridge.persistence_slot_count()
		)
	if three_choice_view.has_method("render_snapshot"):
		var current := snapshot if not snapshot.is_empty() else _session_bridge.current_snapshot()
		three_choice_view.call("render_snapshot", current, false)


func _on_command_requested(command: Dictionary, request_id: int) -> void:
	_presentation_coordinator.submit_command_request(command, request_id)


func _on_session_operation_requested(operation: StringName, arguments: Dictionary, request_id: int) -> void:
	var result := _perform_session_operation(operation, arguments)
	_presentation_coordinator.complete_session_operation(request_id, result, operation)


func _perform_session_operation(operation: StringName, arguments: Dictionary) -> Dictionary:
	var ok := false
	match operation:
		&"save":
			ok = _session_bridge.save_to_slot(int(arguments.get("slot", 0)))
		&"load":
			ok = _session_bridge.load_from_slot(int(arguments.get("slot", 0)))
		&"export_replay":
			ok = _session_bridge.export_replay()
		&"export_battle_trace":
			ok = _session_bridge.export_battle_trace()
	var result := {
		"ok": ok,
		"snapshot": _session_bridge.current_snapshot()
	}
	return result


func _on_battle_session_operation_requested(
	operation: StringName,
	arguments: Dictionary
) -> void:
	var result := _perform_session_operation(operation, arguments)
	var snapshot := Dictionary(result.get("snapshot", {}))
	_presentation_coordinator.enqueue_external_snapshot(snapshot, {
		"reason": "battle_session_operation:%s" % String(operation),
		"asynchronous": true,
		"force": true,
		"animate_transition": false,
		"stateVersion": int(snapshot.get("stateVersion", -1)),
		"stateHash": String(snapshot.get("stateHash", "")),
	})


func _on_button_shortcut_hints_visibility_changed(hints_visible: bool) -> void:
	_button_shortcut_hints_visible = hints_visible
	_ui_preferences.call("save_button_shortcut_hints_visible", hints_visible)
	if is_instance_valid(_global_settings_menu):
		_global_settings_menu.call("set_button_shortcut_hints_visible", hints_visible)
	var battle_scene: Node = _feature_router.active_view() if _feature_router != null else null
	if is_instance_valid(battle_scene) \
			and battle_scene.has_method("set_button_shortcut_hints_visible"):
		battle_scene.call("set_button_shortcut_hints_visible", hints_visible)


func _on_shortcut_bindings_changed(bindings: Dictionary) -> void:
	ShortcutCatalog.load_bindings(bindings)
	_ui_preferences.call("save_shortcut_bindings", ShortcutCatalog.serialized_bindings())


func _on_asynchronous_snapshot_received(snapshot: Dictionary, metadata: Dictionary) -> void:
	_presentation_coordinator.enqueue_external_snapshot(snapshot, metadata)


func _on_battle_command_requested(command: Dictionary) -> void:
	if command.is_empty():
		return
	_dispatch_battle_command(command.duplicate(true))


func _dispatch_battle_command(command: Dictionary) -> void:
	if String(command.get("type", "")) == "RUN_BATTLE":
		await _run_visible_auto_battle()
	else:
		await _submit_battle_command(command)


func _submit_battle_command(command: Dictionary) -> bool:
	return await _presentation_coordinator.submit_battle_command(command)


func _run_visible_auto_battle() -> void:
	if _visible_auto_battle_running:
		return
	_visible_auto_battle_running = true
	var guard := 0
	while String(_session_bridge.current_snapshot().get("phase", "")) == "battle" and guard < 40:
		guard += 1
		var pre_round_snapshot := _session_bridge.current_snapshot()
		if bool(Dictionary(Dictionary(pre_round_snapshot.get("pet_reset", {})).get("player", {})).get("eligible", false)):
			if not await _submit_battle_command({"type": "RESET_PETS"}):
				break
		if not await _submit_battle_command({"type": "AUTO_POSITION_HEROES"}):
			break
		if not await _submit_battle_command({"type": "RUN_COMBAT_ROUND"}):
			break
	_visible_auto_battle_running = false


func _mount_battle(snapshot: Dictionary = {}) -> Node:
	if _feature_router == null:
		return null
	if _feature_router.active_feature() == FeatureRegistryScript.BATTLE_FEATURE:
		return _feature_router.active_view()
	_clear_battle()
	var battle_scene: Node = _feature_router.mount_feature(FeatureRegistryScript.BATTLE_FEATURE)
	if battle_scene != null and battle_scene.has_signal("command_requested"):
		var command_callback := Callable(self, "_on_battle_command_requested")
		if not battle_scene.is_connected("command_requested", command_callback):
			battle_scene.connect("command_requested", command_callback)
	if battle_scene != null and battle_scene.has_signal("session_operation_requested"):
		var session_operation_callback := Callable(self, "_on_battle_session_operation_requested")
		if not battle_scene.is_connected("session_operation_requested", session_operation_callback):
			battle_scene.connect("session_operation_requested", session_operation_callback)
	if battle_scene != null and battle_scene.has_signal("button_shortcut_hints_visibility_changed"):
		var shortcut_hints_callback := Callable(self, "_on_button_shortcut_hints_visibility_changed")
		if not battle_scene.is_connected("button_shortcut_hints_visibility_changed", shortcut_hints_callback):
			battle_scene.connect("button_shortcut_hints_visibility_changed", shortcut_hints_callback)
	if battle_scene != null and battle_scene.has_signal("shortcut_bindings_changed"):
		var keybind_callback := Callable(self, "_on_shortcut_bindings_changed")
		if not battle_scene.is_connected("shortcut_bindings_changed", keybind_callback):
			battle_scene.connect("shortcut_bindings_changed", keybind_callback)
	if battle_scene != null and battle_scene.has_method("set_button_shortcut_hints_visible"):
		battle_scene.call("set_button_shortcut_hints_visible", _button_shortcut_hints_visible)
	if battle_scene != null and three_choice_view.has_method("attach_feature_view"):
		three_choice_view.call("attach_feature_view", FeatureRegistryScript.BATTLE_FEATURE, battle_scene)
	_presentation_coordinator.configure_battle_view(battle_scene)
	if battle_scene != null and battle_scene.has_method("render_snapshot"):
		var current := snapshot if not snapshot.is_empty() else _session_bridge.current_snapshot()
		battle_scene.call("render_snapshot", current)
	return battle_scene


func _clear_battle() -> void:
	if _feature_router == null:
		return
	var feature_id: StringName = _feature_router.active_feature()
	var feature_view: Node = _feature_router.active_view()
	if is_instance_valid(feature_view) and feature_view.has_signal("command_requested"):
		var command_callback := Callable(self, "_on_battle_command_requested")
		if feature_view.is_connected("command_requested", command_callback):
			feature_view.disconnect("command_requested", command_callback)
	if is_instance_valid(feature_view) and feature_view.has_signal("session_operation_requested"):
		var session_operation_callback := Callable(self, "_on_battle_session_operation_requested")
		if feature_view.is_connected("session_operation_requested", session_operation_callback):
			feature_view.disconnect("session_operation_requested", session_operation_callback)
	if is_instance_valid(feature_view) and feature_view.has_signal("button_shortcut_hints_visibility_changed"):
		var shortcut_hints_callback := Callable(self, "_on_button_shortcut_hints_visibility_changed")
		if feature_view.is_connected("button_shortcut_hints_visibility_changed", shortcut_hints_callback):
			feature_view.disconnect("button_shortcut_hints_visibility_changed", shortcut_hints_callback)
	if is_instance_valid(feature_view) and feature_view.has_signal("shortcut_bindings_changed"):
		var keybind_callback := Callable(self, "_on_shortcut_bindings_changed")
		if feature_view.is_connected("shortcut_bindings_changed", keybind_callback):
			feature_view.disconnect("shortcut_bindings_changed", keybind_callback)
	if is_instance_valid(feature_view) and three_choice_view.has_method("detach_feature_view"):
		three_choice_view.call("detach_feature_view", feature_id, feature_view)
	_visible_auto_battle_running = false
	_feature_router.clear()


func _active_battle_view() -> Node:
	if _feature_router == null or _feature_router.active_feature() != FeatureRegistryScript.BATTLE_FEATURE:
		return null
	return _feature_router.active_view()


func _required_feature_for_snapshot(snapshot: Dictionary) -> StringName:
	if String(snapshot.get("phase", "")) == "battle":
		return FeatureRegistryScript.BATTLE_FEATURE
	return &""


func _prepare_feature_for_snapshot(snapshot: Dictionary) -> void:
	var required_feature := _required_feature_for_snapshot(snapshot)
	if required_feature == FeatureRegistryScript.BATTLE_FEATURE:
		_mount_battle(snapshot)


func _release_features_not_required(snapshot: Dictionary) -> void:
	if _feature_router == null:
		return
	var active_feature: StringName = _feature_router.active_feature()
	if active_feature != &"" and active_feature != _required_feature_for_snapshot(snapshot):
		_clear_battle()
