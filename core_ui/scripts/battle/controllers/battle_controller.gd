extends Control

signal command_requested(command: Dictionary)
signal trace_sequence_finished

const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const BattleBoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const BattleBoardControllerScript := preload("res://core_ui/scripts/battle/controllers/battle_board_controller.gd")
const BattleHudControllerScript := preload("res://core_ui/scripts/battle/controllers/battle_hud_controller.gd")
const BattleDetailControllerScript := preload("res://core_ui/scripts/battle/controllers/battle_detail_controller.gd")
const BattleCommandBuilderScript := preload("res://core_ui/scripts/battle/controllers/battle_command_builder.gd")
const BattleTraceProjectionScript := preload("res://core_ui/scripts/battle/controllers/battle_trace_projection.gd")
const GameLogScript := preload("res://core/logging/game_log.gd")
const BattleCellScene := preload("res://art/prefabs/terrain/terrain.tscn")
const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")
const PetDetailPanelScene := preload("res://art/prefabs/pet/pet_detail.tscn")
const TerrainDetailScene := preload("res://art/prefabs/terrain/terrain_detail.tscn")

const DEFAULT_BOARD_COLUMNS := BattleBoardDimensionsScript.DEFAULT_WIDTH
const DEFAULT_BOARD_ROWS := BattleBoardDimensionsScript.DEFAULT_HEIGHT
const CELL_GAP := Vector2.ZERO
const COMMAND_TOOL_SIZE := Vector2(118.0, 42.0)
const DETAIL_PANEL_SIZE := Vector2(314.0, 528.0)
const DETAIL_PANEL_POSITION := Vector2(1574.0, 132.0)
const DRAG_CLICK_THRESHOLD := 12.0
const DROP_SETTLE_DURATION := 0.12
const DROP_RETURN_DURATION := 0.16

@onready var board: Control = $Board
@onready var top_info_bar: Control = $TopInfoBar
@onready var cell_detail: Control = $CellDetail
@onready var board_grid: Control = board.call("get_board_grid") as Control
@onready var auto_arrange_button: TextureButton = board.call("get_auto_arrange_button") as TextureButton
@onready var position_difficulty_button: Button = board.call("get_position_difficulty_button") as Button
@onready var begin_turn_button: TextureButton = board.call("get_begin_turn_button") as TextureButton
@onready var vfx_player: Control = board.call("get_vfx_player") as Control

var _assets: RefCounted = null
var _cell_size := Vector2.ZERO
var _cells: Array[Control] = []
var _cell_pool: Array[Control] = []
var _board_columns := DEFAULT_BOARD_COLUMNS
var _board_rows := DEFAULT_BOARD_ROWS
var _last_snapshot: Dictionary = {}
var _missing_mappings := {}
var _rendered_trace_count := -1
var _hovered_grid := Vector2i(-1, -1)
var _drag_unit_id := ""
var _drag_origin := Vector2i(-1, -1)
var _drag_preview: Control = null
var _drag_offset := Vector2.ZERO
var _drag_preview_target := Vector2i(-1, -1)
var _debug_drag_preview_target := Vector2i(-1, -1)
var _drag_attack_highlight_keys: Array[String] = []
var _drag_attack_marker_keys: Array[String] = []
var _drag_hover_grid := Vector2i(-1, -1)
var _drag_start_mouse_position := Vector2.ZERO
var _drag_has_moved := false
var _drop_settle_active := false
var _drop_settle_preview: Control = null
var _drop_settle_unit_id := ""
var _drop_settle_grid := Vector2i(-1, -1)
var _last_drop_settle_summary: Dictionary = {}
var _suppress_next_select := false
var _initial_round_banner_requested := false
var _last_debug_drag_command: Dictionary = {}
var _command_tools: PanelContainer = null
var _action_panel: Control = null
var _direction_drawer: Control = null
var _preview_highlights: Dictionary = {}
var _detail_panel: Control = null
var _element_detail_panel: PanelContainer = null
var _active_detail_grid := Vector2i(-1, -1)
var _active_detail_unit_id := ""
var _battle_input_locked := false
var _pending_enemy_move_final_cells := {}
var _pending_final_snapshot: Dictionary = {}
var _pending_action_panel_snapshot: Dictionary = {}
var _last_rendered_cell_count := 0
var _auto_position_feedback_pending := false
var _position_feedback_serial := 0
var _board_controller := BattleBoardControllerScript.new()
var _hud_controller := BattleHudControllerScript.new()
var _detail_controller := BattleDetailControllerScript.new()
var _command_builder := BattleCommandBuilderScript.new()
var _trace_projection := BattleTraceProjectionScript.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	set_process(false)
	_assets = BattleAssetRegistryScript.new()
	_build_board()
	if vfx_player != null and vfx_player.has_method("configure"):
		vfx_player.call("configure", board_grid, _assets)
	if vfx_player != null and vfx_player.has_signal("pets_reset_reveal_requested"):
		if not vfx_player.pets_reset_reveal_requested.is_connected(_on_pets_reset_reveal_requested):
			vfx_player.pets_reset_reveal_requested.connect(_on_pets_reset_reveal_requested)
	if vfx_player != null and vfx_player.has_signal("trace_sequence_started"):
		if not vfx_player.trace_sequence_started.is_connected(_on_trace_sequence_started):
			vfx_player.trace_sequence_started.connect(_on_trace_sequence_started)
	if vfx_player != null and vfx_player.has_signal("trace_sequence_finished"):
		if not vfx_player.trace_sequence_finished.is_connected(_on_trace_sequence_finished):
			vfx_player.trace_sequence_finished.connect(_on_trace_sequence_finished)
	if vfx_player != null and vfx_player.has_signal("enemy_move_projection_requested"):
		if not vfx_player.enemy_move_projection_requested.is_connected(_on_enemy_move_projection_requested):
			vfx_player.enemy_move_projection_requested.connect(_on_enemy_move_projection_requested)
	board.call(
		"bind_primary_actions",
		Callable(self, "_on_auto_arrange_pressed"),
		Callable(self, "_on_position_difficulty_toggled"),
		Callable(self, "_on_begin_turn_pressed")
	)
	_style_position_difficulty_button()
	_update_position_difficulty_button({})
	_ensure_detail_panel()
	_ensure_action_panel()
	_ensure_direction_drawer()


func get_runtime_view() -> Control:
	return self


func _process(_delta: float) -> void:
	_update_drag_preview()


func _input(event: InputEvent) -> void:
	if _battle_input_locked:
		return
	if _drag_unit_id == "" or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
		return
	var board_local := board_grid.get_global_transform_with_canvas().affine_inverse() * mouse_event.position
	_finish_unit_drag(_grid_from_board_position(board_local))
	get_viewport().set_input_as_handled()


func render_snapshot(snap: Dictionary) -> void:
	var previous_snapshot := _last_snapshot.duplicate(true)
	var new_trace_events := Array(_trace_projection.call("new_events", snap, _rendered_trace_count))
	var stages_trace_from_previous := not new_trace_events.is_empty() and not previous_snapshot.is_empty()
	_last_snapshot = snap.duplicate(true)
	_missing_mappings = {}
	var board := Dictionary(snap.get("board", {}))
	_set_board_dimensions(BattleBoardDimensionsScript.from_board(board, Vector2i(_board_columns, _board_rows)))
	_ensure_board()
	_clear_all_cell_highlights()
	var final_cells := Array(board.get("cells", [])).duplicate(true)
	var cells := final_cells
	var pending_reset_ids := Dictionary(_trace_projection.call("pending_reset_unit_ids", new_trace_events))
	if stages_trace_from_previous:
		_pending_final_snapshot = snap.duplicate(true)
		cells = Array(Dictionary(previous_snapshot.get("board", {})).get("cells", [])).duplicate(true)
		_pending_enemy_move_final_cells.merge(
			Dictionary(_trace_projection.call("collect_enemy_move_final_cells", final_cells, new_trace_events)),
			true
		)
		pending_reset_ids = {}
	else:
		_pending_final_snapshot = {}
		_pending_enemy_move_final_cells.merge(
			Dictionary(_trace_projection.call("defer_enemy_move_projection", cells, new_trace_events)),
			true
		)
	_last_rendered_cell_count = 0
	_render_board_cells(cells, pending_reset_ids)
	_apply_selected_action_block_ranges(previous_snapshot if stages_trace_from_previous else snap)
	if not stages_trace_from_previous:
		_apply_artist_preview_highlights(snap)
	_restore_drag_visual_state()
	_restore_drop_settle_visual_state()
	_render_pet_detail(previous_snapshot if stages_trace_from_previous else snap)
	if stages_trace_from_previous:
		_pending_action_panel_snapshot = snap.duplicate(true)
		_render_action_panel(previous_snapshot)
		_render_direction_drawer(previous_snapshot)
	else:
		_pending_action_panel_snapshot = {}
		_render_action_panel(snap)
		_render_direction_drawer(snap)
	_play_initial_round_banner_if_needed(snap)
	_play_new_trace_events(snap)
	_update_position_difficulty_button(snap)
	_consume_auto_position_feedback(snap)


