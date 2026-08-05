extends Control

## BattleArtScene page presentation coordinator. Game owns Session and routes
## semantic commands; this node only stages public Snapshot/Trace presentation.

signal command_requested(command: Dictionary)
signal session_operation_requested(operation: StringName, arguments: Dictionary)
signal trace_sequence_finished

const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const BattleTraceProjectionScript := preload("res://core_ui/scripts/battle/controllers/battle_trace_projection.gd")
const GameLogScript := preload("res://core/logging/game_log.gd")

@onready var board: Control = $Board
@onready var vfx_host: Control = $Board/VfxHost
@onready var hud: Control = $Hud
@onready var overlay: Control = $OverlayHost
@onready var settings_menu: Control = $OverlayHost/SettingsMenu
@onready var map_controls: Control = $MapControls
@onready var map_debug_button: Button = $MapDebugButton
@onready var shortcut_hint_debug_button: Button = $ShortcutHintDebugButton
@onready var map_auto_arrange_button: TextureButton = $MapControls/AutoArrangeButton
@onready var map_reset_button: TextureButton = $MapControls/ResetButton
@onready var map_all_out_button: TextureButton = $MapControls/AllOutButton

var _assets: RefCounted = null
var _trace_projection := BattleTraceProjectionScript.new()
var _last_snapshot: Dictionary = {}
var _rendered_trace_count := -1
var _pending_final_snapshot: Dictionary = {}
var _pending_enemy_move_final_cells := {}
var _battle_input_locked := false
var _debug_map_index := -1


func _ready() -> void:
	_assets = BattleAssetRegistryScript.new()
	board.call("configure", _assets)
	overlay.call("configure", _assets)
	_connect_command_source(board)
	_connect_command_source(hud)
	if board.has_signal("cell_detail_requested"):
		board.connect("cell_detail_requested", Callable(self, "_on_cell_detail_requested"))
	if hud.has_signal("direction_preview_changed"):
		hud.connect("direction_preview_changed", Callable(self, "_on_direction_preview_changed"))
	if vfx_host.has_method("configure"):
		vfx_host.call("configure", board.get_node("CellHost"), board.get_node("UnitHost"), _assets)
	_connect_vfx_signal("pets_reset_reveal_requested", "_on_pets_reset_reveal_requested")
	_connect_vfx_signal("trace_sequence_started", "_on_trace_sequence_started")
	_connect_vfx_signal("trace_sequence_finished", "_on_trace_sequence_finished")
	_connect_vfx_signal("enemy_move_projection_requested", "_on_enemy_move_projection_requested")
	if settings_menu.has_signal("session_operation_requested"):
		settings_menu.connect(
			"session_operation_requested",
			Callable(self, "_on_settings_session_operation_requested")
		)
	_connect_map_controls()
	map_debug_button.pressed.connect(_on_map_debug_button_pressed)
	shortcut_hint_debug_button.pressed.connect(_on_shortcut_hint_debug_button_pressed)
	_update_shortcut_hint_debug_button_label()


func get_runtime_view() -> Control:
	return self


func is_battle_input_locked() -> bool:
	return _battle_input_locked


func render_snapshot(snapshot: Dictionary) -> void:
	var incoming := snapshot.duplicate(true)
	var previous := _last_snapshot.duplicate(true)
	var new_events := Array(_trace_projection.call("new_events", incoming, _rendered_trace_count))
	var stage_from_previous := not new_events.is_empty() and not previous.is_empty()
	_last_snapshot = incoming
	var visible_snapshot := previous if stage_from_previous else incoming
	var final_cells := Array(Dictionary(incoming.get("board", {})).get("cells", [])).duplicate(true)
	var visible_cells := Array(Dictionary(visible_snapshot.get("board", {})).get("cells", [])).duplicate(true)
	var pending_reset_ids := Dictionary(_trace_projection.call("pending_reset_unit_ids", new_events))
	if stage_from_previous:
		_pending_final_snapshot = incoming.duplicate(true)
		_pending_enemy_move_final_cells.merge(
			Dictionary(_trace_projection.call("collect_enemy_move_final_cells", final_cells, new_events)),
			true
		)
		pending_reset_ids = {}
	else:
		_pending_final_snapshot = {}
		_pending_enemy_move_final_cells.merge(
			Dictionary(_trace_projection.call("defer_enemy_move_projection", visible_cells, new_events)),
			true
		)
	board.call("render_snapshot", visible_snapshot, visible_cells, pending_reset_ids)
	hud.call("render_snapshot", visible_snapshot)
	overlay.call("render_snapshot", visible_snapshot)
	_sync_map_controls(visible_snapshot)
	if not new_events.is_empty():
		_rendered_trace_count = Array(incoming.get("battleTrace", incoming.get("battle_trace", []))).size()
		_set_battle_input_locked(true)
		play_battle_trace(new_events)
	elif _rendered_trace_count < 0:
		_rendered_trace_count = Array(incoming.get("battleTrace", incoming.get("battle_trace", []))).size()


