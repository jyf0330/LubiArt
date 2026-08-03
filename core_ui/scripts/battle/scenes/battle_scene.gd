extends Control

## BattleArtScene page presentation coordinator. Game owns Session and routes
## semantic commands; this node only stages public Snapshot/Trace presentation.

signal command_requested(command: Dictionary)
signal trace_sequence_finished

const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const BattleTraceProjectionScript := preload("res://core_ui/scripts/battle/controllers/battle_trace_projection.gd")
const GameLogScript := preload("res://core/logging/game_log.gd")

@onready var board: Control = $Board
@onready var vfx_host: Control = $Board/VfxHost
@onready var hud: Control = $Hud
@onready var overlay: Control = $OverlayHost

var _assets: RefCounted = null
var _trace_projection := BattleTraceProjectionScript.new()
var _last_snapshot: Dictionary = {}
var _rendered_trace_count := -1
var _pending_final_snapshot: Dictionary = {}
var _pending_enemy_move_final_cells := {}
var _battle_input_locked := false


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and bool(overlay.call("has_visible_detail")):
		overlay.call("clear")
		get_viewport().set_input_as_handled()