func _render_board_cells(cells: Array, pending_reset_ids: Dictionary = {}) -> void:
	for cell_value in cells:
		var cell := Dictionary(cell_value).duplicate(true)
		var x := int(cell.get("x", cell.get("c", -1)))
		var y := int(cell.get("y", cell.get("r", -1)))
		if not _is_visible_board_cell(x, y):
			continue
		if pending_reset_ids.has(String(cell.get("unitId", cell.get("unit_id", "")))):
			_trace_projection.call("clear_cell_unit_projection", cell)
		var cell_node := _cell_at(x, y)
		var transient_element_dirty := false
		if cell_node.has_method("consume_transient_element_visual_dirty"):
			transient_element_dirty = bool(cell_node.call("consume_transient_element_visual_dirty"))
		var cell_changed := _cell_data_for_cell(cell_node) != cell or transient_element_dirty
		if cell_changed and cell_node.has_method("set_cell_data"):
			cell_node.call("set_cell_data", cell, _assets)
			_render_cell_trace_effects(cell_node, cell)
			_last_rendered_cell_count += 1
		_collect_cell_missing_mappings(cell_node)


func _apply_selected_action_block_ranges(snap: Dictionary) -> void:
	for cell in _cells:
		if cell == null or not cell.has_method("get_unit_node"):
			continue
		var unit_node := cell.call("get_unit_node") as Control
		if unit_node != null and unit_node.has_method("hide_action_block_attack_ranges"):
			unit_node.call("hide_action_block_attack_ranges")
	if String(snap.get("phase", "")) != "battle":
		return
	var selected_unit_id := String(snap.get("selected_unit_id", snap.get("selectedUnitId", "")))
	if selected_unit_id == "":
		var selected := Dictionary(snap.get("selected", {}))
		selected_unit_id = String(selected.get("unitId", selected.get("unit_id", "")))
	if selected_unit_id == "":
		return
	var ranges_by_unit := Dictionary(snap.get(
		"action_block_ranges_by_unit",
		snap.get("actionBlockRangesByUnit", {})
	))
	if not ranges_by_unit.has(selected_unit_id):
		return
	var selected_unit := Dictionary(_detail_controller.call("unit_by_id", snap, selected_unit_id))
	var selected_grid := Vector2i(
		int(selected_unit.get("x", -1)),
		int(selected_unit.get("y", -1))
	)
	if not _is_visible_board_cell(selected_grid.x, selected_grid.y):
		return
	var selected_cell := _cell_at(selected_grid.x, selected_grid.y)
	if selected_cell == null or not selected_cell.has_method("get_unit_node"):
		return
	var selected_unit_node := selected_cell.call("get_unit_node") as Control
	if selected_unit_node != null and selected_unit_node.has_method("show_action_block_attack_ranges"):
		selected_unit_node.call(
			"show_action_block_attack_ranges",
			Array(ranges_by_unit[selected_unit_id]),
			_cell_size,
			selected_grid,
			board_grid.size,
			board_grid.global_position,
			_attack_range_geometry()
		)


func _attack_range_geometry() -> Dictionary:
	var geometry := {}
	for cell in _cells:
		if cell == null or not cell.has_method("get_grid_position"):
			continue
		var grid := cell.call("get_grid_position") as Vector2i
		geometry["%d:%d" % [grid.x, grid.y]] = {
			"position": cell.global_position,
			"size": cell.size,
		}
	return geometry


func get_missing_mapping_report() -> Array:
	var values := _missing_mappings.values()
	values.sort_custom(func(a, b):
		return String(Dictionary(a).get("key", "")) < String(Dictionary(b).get("key", ""))
	)
	return values


func has_required_asset_manifest() -> bool:
	return _assets != null and _assets.has_method("manifest_has_required_assets") and bool(_assets.call("manifest_has_required_assets"))


func play_battle_trace(events: Array) -> void:
	if vfx_player != null and vfx_player.has_method("play_trace"):
		if GameLogScript.is_enabled():
			var type_counts := {}
			for event_value in events:
				var event_type := String(Dictionary(event_value).get("type", Dictionary(event_value).get("kind", "未知")))
				type_counts[event_type] = int(type_counts.get(event_type, 0)) + 1
			GameLogScript.info("表现/战斗事件", "开始播放战斗表现队列", {
				"事件数": events.size(),
				"类型统计": type_counts,
				"回合": int(_last_snapshot.get("battleRound", _last_snapshot.get("battle_round", 0)))
			})
		vfx_player.call("play_trace", events)
	else:
		GameLogScript.error("表现/战斗事件", "无法播放表现队列：VFX 播放器不存在或接口缺失", {"事件数": events.size()})


func has_enabled_primary_buttons() -> bool:
	return (
		auto_arrange_button != null
		and begin_turn_button != null
		and not auto_arrange_button.disabled
		and not begin_turn_button.disabled
	)


func debug_initial_round_banner_requested() -> bool:
	return _initial_round_banner_requested


func debug_last_rendered_cell_count() -> int:
	return _last_rendered_cell_count


func debug_board_dimensions() -> Dictionary:
	return {
		"width": _board_columns,
		"height": _board_rows,
		"activeCellCount": _cells.size(),
		"poolCellCount": _cell_pool.size(),
		"cellSize": _cell_size
	}


func run_prefab_reuse_smoke() -> Dictionary:
	var first_cell := _cell_at(0, 0)
	if first_cell.has_method("set_highlight"):
		first_cell.call("set_highlight", "deploy")
	if first_cell.has_method("show_attack_order_marker") and _assets != null and _assets.has_method("attack_order_marker_texture"):
		first_cell.call("show_attack_order_marker", _assets.call("attack_order_marker_texture", 1))
	if vfx_player != null and vfx_player.has_method("debug_spawn_prefab_samples"):
		return Dictionary(vfx_player.call("debug_spawn_prefab_samples"))
	return {}


func debug_drag_first_player_to_empty() -> Dictionary:
	_last_debug_drag_command = {}
	var drag_case := _first_player_drag_case()
	if drag_case.is_empty():
		return {}
	_start_unit_drag(Vector2i(drag_case["origin"]))
	var preferred_target := _first_drag_target_hitting_enemy()
	if preferred_target.x >= 0:
		drag_case["target"] = preferred_target
		drag_case["target_dict"] = {"x": preferred_target.x, "y": preferred_target.y}
	var preview_was_active := _drag_preview != null
	_debug_update_drag_preview_position(Vector2i(drag_case["target"]))
	_finish_unit_drag(Vector2i(drag_case["target"]))
	var result := _last_debug_drag_command.duplicate(true)
	result["preview_was_active"] = preview_was_active
	result["attack_highlight_count"] = int(drag_case.get("attack_highlight_count", 0))
	return result


func debug_start_first_player_drag_to_empty() -> Dictionary:
	_last_debug_drag_command = {}
	var drag_case := _first_player_drag_case()
	if drag_case.is_empty():
		return {}
	var origin := Vector2i(drag_case["origin"])
	_start_unit_drag(origin)
	var target := Vector2i(drag_case["target"])
	var preferred_target := _first_drag_target_hitting_enemy()
	if preferred_target.x >= 0:
		target = preferred_target
	return {
		"started": _drag_unit_id != "",
		"unitId": _drag_unit_id,
		"origin": {"x": origin.x, "y": origin.y},
		"target": {"x": target.x, "y": target.y},
		"preview_was_active": _drag_preview != null
	}


func debug_update_drag_preview_to_target(target: Dictionary) -> Dictionary:
	var grid := Vector2i(int(target.get("x", -1)), int(target.get("y", -1)))
	_debug_update_drag_preview_position(grid)
	return {
		"dragging": _drag_unit_id != "",
		"target": {"x": grid.x, "y": grid.y},
		"preview_was_active": _drag_preview != null and is_instance_valid(_drag_preview),
		"attack_highlight_count": _drag_attack_highlight_keys.size(),
		"attack_cells": _debug_grid_keys(_drag_attack_highlight_keys),
		"expected_attack_cells": _debug_grid_keys(_grid_keys_for_cells(_drag_attack_cells_for_target(grid)))
	}