func play_battle_trace(events: Array) -> void:
	if events.is_empty():
		return
	if vfx_host == null or not vfx_host.has_method("play_trace"):
		GameLogScript.warning("表现/战斗事件", "VFX 不可用，直接应用最终快照")
		_apply_staged_final_snapshot()
		return
	vfx_host.call("play_trace", events)


func _connect_command_source(source: Node) -> void:
	if source == null or not source.has_signal("command_requested"):
		return
	var callback := Callable(self, "_on_command_requested")
	if not source.is_connected("command_requested", callback):
		source.connect("command_requested", callback)


func _connect_vfx_signal(signal_name: StringName, method_name: StringName) -> void:
	if vfx_host == null or not vfx_host.has_signal(signal_name):
		return
	var callback := Callable(self, method_name)
	if not vfx_host.is_connected(signal_name, callback):
		vfx_host.connect(signal_name, callback)


func _on_command_requested(command: Dictionary) -> void:
	if _battle_input_locked or command.is_empty():
		return
	command_requested.emit(command.duplicate(true))


func _on_cell_detail_requested(grid: Vector2i, unit_id: String) -> void:
	if grid.x < 0 or grid.y < 0:
		overlay.call("clear")
		return
	overlay.call("request_detail", grid, unit_id)


func _on_direction_preview_changed(preview: Dictionary) -> void:
	if preview.is_empty():
		board.call("show_direction_preview", "", "")
		return
	board.call(
		"show_direction_preview",
		String(preview.get("unit_id", preview.get("unitId", ""))),
		String(preview.get("direction", "right"))
	)


func _on_enemy_move_projection_requested(event: Dictionary) -> void:
	var actor := Dictionary(event.get("actor", {}))
	var unit_id := String(event.get("unitId", actor.get("id", "")))
	var final_cell := Dictionary(_pending_enemy_move_final_cells.get(unit_id, {}))
	if unit_id == "" or final_cell.is_empty():
		return
	board.call("apply_enemy_move_final_cell", unit_id, final_cell)
	_pending_enemy_move_final_cells.erase(unit_id)


func _on_pets_reset_reveal_requested(units: Array) -> void:
	board.call("reveal_reset_units", units)


func _on_trace_sequence_started() -> void:
	_set_battle_input_locked(true)


func _on_trace_sequence_finished() -> void:
	_apply_staged_final_snapshot()


func _apply_staged_final_snapshot() -> void:
	if not _pending_final_snapshot.is_empty():
		var final_snapshot := _pending_final_snapshot.duplicate(true)
		_pending_final_snapshot = {}
		var final_cells := Array(Dictionary(final_snapshot.get("board", {})).get("cells", [])).duplicate(true)
		board.call("render_snapshot", final_snapshot, final_cells)
		hud.call("render_snapshot", final_snapshot)
		overlay.call("render_snapshot", final_snapshot)
		_sync_map_controls(final_snapshot)
	else:
		for unit_id_value in _pending_enemy_move_final_cells.keys():
			board.call("apply_enemy_move_final_cell", String(unit_id_value), Dictionary(_pending_enemy_move_final_cells[unit_id_value]))
	_pending_enemy_move_final_cells.clear()
	_set_battle_input_locked(false)
	trace_sequence_finished.emit()


func _set_battle_input_locked(locked: bool) -> void:
	_battle_input_locked = locked
	board.call("set_input_locked", locked)
	hud.call("set_input_locked", locked)
	_update_map_control_availability(_last_snapshot)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_menu_is_open():
		settings_menu.call("handle_cancel")
	elif bool(overlay.call("has_visible_detail")):
		overlay.call("clear")
	else:
		settings_menu.call("open_menu")
	get_viewport().set_input_as_handled()