func debug_finish_active_drag() -> Dictionary:
	var target := _drag_preview_target
	_finish_unit_drag(target)
	return _last_debug_drag_command.duplicate(true)


func debug_open_first_pet_detail() -> Dictionary:
	var fallback: Dictionary = {}
	for cell in _cells:
		var data := _cell_data_for_cell(cell)
		var unit_id := String(data.get("unitId", data.get("unit_id", "")))
		if unit_id == "":
			continue
		var grid := cell.call("get_grid_position") as Vector2i
		var row := {
			"opened": true,
			"unitId": unit_id,
			"name": String(data.get("unitName", data.get("name", ""))),
			"grid": {"x": grid.x, "y": grid.y}
		}
		if fallback.is_empty():
			fallback = row
		var side := String(data.get("side", data.get("unitSide", "")))
		if side != "player" and side != "hero" and side != "hero_leader":
			continue
		_select_player_unit_and_request_detail(grid)
		return row
	if not fallback.is_empty():
		var fallback_grid := Dictionary(fallback.get("grid", {}))
		_request_cell_detail(Vector2i(int(fallback_grid.get("x", -1)), int(fallback_grid.get("y", -1))))
		return fallback
	return {"opened": false}


func debug_open_first_element_detail() -> Dictionary:
	for cell in _cells:
		var data := _cell_data_for_cell(cell)
		if String(data.get("unitId", data.get("unit_id", ""))) != "":
			continue
		if not bool(_detail_controller.call("has_visible_elements", _dict(data.get("elements", {})))):
			continue
		var grid := cell.call("get_grid_position") as Vector2i
		_on_cell_selected(grid.x, grid.y)
		return {
			"opened": true,
			"grid": {"x": grid.x, "y": grid.y},
			"elements": _dict(data.get("elements", {})).duplicate(true)
		}
	return {"opened": false}


func debug_detail_panel_summary() -> Dictionary:
	_ensure_detail_panel()
	var labels: Array[String] = []
	if _detail_panel != null and _detail_panel.visible and _detail_panel.has_method("get_display_text"):
		labels.append_array(String(_detail_panel.call("get_display_text")).split("\n", false))
	elif _element_detail_panel != null and _element_detail_panel.has_method("get_display_text"):
		labels.append_array(String(_element_detail_panel.call("get_display_text")).split("\n", false))
	return {
		"visible": (_detail_panel != null and _detail_panel.visible) or (_element_detail_panel != null and _element_detail_panel.visible),
		"unitId": _active_detail_unit_id,
		"lineCount": labels.size(),
		"text": "\n".join(labels),
		"usesSharedPrefab": _detail_panel != null and _detail_panel.scene_file_path == "res://art/prefabs/pet/pet_detail.tscn",
	}


func debug_selected_action_range_summary() -> Dictionary:
	var selected_unit_id := _selected_unit_id()
	if selected_unit_id == "":
		return {"unitId": "", "visibleCellCount": 0}
	var grid := _grid_for_unit_id(selected_unit_id)
	if not _is_visible_board_cell(grid.x, grid.y):
		return {"unitId": selected_unit_id, "visibleCellCount": 0}
	var cell := _cell_at(grid.x, grid.y)
	if cell == null or not cell.has_method("get_unit_node"):
		return {"unitId": selected_unit_id, "visibleCellCount": 0}
	var unit := cell.call("get_unit_node") as Control
	if unit == null or not unit.has_method("get_action_block_attack_range_snapshot"):
		return {"unitId": selected_unit_id, "visibleCellCount": 0}
	var summary := Dictionary(unit.call("get_action_block_attack_range_snapshot"))
	summary["unitId"] = selected_unit_id
	return summary


func debug_cancel_active_drag() -> void:
	_finish_unit_drag(Vector2i(-1, -1))


func debug_drop_settle_summary() -> Dictionary:
	return _last_drop_settle_summary.duplicate(true)


func _first_player_drag_case() -> Dictionary:
	for cell in _cells:
		if not cell.has_method("has_player_unit") or not bool(cell.call("has_player_unit")):
			continue
		var origin := cell.call("get_grid_position") as Vector2i
		var unit := cell.call("get_unit_node") as Control
		if unit == null or not unit.has_method("get_unit_id"):
			continue
		var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
		for direction in directions:
			var target: Vector2i = origin + Vector2i(direction)
			if not _is_visible_board_cell(target.x, target.y):
				continue
			var target_cell := _cell_at(target.x, target.y)
			if target_cell.has_method("get_unit_node") and target_cell.call("get_unit_node") != null:
				continue
			return {
				"origin": origin,
				"target": target,
				"target_dict": {"x": target.x, "y": target.y}
			}
	return {}


func _first_drag_target_hitting_enemy() -> Vector2i:
	if _drag_unit_id == "":
		return Vector2i(-1, -1)
	for y in range(_board_rows):
		for x in range(_board_columns):
			var target := Vector2i(x, y)
			if not _can_drag_preview_at(target):
				continue
			for attack_grid in _drag_attack_cells_for_target(target):
				if _cell_is_enemy_occupied(attack_grid):
					return target
	return Vector2i(-1, -1)


func debug_emit_command(command_type: String) -> Dictionary:
	var command := _battle_command(command_type)
	if command.is_empty():
		return {}
	command_requested.emit(command)
	return command.duplicate(true)


func _build_board() -> void:
	for child_value in board_grid.get_children():
		var authored_cell := child_value as Control
		if authored_cell != null and authored_cell.has_method("setup_grid_position") and not _cell_pool.has(authored_cell):
			_cell_pool.append(authored_cell)
	var required_cell_count := _board_columns * _board_rows
	while _cell_pool.size() < required_cell_count:
		var created_cell := BattleCellScene.instantiate() as Control
		if created_cell == null:
			break
		board_grid.add_child(created_cell)
		_cell_pool.append(created_cell)
	for index in range(_cell_pool.size()):
		_cell_pool[index].name = "BattleCellPool_%d" % index
	_cells.clear()
	var board_size := board_grid.size
	_cell_size = Vector2(
		(board_size.x - CELL_GAP.x * float(_board_columns - 1)) / float(_board_columns),
		(board_size.y - CELL_GAP.y * float(_board_rows - 1)) / float(_board_rows)
	)
	for index in range(_cell_pool.size()):
		var cell := _cell_pool[index]
		var active := index < required_cell_count
		cell.visible = active
		cell.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
		if not active:
			if cell.has_method("set_cell_data"):
				cell.call("set_cell_data", {}, _assets)
			continue
		var x := index % _board_columns
		var y := int(index / _board_columns)
		if cell.has_method("setup_grid_position"):
			cell.call("setup_grid_position", x, y, _cell_size, _cell_origin(x, y))
		if cell.has_signal("cell_selected") and not cell.is_connected("cell_selected", _on_cell_selected):
			cell.connect("cell_selected", _on_cell_selected)
		if cell.has_signal("cell_pressed") and not cell.is_connected("cell_pressed", _on_cell_pressed):
			cell.connect("cell_pressed", _on_cell_pressed)
		if cell.has_signal("cell_released") and not cell.is_connected("cell_released", _on_cell_released):
			cell.connect("cell_released", _on_cell_released)
		if cell.has_signal("cell_hovered") and not cell.is_connected("cell_hovered", _on_cell_hovered):
			cell.connect("cell_hovered", _on_cell_hovered)
		if cell.has_signal("cell_unhovered") and not cell.is_connected("cell_unhovered", _on_cell_unhovered):
			cell.connect("cell_unhovered", _on_cell_unhovered)
		_cells.append(cell)


func _ensure_board() -> void:
	if _cells.size() == _board_columns * _board_rows:
		return
	_build_board()


func _set_board_dimensions(dimensions: Vector2i) -> void:
	var normalized := BattleBoardDimensionsScript.normalized(dimensions.x, dimensions.y, Vector2i(_board_columns, _board_rows))
	if normalized.x == _board_columns and normalized.y == _board_rows and _cells.size() == normalized.x * normalized.y:
		return
	_cancel_drag_for_board_resize()
	_board_columns = normalized.x
	_board_rows = normalized.y
	_build_board()


func _cancel_drag_for_board_resize() -> void:
	if _drag_unit_id != "":
		_finish_unit_drag(Vector2i(-1, -1))
	_hovered_grid = Vector2i(-1, -1)
	_drag_hover_grid = Vector2i(-1, -1)
	_active_detail_grid = Vector2i(-1, -1)


func _collect_cell_missing_mappings(cell_node: Control) -> void:
	if not cell_node.has_method("get_missing_mapping_report"):
		return
	var missing_items := Array(cell_node.call("get_missing_mapping_report"))
	for value in missing_items:
		var missing := Dictionary(value)
		if missing.is_empty():
			continue
		_missing_mappings[String(missing.get("key", ""))] = missing


func _render_cell_trace_effects(cell_node: Control, cell_data: Dictionary) -> void:
	if _assets == null or not _assets.has_method("buff_ring_texture") or not cell_node.has_method("show_effect_marker"):
		return
	var traces := Array(cell_data.get("traces", []))
	if traces.is_empty() and cell_data.has("trace"):
		traces = [Dictionary(cell_data.get("trace", {}))]
	for trace_value in traces:
		var trace := Dictionary(trace_value)
		var element := _trace_element(String(trace.get("kind", "")))
		if element == "":
			continue
		cell_node.call("show_effect_marker", _assets.call("buff_ring_texture", element))
		return


func _play_new_trace_events(snap: Dictionary) -> void:
	var events := Array(snap.get("battleTrace", snap.get("battle_trace", [])))
	if _rendered_trace_count < 0 or events.size() < _rendered_trace_count:
		_rendered_trace_count = events.size()
		return
	if events.size() == _rendered_trace_count:
		return
	var new_events := []
	for index in range(_rendered_trace_count, events.size()):
		new_events.append(Dictionary(events[index]))
	_rendered_trace_count = events.size()
	_set_battle_input_locked(true)
	play_battle_trace(new_events)


func _on_enemy_move_projection_requested(event: Dictionary) -> void:
	var actor := Dictionary(event.get("actor", {}))
	var unit_id := String(event.get("unitId", actor.get("id", "")))
	var final_cell := Dictionary(_pending_enemy_move_final_cells.get(unit_id, {}))
	if unit_id == "" or final_cell.is_empty():
		return
	var from := Dictionary(event.get("from", Dictionary(event.get("payload", {})).get("from", {})))
	var from_node := _cell_at(int(from.get("x", from.get("c", -1))), int(from.get("y", from.get("r", -1))))
	if from_node != null and from_node.has_method("set_cell_data"):
		var from_data := _cell_data_for_cell(from_node).duplicate(true)
		if String(from_data.get("unitId", from_data.get("unit_id", ""))) == unit_id:
			_trace_projection.call("clear_cell_unit_projection", from_data)
			from_node.call("set_cell_data", from_data, _assets)
	var to_node := _cell_at(int(final_cell.get("x", final_cell.get("c", -1))), int(final_cell.get("y", final_cell.get("r", -1))))
	if to_node != null and to_node.has_method("set_cell_data"):
		to_node.call("set_cell_data", final_cell, _assets)
		_render_cell_trace_effects(to_node, final_cell)
	_pending_enemy_move_final_cells.erase(unit_id)


func _on_trace_sequence_started() -> void:
	GameLogScript.debug("表现/战斗事件", "表现序列开始，锁定战斗输入")
	_set_battle_input_locked(true)


func _on_trace_sequence_finished() -> void:
	var had_final_snapshot := not _pending_final_snapshot.is_empty()
	var pending_enemy_moves := _pending_enemy_move_final_cells.size()
	if not _pending_final_snapshot.is_empty():
		var final_snapshot := _pending_final_snapshot.duplicate(true)
		_pending_final_snapshot = {}
		_clear_all_cell_highlights()
		var final_cells := Array(Dictionary(final_snapshot.get("board", {})).get("cells", [])).duplicate(true)
		_render_board_cells(final_cells)
		_apply_artist_preview_highlights(final_snapshot)
		_render_pet_detail(final_snapshot)
	else:
		for final_cell_value in _pending_enemy_move_final_cells.values():
			var final_cell := Dictionary(final_cell_value)
			var cell_node := _cell_at(int(final_cell.get("x", final_cell.get("c", -1))), int(final_cell.get("y", final_cell.get("r", -1))))
			if cell_node != null and cell_node.has_method("set_cell_data"):
				cell_node.call("set_cell_data", final_cell, _assets)
	_pending_enemy_move_final_cells.clear()
	_apply_selected_action_block_ranges(_last_snapshot)
	if not _pending_action_panel_snapshot.is_empty():
		_render_action_panel(_pending_action_panel_snapshot)
		_render_direction_drawer(_pending_action_panel_snapshot)
		_pending_action_panel_snapshot = {}
	_set_battle_input_locked(false)
	GameLogScript.info("表现/战斗事件", "表现序列播放完成，最终快照已落位", {
		"应用最终快照": had_final_snapshot,
		"待落位敌方移动": pending_enemy_moves,
		"输入已解锁": true
	})
	trace_sequence_finished.emit()


func _set_battle_input_locked(locked: bool) -> void:
	if _battle_input_locked != locked:
		GameLogScript.debug("表现/输入锁", "战斗输入状态变化", {"状态": "锁定" if locked else "解锁"})
	_battle_input_locked = locked
	if auto_arrange_button != null:
		auto_arrange_button.disabled = locked
	if position_difficulty_button != null:
		position_difficulty_button.disabled = locked
	if begin_turn_button != null:
		begin_turn_button.disabled = locked


func is_battle_input_locked() -> bool:
	return _battle_input_locked