func _settings_menu_is_open() -> bool:
	return settings_menu != null and bool(settings_menu.call("is_open"))


func _connect_map_controls() -> void:
	var connections := {
		"settings_requested": Callable(self, "_on_map_settings_requested"),
		"attack_order_requested": Callable(self, "_on_map_attack_order_requested"),
		"auto_arrange_requested": Callable(self, "_on_map_auto_arrange_requested"),
		"reset_requested": Callable(self, "_on_map_reset_requested"),
		"all_out_requested": Callable(self, "_on_map_all_out_requested"),
	}
	for signal_name in connections:
		var callback := connections[signal_name] as Callable
		if map_controls.has_signal(signal_name) and not map_controls.is_connected(signal_name, callback):
			map_controls.connect(signal_name, callback)


func _sync_map_controls(snapshot: Dictionary) -> void:
	if _assets != null and _assets.has_method("battle_background_key"):
		var map_id := String(_assets.call("battle_background_key", snapshot))
		if bool(map_controls.call("set_map_by_id", map_id)):
			_debug_map_index = int(map_controls.call("get_map_index"))
			_update_map_debug_button_label()
	_update_map_control_availability(snapshot)


func _update_map_control_availability(snapshot: Dictionary) -> void:
	var phase_is_battle := String(snapshot.get("phase", "")) == "battle"
	map_auto_arrange_button.disabled = _battle_input_locked or not phase_is_battle
	map_all_out_button.disabled = _battle_input_locked or not phase_is_battle
	var reset_state := Dictionary(Dictionary(snapshot.get("pet_reset", {})).get("player", {}))
	map_reset_button.disabled = (
		_battle_input_locked or not phase_is_battle or not bool(reset_state.get("eligible", false))
	)


func _on_map_settings_requested() -> void:
	if _settings_menu_is_open():
		settings_menu.call("handle_cancel")
	elif bool(overlay.call("has_visible_detail")):
		overlay.call("clear")
	else:
		settings_menu.call("open_menu")


func _on_map_attack_order_requested() -> void:
	if hud.has_method("toggle_attack_timeline"):
		hud.call("toggle_attack_timeline")


func _on_map_auto_arrange_requested() -> void:
	if _battle_input_locked or map_auto_arrange_button.disabled:
		return
	map_auto_arrange_button.disabled = true
	if hud.has_method("request_auto_arrange"):
		hud.call("request_auto_arrange")


func _on_map_reset_requested() -> void:
	if _battle_input_locked or map_reset_button.disabled:
		return
	command_requested.emit({"type": "RESET_PETS"})


func _on_map_all_out_requested() -> void:
	if _battle_input_locked or map_all_out_button.disabled:
		return
	if hud.has_method("request_begin_turn"):
		hud.call("request_begin_turn")


func _on_shortcut_hint_debug_button_pressed() -> void:
	map_controls.call("toggle_shortcut_hints")
	_update_shortcut_hint_debug_button_label()


func _update_shortcut_hint_debug_button_label() -> void:
	var hints_visible := bool(map_controls.call("are_shortcut_hints_visible"))
	shortcut_hint_debug_button.text = "Shortcut Hints: %s" % ("ON" if hints_visible else "OFF")


func _on_map_debug_button_pressed() -> void:
	var map_ids := map_controls.call("get_map_ids") as PackedStringArray
	if map_ids.is_empty():
		return
	_debug_map_index = (_debug_map_index + 1) % map_ids.size()
	if not bool(map_controls.call("set_map_by_index", _debug_map_index)):
		return
	var texture := map_controls.call("get_map_texture") as Texture2D
	if texture != null and board.has_method("set_background_texture"):
		board.call("set_background_texture", texture)
	_update_map_debug_button_label()


func _update_map_debug_button_label() -> void:
	map_debug_button.text = "调试地图：%s" % String(map_controls.call("get_map_display_name"))


func _on_settings_session_operation_requested(
	operation: StringName,
	arguments: Dictionary
) -> void:
	session_operation_requested.emit(operation, arguments.duplicate(true))