func _on_pets_reset_reveal_requested(units: Array) -> void:
	var board := Dictionary(_last_snapshot.get("board", {}))
	var cells := Array(board.get("cells", []))
	for unit_value in units:
		var unit_id := String(Dictionary(unit_value).get("id", ""))
		if unit_id == "":
			continue
		for cell_value in cells:
			var cell := Dictionary(cell_value)
			if String(cell.get("unitId", cell.get("unit_id", ""))) != unit_id:
				continue
			var cell_node := _cell_at(int(cell.get("x", cell.get("c", -1))), int(cell.get("y", cell.get("r", -1))))
			if cell_node == null or not cell_node.has_method("set_cell_data"):
				break
			cell_node.call("set_cell_data", cell, _assets)
			_render_cell_trace_effects(cell_node, cell)
			var summoned_unit := cell_node.call("get_unit_node") as Control if cell_node.has_method("get_unit_node") else null
			if summoned_unit != null:
				summoned_unit.modulate.a = 0.0
				summoned_unit.scale = Vector2(0.72, 0.72)
				summoned_unit.pivot_offset = summoned_unit.size * 0.5
				var tween := summoned_unit.create_tween().set_parallel(true)
				tween.tween_property(summoned_unit, "modulate:a", 1.0, 0.32)
				tween.tween_property(summoned_unit, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			break


func _play_initial_round_banner_if_needed(snap: Dictionary) -> void:
	if _initial_round_banner_requested:
		return
	if vfx_player == null or not vfx_player.has_method("play_round_banner"):
		return
	var round_number := int(snap.get("round", snap.get("battleRound", snap.get("battle_round", 1))))
	if round_number <= 0:
		round_number = 1
	_initial_round_banner_requested = true
	vfx_player.call_deferred("play_round_banner", round_number, "player")


func _trace_element(kind: String) -> String:
	if kind.begins_with("fire"):
		return "fire"
	if kind.begins_with("water"):
		return "water"
	if kind.begins_with("earth"):
		return "earth"
	if kind.begins_with("wind"):
		return "wind"
	return ""


func _cell_at(x: int, y: int) -> Control:
	if not _is_visible_board_cell(x, y):
		return null
	var index := y * _board_columns + x
	return _cells[index] if index < _cells.size() else null


func _cell_key(grid: Vector2i) -> String:
	return String(_board_controller.call("cell_key", grid))


func _cell_origin(x: int, y: int) -> Vector2:
	var cell := _cell_at(x, y)
	if cell != null and cell.has_method("uses_perspective_geometry") and bool(cell.call("uses_perspective_geometry")):
		return cell.position
	return _board_controller.call("cell_origin", _cell_size, CELL_GAP, x, y) as Vector2


func _grid_from_board_position(local_position: Vector2) -> Vector2i:
	var has_perspective_geometry := false
	for cell in _cells:
		if not cell.has_method("uses_perspective_geometry") or not bool(cell.call("uses_perspective_geometry")):
			continue
		has_perspective_geometry = true
		if cell.has_method("contains_board_point") and bool(cell.call("contains_board_point", local_position)):
			return cell.call("get_grid_position") as Vector2i
	if has_perspective_geometry:
		return Vector2i(-1, -1)
	return _board_controller.call("grid_from_position", local_position, Vector2i(_board_columns, _board_rows), _cell_size, CELL_GAP) as Vector2i


func _on_cell_selected(x: int, y: int) -> void:
	if _battle_input_locked:
		return
	if _suppress_next_select:
		_suppress_next_select = false
		return
	var grid := Vector2i(x, y)
	if _cell_has_player_unit(grid):
		_select_player_unit_and_request_detail(grid)
		return
	if _cell_has_unit(grid) or _cell_has_visible_elements(grid):
		_request_cell_detail(grid)
		return
	command_requested.emit({"type": "SELECT_CELL", "x": x, "y": y, "cell": {"x": x, "y": y}})


func _on_cell_pressed(x: int, y: int) -> void:
	if _battle_input_locked:
		return
	_start_unit_drag(Vector2i(x, y))


func _on_cell_released(x: int, y: int) -> void:
	if _battle_input_locked:
		return
	if _drag_unit_id == "":
		return
	_finish_unit_drag(Vector2i(x, y))


func _on_cell_hovered(x: int, y: int) -> void:
	var grid := Vector2i(x, y)
	if _hovered_grid == grid:
		return
	if _hovered_grid.x >= 0 and _hovered_grid.y >= 0 and _drag_unit_id == "":
		_clear_cell_highlight(_hovered_grid)
	_hovered_grid = grid
	var mode := "deploy" if _drag_unit_id != "" else "selected"
	_set_cell_highlight(grid, mode)


func _on_cell_unhovered(x: int, y: int) -> void:
	var grid := Vector2i(x, y)
	if _drag_unit_id == "" and _hovered_grid == grid:
		_clear_cell_highlight(grid)
		_hovered_grid = Vector2i(-1, -1)


func _start_unit_drag(grid: Vector2i) -> void:
	if _drop_settle_active:
		return
	var cell := _cell_at(grid.x, grid.y)
	if cell == null or not cell.has_method("has_player_unit") or not bool(cell.call("has_player_unit")):
		return
	var unit := cell.call("get_unit_node") as Control
	if unit == null or not unit.has_method("get_unit_id"):
		return
	_clear_active_detail()
	_drag_unit_id = String(unit.call("get_unit_id"))
	set_process(true)
	_drag_origin = grid
	_drag_offset = board_grid.get_local_mouse_position() - _cell_origin(grid.x, grid.y)
	_drag_start_mouse_position = board_grid.get_local_mouse_position()
	_drag_has_moved = false
	if cell.has_method("set_unit_dragging"):
		cell.call("set_unit_dragging", true)
	_select_player_unit(grid)
	_create_drag_preview(unit)
	_update_drag_preview()


func _finish_unit_drag(target: Vector2i) -> void:
	if _drag_unit_id == "":
		return
	var dragged_unit_id := _drag_unit_id
	var origin := _drag_origin
	var was_dragged := _drag_has_moved
	var settle_preview := _take_drag_preview()
	_clear_cell_highlight(origin)
	_clear_drag_attack_preview()
	_clear_drag_hover_highlight()
	_reset_drag_tracking()
	if target == origin and not was_dragged:
		_free_drop_preview(settle_preview)
		_set_cell_unit_dragging(origin, false)
		_suppress_next_select = true
		_select_player_unit_and_request_detail(origin)
		return
	if target == origin:
		_suppress_next_select = true
		_start_drop_settle(settle_preview, dragged_unit_id, origin, target, origin)
		return
	var command := {}
	if _is_visible_board_cell(target.x, target.y):
		command = {
			"type": "MOVE_HERO",
			"unitId": dragged_unit_id,
			"x": target.x,
			"y": target.y,
			"cell": {"x": target.x, "y": target.y}
		}
		_last_debug_drag_command = command.duplicate(true)
	_suppress_next_select = true
	if not command.is_empty():
		command_requested.emit(command)
	var settled_grid := _grid_for_unit_id(dragged_unit_id)
	if settled_grid.x < 0 or settled_grid.y < 0:
		settled_grid = origin
	_start_drop_settle(settle_preview, dragged_unit_id, origin, target, settled_grid)


func _take_drag_preview() -> Control:
	var preview := _drag_preview
	_drag_preview = null
	return preview


func _reset_drag_tracking() -> void:
	_drag_unit_id = ""
	set_process(false)
	_drag_origin = Vector2i(-1, -1)
	_drag_preview_target = Vector2i(-1, -1)
	_debug_drag_preview_target = Vector2i(-1, -1)
	_drag_start_mouse_position = Vector2.ZERO
	_drag_has_moved = false


func _grid_for_unit_id(unit_id: String) -> Vector2i:
	var unit := Dictionary(_detail_controller.call("unit_by_id", _last_snapshot, unit_id))
	if unit.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(unit.get("x", -1)), int(unit.get("y", -1)))


func _start_drop_settle(preview: Control, unit_id: String, origin: Vector2i, requested: Vector2i, settled: Vector2i) -> void:
	var is_return := settled == origin and requested != origin
	var duration := DROP_RETURN_DURATION if is_return else DROP_SETTLE_DURATION
	_last_drop_settle_summary = {
		"active": preview != null and is_instance_valid(preview),
		"completed": false,
		"unitId": unit_id,
		"origin": {"x": origin.x, "y": origin.y},
		"requested": {"x": requested.x, "y": requested.y},
		"settled": {"x": settled.x, "y": settled.y},
		"returned": is_return,
		"duration": duration
	}
	if preview == null or not is_instance_valid(preview):
		_set_cell_unit_dragging(settled, false)
		_last_drop_settle_summary["active"] = false
		_last_drop_settle_summary["completed"] = true
		return
	_drop_settle_active = true
	_drop_settle_preview = preview
	_drop_settle_unit_id = unit_id
	_drop_settle_grid = settled
	_set_cell_unit_dragging(settled, true)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_as_relative = false
	preview.z_index = 180
	preview.modulate.a = 0.94
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUINT)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "position", _cell_origin(settled.x, settled.y), duration)
	tween.parallel().tween_property(preview, "modulate:a", 1.0, duration)
	tween.finished.connect(_finish_drop_settle.bind(preview, unit_id, settled))


func _finish_drop_settle(preview: Control, unit_id: String, settled: Vector2i) -> void:
	if preview != null and is_instance_valid(preview):
		preview.visible = false
		preview.queue_free()
	_set_cell_unit_dragging(settled, false)
	if _drop_settle_preview == preview:
		_drop_settle_preview = null
	_drop_settle_active = false
	_drop_settle_unit_id = ""
	_drop_settle_grid = Vector2i(-1, -1)
	_last_drop_settle_summary["active"] = false
	_last_drop_settle_summary["completed"] = true
	_last_drop_settle_summary["unitId"] = unit_id


func _restore_drop_settle_visual_state() -> void:
	if not _drop_settle_active or _drop_settle_unit_id == "":
		return
	var current_grid := _grid_for_unit_id(_drop_settle_unit_id)
	if current_grid.x >= 0 and current_grid.y >= 0:
		_drop_settle_grid = current_grid
	_set_cell_unit_dragging(_drop_settle_grid, true)


func _set_cell_unit_dragging(grid: Vector2i, is_dragging: bool) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	var cell := _cell_at(grid.x, grid.y)
	if cell != null and cell.has_method("set_unit_dragging"):
		cell.call("set_unit_dragging", is_dragging)


func _free_drop_preview(preview: Control) -> void:
	if preview != null and is_instance_valid(preview):
		preview.queue_free()


func _clear_active_detail() -> void:
	_active_detail_grid = Vector2i(-1, -1)
	_active_detail_unit_id = ""
	if _detail_panel != null:
		if _detail_panel.has_method("close"):
			_detail_panel.call("close")
		else:
			_detail_panel.visible = false
	if _element_detail_panel != null:
		_element_detail_panel.visible = false


func _clear_drag_hover_highlight() -> void:
	if _hovered_grid.x >= 0 and _hovered_grid.y >= 0:
		_clear_cell_highlight(_hovered_grid)
	_hovered_grid = Vector2i(-1, -1)
	if _drag_preview_target.x >= 0 and _drag_preview_target.y >= 0:
		_clear_cell_highlight(_drag_preview_target)
	if _drag_hover_grid.x >= 0 and _drag_hover_grid.y >= 0:
		_clear_cell_highlight(_drag_hover_grid)
	_drag_hover_grid = Vector2i(-1, -1)


func _request_cell_detail(grid: Vector2i) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	var data := _cell_data_at_grid(grid)
	var x := int(data.get("x", data.get("c", grid.x)))
	var y := int(data.get("y", data.get("r", grid.y)))
	_active_detail_grid = Vector2i(x, y)
	_active_detail_unit_id = String(data.get("unitId", data.get("unit_id", "")))
	command_requested.emit({"type": "GET_CELL_DETAIL", "x": x, "y": y, "cell": {"x": x, "y": y}})


func _cell_has_player_unit(grid: Vector2i) -> bool:
	var cell := _cell_at(grid.x, grid.y)
	return cell != null and cell.has_method("has_player_unit") and bool(cell.call("has_player_unit"))


func _select_player_unit_and_request_detail(grid: Vector2i) -> void:
	if not _cell_has_player_unit(grid):
		_request_cell_detail(grid)
		return
	_select_player_unit(grid)
	_request_cell_detail(grid)


func _select_player_unit(grid: Vector2i) -> void:
	if not _cell_has_player_unit(grid):
		return
	command_requested.emit({
		"type": "SELECT_CELL",
		"x": grid.x,
		"y": grid.y,
		"cell": {"x": grid.x, "y": grid.y}
	})


func _create_drag_preview(unit: Control) -> void:
	_clear_drag_preview()
	var raw_data = unit.get("cell_data")
	if not (raw_data is Dictionary):
		return
	var preview := BattleUnitScene.instantiate() as Control
	if preview == null:
		return
	preview.name = "BattleUnitDragPreview"
	preview.position = board_grid.get_local_mouse_position() - _drag_offset
	preview.size = _cell_size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_grid.add_child(preview)
	if preview.has_method("set_unit_data"):
		preview.call("set_unit_data", Dictionary(raw_data).duplicate(true), String(unit.get("side")), _assets)
	if preview.has_method("set_dragging"):
		preview.call("set_dragging", false)
	preview.z_as_relative = false
	preview.z_index = 180
	preview.modulate.a = 0.94
	board_grid.move_child(preview, board_grid.get_child_count() - 1)
	_drag_preview = preview


func _update_drag_preview() -> void:
	if _drag_unit_id == "" or _drag_preview == null or not is_instance_valid(_drag_preview):
		return
	if _debug_drag_preview_target.x >= 0:
		_drag_preview.position = _cell_origin(_debug_drag_preview_target.x, _debug_drag_preview_target.y)
		_refresh_drag_attack_preview(_debug_drag_preview_target)
		_refresh_drag_hover_highlight(_debug_drag_preview_target)
		return
	var local_mouse := board_grid.get_local_mouse_position()
	_drag_preview.position = local_mouse - _drag_offset
	if local_mouse.distance_to(_drag_start_mouse_position) >= DRAG_CLICK_THRESHOLD:
		_drag_has_moved = true
	var target := _grid_from_board_position(local_mouse)
	if target != _drag_origin:
		_drag_has_moved = true
	_refresh_drag_attack_preview(target)
	_refresh_drag_hover_highlight(target)


func _clear_drag_preview() -> void:
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null


func _debug_update_drag_preview_position(target: Vector2i) -> void:
	if _drag_unit_id == "" or _drag_preview == null or not is_instance_valid(_drag_preview):
		return
	_debug_drag_preview_target = target
	if target != _drag_origin:
		_drag_has_moved = true
	_drag_preview.position = _cell_origin(target.x, target.y)
	_refresh_drag_attack_preview(target)
	_refresh_drag_hover_highlight(target)


func _restore_drag_visual_state() -> void:
	if _drag_unit_id == "":
		return
	var origin_cell := _cell_at(_drag_origin.x, _drag_origin.y)
	if origin_cell != null and origin_cell.has_method("set_unit_dragging"):
		origin_cell.call("set_unit_dragging", true)
	if _drag_preview_target.x >= 0:
		_refresh_drag_attack_preview(_drag_preview_target, true)
		_refresh_drag_hover_highlight(_drag_preview_target, true)


func _refresh_drag_attack_preview(target: Vector2i, force: bool = false) -> void:
	if _drag_unit_id == "":
		return
	if not force and target == _drag_preview_target:
		return
	_clear_drag_attack_preview()
	_drag_preview_target = target
	if not _is_visible_board_cell(target.x, target.y):
		return
	_show_drag_attack_cells(_drag_attack_cells_for_target(target))


func _clear_drag_attack_preview() -> void:
	for key in _drag_attack_highlight_keys:
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		_clear_cell_highlight(Vector2i(int(parts[0]), int(parts[1])))
	_drag_attack_highlight_keys.clear()
	for key in _drag_attack_marker_keys:
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		_clear_cell_attack_order_marker(Vector2i(int(parts[0]), int(parts[1])))
	_drag_attack_marker_keys.clear()


func _refresh_drag_hover_highlight(target: Vector2i, force: bool = false) -> void:
	if _drag_unit_id == "":
		return
	if not force and target == _drag_hover_grid:
		return
	if _drag_hover_grid.x >= 0 and _drag_hover_grid.y >= 0:
		_clear_cell_highlight(_drag_hover_grid)
	_drag_hover_grid = Vector2i(-1, -1)
	if not _is_visible_board_cell(target.x, target.y):
		return
	_drag_hover_grid = target
	_set_cell_highlight(target, "selected")


func _show_drag_attack_cells(cells: Array[Vector2i]) -> void:
	var visible_attack_cells: Array[Vector2i] = []
	for index in range(cells.size()):
		var grid := cells[index]
		if not _cell_is_enemy_occupied(grid):
			continue
		_set_cell_highlight(grid, "attack")
		_drag_attack_highlight_keys.append(_cell_key(grid))
		visible_attack_cells.append(grid)
	if not visible_attack_cells.is_empty():
		var marker_grid := visible_attack_cells[visible_attack_cells.size() - 1]
		var preview := _drag_action_preview()
		_set_cell_attack_order_marker(marker_grid, int(preview.get("slotIndex", _selected_slot_index())) + 1)
		_drag_attack_marker_keys.append(_cell_key(marker_grid))


func _can_drag_preview_at(target: Vector2i) -> bool:
	if not _is_visible_board_cell(target.x, target.y):
		return false
	var data := _cell_data_at_grid(target)
	var unit_id := String(data.get("unitId", data.get("unit_id", "")))
	return unit_id == "" or target == _drag_origin or unit_id == _drag_unit_id


func _drag_attack_cells_for_target(target: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _can_drag_preview_at(target):
		return out
	var preview := _drag_action_preview()
	var source_cells := Array(preview.get("cells", []))
	if source_cells.is_empty():
		return out
	var source_origin := Dictionary(preview.get("origin", {}))
	var origin := Vector2i(
		int(source_origin.get("x", _drag_origin.x)),
		int(source_origin.get("y", _drag_origin.y))
	)
	var delta := target - origin
	var by_key := {}
	for cell_value in source_cells:
		var row := Dictionary(cell_value)
		var x := int(row.get("x", row.get("c", -1))) + delta.x
		var y := int(row.get("y", row.get("r", -1))) + delta.y
		if not _is_visible_board_cell(x, y):
			continue
		var grid := Vector2i(x, y)
		by_key[_cell_key(grid)] = grid
	for grid_value in by_key.values():
		out.append(grid_value as Vector2i)
	return out


func _drag_action_preview() -> Dictionary:
	var previews := Dictionary(_last_snapshot.get("action_preview_by_unit", {}))
	if previews.has(_drag_unit_id):
		return Dictionary(previews[_drag_unit_id])
	var source_cells := _current_drag_source_attack_cells()
	if source_cells.is_empty():
		return {}
	return {
		"unitId": _drag_unit_id,
		"origin": {"x": _drag_origin.x, "y": _drag_origin.y},
		"slotIndex": _selected_slot_index(),
		"cells": source_cells
	}


func _is_visible_board_cell(x: int, y: int) -> bool:
	return bool(_board_controller.call("contains", Vector2i(_board_columns, _board_rows), x, y))


func _grid_keys_for_cells(cells: Array[Vector2i]) -> Array[String]:
	var keys: Array[String] = []
	for grid in cells:
		keys.append(_cell_key(grid))
	keys.sort()
	return keys


func _debug_grid_keys(keys: Array[String]) -> Array[String]:
	var out: Array[String] = keys.duplicate()
	out.sort()
	return out


func _current_drag_source_attack_cells() -> Array:
	var selected_id := String(_last_snapshot.get("selected_unit_id", _last_snapshot.get("selectedUnitId", "")))
	if selected_id != _drag_unit_id:
		return []
	var cells := Array(_last_snapshot.get("selected_action_cells", _last_snapshot.get("selectedActionCells", [])))
	if not cells.is_empty():
		return cells
	var fallback: Array = []
	var board := Dictionary(_last_snapshot.get("board", {}))
	for cell_value in Array(board.get("cells", [])):
		var cell := Dictionary(cell_value)
		if not bool(cell.get("action_preview", cell.get("actionPreview", false))):
			continue
		var preview := Dictionary(cell.get("action_preview_data", cell.get("actionPreviewData", {})))
		if String(preview.get("unit_id", preview.get("unitId", ""))) != _drag_unit_id:
			continue
		fallback.append({"x": int(cell.get("x", cell.get("c", -1))), "y": int(cell.get("y", cell.get("r", -1)))})
	return fallback


func _set_cell_attack_order_marker(grid: Vector2i, dot_count: int) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	var cell := _cell_at(grid.x, grid.y)
	if cell == null or not cell.has_method("show_attack_order_marker"):
		return
	if _assets == null or not _assets.has_method("attack_order_marker_texture"):
		return
	cell.call("show_attack_order_marker", _assets.call("attack_order_marker_texture", dot_count))


func _clear_cell_attack_order_marker(grid: Vector2i) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	var cell := _cell_at(grid.x, grid.y)
	if cell != null and cell.has_method("clear_attack_order_marker"):
		cell.call("clear_attack_order_marker")


func _set_cell_highlight(grid: Vector2i, mode: String) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	var cell := _cell_at(grid.x, grid.y)
	if cell != null and cell.has_method("set_highlight"):
		cell.call("set_highlight", mode)


func _clear_cell_highlight(grid: Vector2i) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	var cell := _cell_at(grid.x, grid.y)
	if cell == null:
		return
	var key := _cell_key(grid)
	if _preview_highlights.has(key) and cell.has_method("set_highlight"):
		cell.call("set_highlight", String(_preview_highlights[key]))
	elif cell.has_method("clear_highlight"):
		cell.call("clear_highlight")


func _clear_all_cell_highlights() -> void:
	_preview_highlights = {}
	for cell in _cells:
		if cell != null and cell.has_method("clear_highlight"):
			cell.call("clear_highlight")


func _apply_artist_preview_highlights(snap: Dictionary) -> void:
	for y in range(_board_rows):
		for x in range(_board_columns):
			var grid := Vector2i(x, y)
			var cell := _cell_at(x, y)
			if cell != null and cell.has_method("get_unit_node") and cell.call("get_unit_node") == null:
				_set_preview_highlight(grid, "deploy")
	var action_cells := Array(snap.get("selected_action_cells", snap.get("selectedActionCells", [])))
	for value in action_cells:
		var row := Dictionary(value)
		if not _preview_row_is_enemy(row):
			continue
		_set_preview_highlight(Vector2i(int(row.get("x", row.get("c", -1))), int(row.get("y", row.get("r", -1)))), "attack")
	var board := Dictionary(snap.get("board", {}))
	for cell_value in Array(board.get("cells", [])):
		var cell_data := Dictionary(cell_value)
		if not bool(cell_data.get("action_preview", cell_data.get("actionPreview", false))):
			continue
		var preview := Dictionary(cell_data.get("action_preview_data", cell_data.get("actionPreviewData", cell_data.get("preview", {}))))
		if not _preview_row_is_enemy(preview):
			continue
		_set_preview_highlight(Vector2i(int(cell_data.get("x", cell_data.get("c", -1))), int(cell_data.get("y", cell_data.get("r", -1)))), "attack")


func _preview_row_is_enemy(row: Dictionary) -> bool:
	return String(row.get("preview_type", row.get("previewType", ""))) == "enemy" or bool(row.get("hitEnemy", row.get("hit_enemy", false)))


func _cell_is_enemy_occupied(grid: Vector2i) -> bool:
	var data := _cell_data_at_grid(grid)
	if String(data.get("unitId", data.get("unit_id", ""))) == "":
		return false
	return String(data.get("side", data.get("unitSide", ""))) == "enemy"


func _set_preview_highlight(grid: Vector2i, mode: String) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	_preview_highlights[_cell_key(grid)] = mode
	_set_cell_highlight(grid, mode)


func _on_auto_arrange_pressed() -> void:
	if _battle_input_locked or _auto_position_feedback_pending:
		GameLogScript.warning("表现/自动布置", "点击未发送：当前已有操作处理中", {
			"输入锁定": _battle_input_locked,
			"正在计算": _auto_position_feedback_pending
		})
		return
	GameLogScript.info("表现/自动布置", "玩家点击自动布置，界面进入计算状态", {
		"难度": String(_last_snapshot.get("difficulty", "normal")),
		"回合": int(_last_snapshot.get("battleRound", _last_snapshot.get("battle_round", 0)))
	})
	_auto_position_feedback_pending = true
	_position_feedback_serial += 1
	position_difficulty_button.text = "摆位计算中…"
	auto_arrange_button.disabled = true
	auto_arrange_button.modulate = Color("#fff0ad")
	var pulse := create_tween()
	pulse.tween_property(auto_arrange_button, "modulate", Color.WHITE, 0.35)
	_request_auto_position.call_deferred()


func _request_auto_position() -> void:
	if not _auto_position_feedback_pending:
		return
	if _battle_input_locked:
		_auto_position_feedback_pending = false
		auto_arrange_button.disabled = false
		_apply_position_difficulty_label(String(_last_snapshot.get("difficulty", "normal")))
		GameLogScript.warning("表现/自动布置", "延迟发送前发现输入已锁定，取消本次请求")
		return
	GameLogScript.debug("表现/自动布置", "向核心发送自动布置命令")
	command_requested.emit({"type": "AUTO_POSITION_HEROES"})


func _consume_auto_position_feedback(snap: Dictionary) -> void:
	if not _auto_position_feedback_pending:
		return
	var command_log := Array(snap.get("command_log", []))
	if command_log.is_empty() or String(Dictionary(command_log.back()).get("type", "")) != "AUTO_POSITION_HEROES":
		return
	_auto_position_feedback_pending = false
	auto_arrange_button.disabled = _battle_input_locked
	var result := Dictionary(snap.get("lastCommandResult", snap.get("last_command_result", {})))
	var difficulty := String(snap.get("difficulty", "normal"))
	var feedback_text := String(_hud_controller.call("auto_position_feedback", snap, result))
	GameLogScript.info("表现/自动布置", "核心结果已显示给玩家", {
		"结果": "成功" if bool(result.get("ok", false)) else "失败",
		"提示": feedback_text,
		"移动宠物": Array(result.get("moves", [])).size(),
		"难度": difficulty
	})
	_show_auto_position_feedback(feedback_text, difficulty)


func _show_auto_position_feedback(text: String, difficulty: String) -> void:
	_position_feedback_serial += 1
	var serial := _position_feedback_serial
	position_difficulty_button.text = text
	position_difficulty_button.modulate = Color("#d9ffc9")
	var fade := create_tween()
	fade.tween_property(position_difficulty_button, "modulate", Color.WHITE, 0.45)
	await get_tree().create_timer(3.0, true, false, true).timeout
	if serial != _position_feedback_serial:
		return
	_apply_position_difficulty_label(String(_last_snapshot.get("difficulty", difficulty)))


func _on_position_difficulty_toggled(use_easy: bool) -> void:
	if _battle_input_locked:
		_update_position_difficulty_button(_last_snapshot)
		return
	var difficulty := "easy" if use_easy else "normal"
	_apply_position_difficulty_label(difficulty)
	command_requested.emit({"type": "SET_DIFFICULTY", "difficulty": difficulty})


func _update_position_difficulty_button(snap: Dictionary) -> void:
	_apply_position_difficulty_label(String(snap.get("difficulty", "normal")))


func _apply_position_difficulty_label(difficulty: String) -> void:
	if position_difficulty_button == null:
		return
	var use_easy := difficulty == "easy"
	position_difficulty_button.set_pressed_no_signal(use_easy)
	position_difficulty_button.text = String(_hud_controller.call("difficulty_label", difficulty))
	position_difficulty_button.tooltip_text = String(_hud_controller.call("difficulty_tooltip"))


func _style_position_difficulty_button() -> void:
	if position_difficulty_button == null:
		return
	position_difficulty_button.add_theme_font_size_override("font_size", 21)
	position_difficulty_button.add_theme_color_override("font_color", Color("#f7ead0"))
	position_difficulty_button.add_theme_color_override("font_pressed_color", Color("#fff7d6"))
	position_difficulty_button.add_theme_stylebox_override("normal", _make_position_difficulty_style(Color("#312a22"), Color("#8c765d")))
	position_difficulty_button.add_theme_stylebox_override("hover", _make_position_difficulty_style(Color("#42382c"), Color("#d0a85f")))
	position_difficulty_button.add_theme_stylebox_override("pressed", _make_position_difficulty_style(Color("#315338"), Color("#d6b55f")))


func _make_position_difficulty_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style


func _on_begin_turn_pressed() -> void:
	if _battle_input_locked:
		return
	command_requested.emit({"type": "RUN_COMBAT_ROUND"})


func _ensure_detail_panel() -> void:
	if _detail_panel != null:
		return
	_detail_panel = PetDetailPanelScene.instantiate() as Control
	if _detail_panel == null:
		return
	_detail_panel.name = "BattlePetDetailPanel"
	_detail_panel.visible = false
	_detail_panel.z_index = 42
	cell_detail.call("mount_detail_panel", _detail_panel)

	_element_detail_panel = TerrainDetailScene.instantiate() as PanelContainer
	if _element_detail_panel == null:
		return
	_element_detail_panel.name = "BattleElementDetailPanel"
	_element_detail_panel.visible = false
	_element_detail_panel.z_index = 42
	_element_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_element_detail_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_element_detail_panel.position = DETAIL_PANEL_POSITION
	_element_detail_panel.custom_minimum_size = DETAIL_PANEL_SIZE
	_element_detail_panel.size = DETAIL_PANEL_SIZE
	cell_detail.call("mount_detail_panel", _element_detail_panel)


func _render_pet_detail(snap: Dictionary) -> void:
	_ensure_detail_panel()
	if _detail_panel == null or _element_detail_panel == null:
		return
	var detail := Dictionary(_detail_controller.call("resolve_detail", snap, _active_detail_grid, _active_detail_unit_id))
	var unit := _dict(detail.get("unit", {}))
	var cell_elements := _dict(detail.get("elements", {}))
	if unit.is_empty() and not bool(_detail_controller.call("has_visible_elements", cell_elements)):
		_clear_active_detail()
		return
	if unit.is_empty():
		if _detail_panel.has_method("close"):
			_detail_panel.call("close")
		else:
			_detail_panel.visible = false
		_element_detail_panel.visible = true
		_render_element_cell_detail(detail, cell_elements)
		return
	_element_detail_panel.visible = false
	_active_detail_unit_id = String(unit.get("id", unit.get("unitId", _active_detail_unit_id)))
	var card_record := _battle_pet_detail_record(detail, unit, snap)
	var texture := _battle_detail_texture(unit)
	if _detail_panel.has_method("show_context_detail"):
		_detail_panel.call("show_context_detail", card_record, texture)
	else:
		_detail_panel.visible = true


func _battle_pet_detail_record(detail: Dictionary, unit: Dictionary, snap: Dictionary) -> Dictionary:
	return Dictionary(_detail_controller.call(
		"pet_record",
		unit,
		_detail_controller.call("skill_text", unit, snap, _selected_unit_id()),
		_detail_controller.call("attack_shape", detail, unit, snap)
	))


func _battle_detail_texture(unit: Dictionary) -> Texture2D:
	if _assets == null or not _assets.has_method("texture_for_unit"):
		return null
	var resolved := Dictionary(_assets.call("texture_for_unit", unit, String(unit.get("side", "player"))))
	return resolved.get("texture") as Texture2D


func _render_element_cell_detail(detail: Dictionary, elements: Dictionary) -> void:
	_active_detail_unit_id = ""
	if _element_detail_panel != null and _element_detail_panel.has_method("render_detail"):
		_element_detail_panel.call("render_detail", detail, elements, _detail_controller)


func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return Dictionary(value)
	return {}


func _cell_has_unit(grid: Vector2i) -> bool:
	var data := _cell_data_at_grid(grid)
	return String(data.get("unitId", data.get("unit_id", ""))) != ""


func _cell_has_visible_elements(grid: Vector2i) -> bool:
	return bool(_detail_controller.call("has_visible_elements", _dict(_cell_data_at_grid(grid).get("elements", {}))))


func _cell_data_at_grid(grid: Vector2i) -> Dictionary:
	if not _is_visible_board_cell(grid.x, grid.y):
		return {}
	return _cell_data_for_cell(_cell_at(grid.x, grid.y))


func _cell_data_for_cell(cell: Node) -> Dictionary:
	if cell == null:
		return {}
	var raw_data = cell.get("cell_data")
	if raw_data is Dictionary:
		return Dictionary(raw_data)
	return {}


func _ensure_command_tools() -> void:
	if _command_tools != null:
		return
	_command_tools = PanelContainer.new()
	_command_tools.name = "BattleCommandTools"
	_command_tools.z_index = 40
	_command_tools.mouse_filter = Control.MOUSE_FILTER_STOP
	_command_tools.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_command_tools.position = Vector2(1576.0, 438.0)
	_command_tools.custom_minimum_size = Vector2(300.0, 258.0)
	_command_tools.add_theme_stylebox_override("panel", _make_command_tools_style())

	var grid := GridContainer.new()
	grid.name = "BattleCommandGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_command_tools.add_child(grid)

	_add_command_tool_button(grid, "槽位", "SelectActionSlotButton", "SELECT_ACTION_SLOT")
	_add_command_tool_button(grid, "方向", "SetActionDirectionButton", "SET_ACTION_DIRECTION")
	_add_command_tool_button(grid, "AP", "SetActionApButton", "SET_ACTION_AP")
	_add_command_tool_button(grid, "施放", "UseActionSlotButton", "USE_ACTION_SLOT")
	_add_command_tool_button(grid, "全出击", "RunPlayerAllOutButton", "RUN_PLAYER_ALL_OUT")
	_add_command_tool_button(grid, "结束", "EndPlayerTurnButton", "END_PLAYER_TURN")
	_add_command_tool_button(grid, "AI行动", "RunMonsterTurnButton", "RUN_MONSTER_TURN")
	_add_command_tool_button(grid, "自动战斗", "RunBattleButton", "RUN_BATTLE")
	board.call("add_runtime_control", _command_tools)


func _ensure_action_panel() -> void:
	if _action_panel != null:
		return
	_action_panel = board.call("get_action_panel") as Control
	if _action_panel == null:
		return
	if _action_panel.has_signal("command_requested"):
		_action_panel.connect("command_requested", Callable(self, "_on_action_panel_command_requested"))


func _render_action_panel(snap: Dictionary) -> void:
	_ensure_action_panel()
	if _action_panel != null and _action_panel.has_method("render_snapshot"):
		_action_panel.call("render_snapshot", snap)


func _ensure_direction_drawer() -> void:
	if _direction_drawer != null:
		return
	_direction_drawer = board.call("get_attack_direction_drawer") as Control


func _render_direction_drawer(snap: Dictionary) -> void:
	_ensure_direction_drawer()
	if _direction_drawer != null and _direction_drawer.has_method("render_snapshot"):
		_direction_drawer.call("render_snapshot", snap)


func _on_action_panel_command_requested(command: Dictionary) -> void:
	if _battle_input_locked:
		return
	if not command.is_empty():
		command_requested.emit(command)


func _add_command_tool_button(parent: Control, label_text: String, button_name: String, command_type: String) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = label_text
	button.custom_minimum_size = COMMAND_TOOL_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.set_meta("command_type", command_type)
	button.pressed.connect(_on_command_tool_pressed.bind(command_type))
	parent.add_child(button)


func _on_command_tool_pressed(command_type: String) -> void:
	if _battle_input_locked:
		return
	var command := _battle_command(command_type)
	if command.is_empty():
		return
	command_requested.emit(command)


func _battle_command(command_type: String) -> Dictionary:
	return Dictionary(_command_builder.call("build", command_type, _last_snapshot))


func _selected_unit_id() -> String:
	return String(_command_builder.call("selected_unit_id", _last_snapshot))


func _selected_slot_index() -> int:
	return int(_command_builder.call("selected_slot_index", _last_snapshot))


func _make_command_tools_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.76)
	style.border_color = Color(0.78, 0.61, 0.33, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	return style
