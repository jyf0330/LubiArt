extends Control

## Authored Board responsibility root. It owns cell/unit presentation, local
## optimistic drag projection and semantic board input only.

signal command_requested(command: Dictionary)
signal cell_detail_requested(grid: Vector2i, unit_id: String)

const BattleBoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const BattleBoardControllerScript := preload("res://core_ui/scripts/battle/controllers/battle_board_controller.gd")
const BattleBoardLayoutScript := preload("res://core_ui/scripts/battle/controllers/battle_board_layout.gd")
const BattlePreviewPresenterScript := preload("res://core_ui/scripts/battle/controllers/battle_preview_presenter.gd")
const GameLogScript := preload("res://core/logging/game_log.gd")
const BattleCellScene := preload("res://art/prefabs/terrain/terrain.tscn")
const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")

const DEFAULT_BOARD_COLUMNS := BattleBoardDimensionsScript.DEFAULT_WIDTH
const DEFAULT_BOARD_ROWS := BattleBoardDimensionsScript.DEFAULT_HEIGHT
const CELL_GAP := Vector2.ZERO
const DRAG_CLICK_THRESHOLD := 12.0
const DROP_SETTLE_DURATION := 0.12
const DROP_RETURN_DURATION := 0.16

@onready var board: Control = self
@onready var board_background: TextureRect = $Background
@onready var board_grid: Control = $CellHost
@onready var unit_host: Control = $UnitHost

var _assets: RefCounted = null
var _cell_size := Vector2.ZERO
var _cells: Array[Control] = []
var _cell_pool: Array[Control] = []
var _board_columns := DEFAULT_BOARD_COLUMNS
var _board_rows := DEFAULT_BOARD_ROWS
var _last_snapshot: Dictionary = {}
var _missing_mappings := {}
var _hovered_grid := Vector2i(-1, -1)
var _drag_unit_id := ""
var _drag_origin := Vector2i(-1, -1)
var _drag_preview: Control = null
var _drag_offset := Vector2.ZERO
var _drag_preview_target := Vector2i(-1, -1)
var _drag_attack_highlight_keys: Array[String] = []
var _drag_attack_marker_keys: Array[String] = []
var _drag_damage_preview_unit_ids: Array[String] = []
var _direction_hover_highlight_keys: Array[String] = []
var _drag_hover_grid := Vector2i(-1, -1)
var _drag_start_mouse_position := Vector2.ZERO
var _drag_has_moved := false
var _drop_settle_active := false
var _drop_settle_preview: Control = null
var _drop_settle_unit_id := ""
var _drop_settle_grid := Vector2i(-1, -1)
var _suppress_next_select := false
var _battle_input_locked := false
var _last_rendered_cell_count := 0
var _enemy_damage_preview_sync_epoch_msec := -1
var _board_controller := BattleBoardControllerScript.new()
var _preview_presenter := BattlePreviewPresenterScript.new()
var _board_layout := BattleBoardLayoutScript.new()
var _unit_nodes_by_id := {}
var _unit_pool: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	set_process(false)
	_build_board()


func configure(assets: RefCounted) -> void:
	_assets = assets


func set_input_locked(locked: bool) -> void:
	if _battle_input_locked != locked:
		GameLogScript.debug("表现/输入锁", "战斗棋盘输入状态变化", {"状态": "锁定" if locked else "解锁"})
	_battle_input_locked = locked
	if locked:
		_set_cursor_grabbing(false)
		_set_cursor_pet_hover(false)
	else:
		_refresh_cursor_hover_state()


func show_direction_preview(unit_id: String, direction: String) -> void:
	if unit_id == "" or direction == "":
		_clear_direction_hover_preview()
		return
	_show_direction_hover_preview(unit_id, direction)


func apply_enemy_move_final_cell(unit_id: String, cell: Dictionary) -> void:
	if unit_id == "" or cell.is_empty():
		return
	var previous_grid := _rendered_grid_for_unit_id(unit_id)
	if previous_grid.x >= 0 and previous_grid.y >= 0:
		var previous_cell := _cell_at(previous_grid.x, previous_grid.y)
		var cleared := _cell_data_for_cell(previous_cell).duplicate(true)
		_clear_cell_unit_projection(cleared)
		previous_cell.call("set_cell_data", cleared, _assets)
		_sync_cell_unit(previous_cell, cleared, true)
	var x := int(cell.get("x", cell.get("c", -1)))
	var y := int(cell.get("y", cell.get("r", -1)))
	if not _is_visible_board_cell(x, y):
		return
	var destination := _cell_at(x, y)
	var final_cell := cell.duplicate(true)
	destination.call("set_cell_data", final_cell, _assets)
	_sync_cell_unit(destination, final_cell, true)
	_render_cell_trace_effects(destination, final_cell)


func reveal_reset_units(units: Array) -> void:
	_reveal_reset_units(units)


func clear_transient_state() -> void:
	if _drag_unit_id != "":
		var preview := _take_drag_preview()
		_set_cell_unit_dragging(_drag_origin, false)
		_reset_drag_tracking()
		_free_drop_preview(preview)
	_clear_drag_attack_preview()
	_clear_drag_hover_highlight()
	_clear_direction_hover_preview()
	_stop_enemy_damage_previews()


func board_dimensions() -> Vector2i:
	return Vector2i(_board_columns, _board_rows)


func rendered_cell_count() -> int:
	return _last_rendered_cell_count


func missing_mapping_report() -> Array:
	var values := _missing_mappings.values()
	values.sort_custom(func(a, b):
		return String(Dictionary(a).get("key", "")) < String(Dictionary(b).get("key", ""))
	)
	return values


func _exit_tree() -> void:
	_set_cursor_grabbing(false)
	_set_cursor_pet_hover(false)


func _game_cursor() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"game_cursor")


func _set_cursor_pet_hover(active: bool) -> void:
	var cursor := _game_cursor()
	if cursor != null and cursor.has_method("set_pet_hover"):
		cursor.call("set_pet_hover", active)


func _set_cursor_grabbing(active: bool) -> void:
	var cursor := _game_cursor()
	if cursor != null and cursor.has_method("set_grabbing"):
		cursor.call("set_grabbing", active)


func _refresh_cursor_hover_state() -> void:
	if _battle_input_locked or _drag_unit_id != "" or _hovered_grid.x < 0 or _hovered_grid.y < 0:
		_set_cursor_pet_hover(false)
		return
	_set_cursor_pet_hover(_mouse_is_over_draggable_pet(_cell_at(_hovered_grid.x, _hovered_grid.y)))


func _refresh_cursor_hover_at(grid: Vector2i) -> void:
	if _battle_input_locked or _drag_unit_id != "":
		_set_cursor_pet_hover(false)
		return
	_set_cursor_pet_hover(_mouse_is_over_draggable_pet(_cell_at(grid.x, grid.y)))


func _mouse_is_over_draggable_pet(cell: Control) -> bool:
	if not _cell_has_draggable_player_unit(cell):
		return false
	var unit := cell.call("get_unit_node") as Control
	if unit == null:
		return false
	var mouse_position := get_viewport().get_mouse_position()
	if unit.has_method("contains_art_point"):
		return bool(unit.call("contains_art_point", mouse_position))
	return unit.get_global_rect().has_point(mouse_position)


func _process(_delta: float) -> void:
	_update_drag_preview()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _drag_unit_id == "":
		_refresh_cursor_hover_state()
	if _battle_input_locked:
		return
	if event is InputEventMouseMotion and _drag_unit_id != "":
		var motion := event as InputEventMouseMotion
		var board_local := board_grid.get_global_transform_with_canvas().affine_inverse() * motion.position
		_update_drag_preview_at_board_position(board_local)
		return
	if _drag_unit_id == "" or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
		return
	var board_local := board_grid.get_global_transform_with_canvas().affine_inverse() * mouse_event.position
	_finish_unit_drag(_grid_from_board_position(board_local))
	get_viewport().set_input_as_handled()


func render_snapshot(snapshot: Dictionary, cells: Array, pending_reset_ids: Dictionary = {}) -> void:
	_last_snapshot = snapshot.duplicate(true)
	_render_battle_background(snapshot)
	_missing_mappings = {}
	var board_data := Dictionary(snapshot.get("board", {}))
	_set_board_dimensions(BattleBoardDimensionsScript.from_board(board_data, Vector2i(_board_columns, _board_rows)))
	_ensure_board()
	_clear_all_cell_highlights()
	_last_rendered_cell_count = 0
	_render_board_cells(cells, pending_reset_ids)
	_apply_selected_action_block_ranges(snapshot)
	_sync_enemy_damage_previews()
	_restore_drag_visual_state()
	_restore_drop_settle_visual_state()


func _render_battle_background(snapshot: Dictionary) -> void:
	if board_background == null or _assets == null or not _assets.has_method("battle_background_texture"):
		return
	var texture_resource := _assets.call("battle_background_texture", snapshot) as Texture2D
	if texture_resource != null:
		board_background.texture = texture_resource


func _render_board_cells(cells: Array, pending_reset_ids: Dictionary = {}) -> void:
	var desired_unit_ids := {}
	for cell_value in cells:
		var desired_cell := Dictionary(cell_value)
		var desired_unit_id := String(desired_cell.get("unitId", desired_cell.get("unit_id", "")))
		if desired_unit_id != "":
			desired_unit_ids[desired_unit_id] = true
	_release_unused_units(desired_unit_ids)
	for cell_value in cells:
		var cell := Dictionary(cell_value).duplicate(true)
		var x := int(cell.get("x", cell.get("c", -1)))
		var y := int(cell.get("y", cell.get("r", -1)))
		if not _is_visible_board_cell(x, y):
			continue
		if pending_reset_ids.has(String(cell.get("unitId", cell.get("unit_id", "")))):
			_clear_cell_unit_projection(cell)
		var cell_node := _cell_at(x, y)
		var transient_element_dirty := false
		if cell_node.has_method("consume_transient_element_visual_dirty"):
			transient_element_dirty = bool(cell_node.call("consume_transient_element_visual_dirty"))
		var cell_changed := _cell_data_for_cell(cell_node) != cell or transient_element_dirty
		if cell_changed and cell_node.has_method("set_cell_data"):
			cell_node.call("set_cell_data", cell, _assets)
			_render_cell_trace_effects(cell_node, cell)
			_last_rendered_cell_count += 1
		_sync_cell_unit(cell_node, cell, cell_changed)
		_collect_cell_missing_mappings(cell_node)
	for cell in _cells:
		var cell_id := String(_cell_data_for_cell(cell).get("unitId", _cell_data_for_cell(cell).get("unit_id", "")))
		if cell_id == "" and cell.has_method("set_unit_node"):
			cell.call("set_unit_node", null)


func _release_unused_units(desired_unit_ids: Dictionary) -> void:
	for unit_id_value in _unit_nodes_by_id.keys():
		var unit_id := String(unit_id_value)
		if desired_unit_ids.has(unit_id):
			continue
		var unit := _unit_nodes_by_id[unit_id] as Control
		_unit_nodes_by_id.erase(unit_id)
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.has_method("reset_pet_view"):
			unit.call("reset_pet_view")
		unit.visible = false
		unit.name = "PooledBattleUnit_%d" % _unit_pool.size()
		_unit_pool.append(unit)


func _sync_cell_unit(cell: Control, cell_data: Dictionary, data_changed: bool = true) -> void:
	if cell == null:
		return
	var unit_id := String(cell_data.get("unitId", cell_data.get("unit_id", "")))
	if unit_id == "":
		if cell.has_method("set_unit_node"):
			cell.call("set_unit_node", null)
		return
	var unit := _unit_nodes_by_id.get(unit_id) as Control
	var created := false
	if unit == null or not is_instance_valid(unit):
		unit = _acquire_unit_node(unit_id)
		created = unit != null
	if unit == null:
		return
	unit.visible = true
	unit.position = cell.position
	unit.size = cell.size
	unit.custom_minimum_size = Vector2.ZERO
	unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit.z_index = 2
	if cell.has_method("set_unit_node"):
		cell.call("set_unit_node", unit)
	if (created or data_changed) and unit.has_method("set_unit_data"):
		var side := String(cell_data.get("side", cell_data.get("unitSide", "")))
		unit.call("set_unit_data", cell_data, side, _assets)
	if unit.has_method("get_missing_mapping"):
		var missing := Dictionary(unit.call("get_missing_mapping"))
		if not missing.is_empty():
			_missing_mappings[String(missing.get("key", ""))] = missing


func _acquire_unit_node(unit_id: String) -> Control:
	var unit: Control = null
	if not _unit_pool.is_empty():
		unit = _unit_pool.pop_back()
	else:
		unit = BattleUnitScene.instantiate() as Control
		if unit != null:
			# Clear the collection-prefab minimum before the node enters UnitHost.
			# Otherwise its first ready/layout pass expands to 180x180 and only a
			# later snapshot render restores the authored board-cell size.
			unit.custom_minimum_size = Vector2.ZERO
			unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
			unit_host.add_child(unit)
	if unit == null:
		return null
	unit.name = "BattleUnit_%s" % _safe_node_name(unit_id)
	_unit_nodes_by_id[unit_id] = unit
	return unit


func _safe_node_name(value: String) -> String:
	var result := value.validate_node_name().replace(" ", "_")
	return result if result != "" else "unit"


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
	var selected_unit := _unit_data_by_id(snap, selected_unit_id)
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


func _build_board() -> void:
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
			if cell.has_method("set_hovered"):
				cell.call("set_hovered", false)
			if cell.has_method("clear_highlight"):
				cell.call("clear_highlight")
			if cell.has_method("set_cell_data"):
				cell.call("set_cell_data", {}, _assets)
			if cell.has_method("set_unit_node"):
				cell.call("set_unit_node", null)
			continue
		var x := index % _board_columns
		var y := int(index / _board_columns)
		_board_layout.call(
			"apply_cell_geometry",
			cell,
			x,
			y,
			Vector2i(_board_columns, _board_rows),
			board_size,
			CELL_GAP
		)
		if cell.has_method("set_hovered"):
			cell.call("set_hovered", _hovered_grid == Vector2i(x, y))
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
	if not cell_node.has_method("show_element_tile"):
		return
	var traces := Array(cell_data.get("traces", []))
	if traces.is_empty() and cell_data.has("trace"):
		traces = [Dictionary(cell_data.get("trace", {}))]
	for trace_value in traces:
		var trace := Dictionary(trace_value)
		var element := _trace_element(String(trace.get("kind", "")))
		if element == "":
			continue
		cell_node.call("show_element_tile", element)
		return


func _reveal_reset_units(units: Array) -> void:
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
			_sync_cell_unit(cell_node, cell, true)
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
	# Authored perspective cells overlap. Match Godot's topmost Control input
	# order by testing the later-drawn cells first, otherwise the previous row
	# can swallow every point in the optional eighth row.
	for index in range(_cells.size() - 1, -1, -1):
		var cell := _cells[index]
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
	cell_detail_requested.emit(Vector2i(-1, -1), "")
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
	if _drag_unit_id != "":
		_refresh_drag_attack_preview(grid, true)
	if _hovered_grid == grid:
		return
	if _hovered_grid.x >= 0 and _hovered_grid.y >= 0:
		_set_cell_hovered(_hovered_grid, false)
	if _drag_unit_id != "" and not _can_drag_preview_at(grid):
		_hovered_grid = Vector2i(-1, -1)
		_set_cell_hovered(grid, false)
		return
	_hovered_grid = grid
	_set_cell_hovered(grid, true)
	_refresh_cursor_hover_state()


func _on_cell_unhovered(x: int, y: int) -> void:
	var grid := Vector2i(x, y)
	if _hovered_grid == grid:
		_set_cell_hovered(grid, false)
		_hovered_grid = Vector2i(-1, -1)
	if _drag_unit_id == "":
		_set_cursor_pet_hover(false)


func _start_unit_drag(grid: Vector2i) -> void:
	if _drop_settle_active:
		return
	var cell := _cell_at(grid.x, grid.y)
	if not _cell_has_draggable_player_unit(cell):
		return
	var unit := cell.call("get_unit_node") as Control
	if unit == null or not unit.has_method("get_unit_id"):
		return
	cell_detail_requested.emit(Vector2i(-1, -1), "")
	_drag_unit_id = String(unit.call("get_unit_id"))
	_stop_enemy_damage_previews()
	_set_cursor_pet_hover(false)
	_set_cursor_grabbing(true)
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
	var can_drop := _can_drop_dragged_unit_at(target)
	var settle_preview := _take_drag_preview()
	_clear_cell_highlight(origin)
	_release_drag_damage_previews()
	_clear_drag_attack_preview(false)
	_clear_drag_hover_highlight()
	_reset_drag_tracking()
	_set_cursor_grabbing(false)
	_set_cursor_pet_hover(false)
	if target == origin and not was_dragged:
		_free_drop_preview(settle_preview)
		_set_cell_unit_dragging(origin, false)
		_sync_enemy_damage_previews()
		_suppress_next_select = true
		_request_cell_detail(origin)
		_refresh_cursor_hover_at(target)
		return
	if target == origin:
		_suppress_next_select = true
		_start_drop_settle(settle_preview, dragged_unit_id, origin, target, origin)
		_refresh_cursor_hover_at(target)
		return
	var command := {}
	var settled_grid := origin
	if can_drop and _apply_local_unit_drop(dragged_unit_id, origin, target):
		command = {
			"type": "MOVE_HERO",
			"unitId": dragged_unit_id,
			"x": target.x,
			"y": target.y,
			"cell": {"x": target.x, "y": target.y}
		}
		command_requested.emit(command)
		settled_grid = target
	_suppress_next_select = true
	_start_drop_settle(settle_preview, dragged_unit_id, origin, target, settled_grid)
	_refresh_cursor_hover_at(target)


func _can_drop_dragged_unit_at(target: Vector2i) -> bool:
	if not _is_visible_board_cell(target.x, target.y) or target == _drag_origin:
		return false
	return not _cell_has_unit(target)


func _apply_local_unit_drop(unit_id: String, origin: Vector2i, target: Vector2i) -> bool:
	var origin_cell := _cell_at(origin.x, origin.y)
	var target_cell := _cell_at(target.x, target.y)
	if origin_cell == null or target_cell == null or _cell_has_unit(target):
		return false
	var origin_data := _cell_data_for_cell(origin_cell).duplicate(true)
	var target_data := _cell_data_for_cell(target_cell).duplicate(true)
	if String(origin_data.get("unitId", origin_data.get("unit_id", ""))) != unit_id:
		return false

	# Keep the authored drag responsive while Game submits MOVE_HERO. The next
	# public Snapshot remains authoritative and replaces this local projection.
	var moved_data := origin_data.duplicate(true)
	_copy_cell_location(moved_data, target_data)
	var emptied_origin := target_data.duplicate(true)
	_copy_cell_location(emptied_origin, origin_data)
	origin_cell.call("set_cell_data", emptied_origin, _assets)
	target_cell.call("set_cell_data", moved_data, _assets)
	_sync_cell_unit(origin_cell, emptied_origin, true)
	_sync_cell_unit(target_cell, moved_data, true)
	_render_cell_trace_effects(origin_cell, emptied_origin)
	_render_cell_trace_effects(target_cell, moved_data)
	_collect_cell_missing_mappings(target_cell)
	return true


func _copy_cell_location(destination: Dictionary, source: Dictionary) -> void:
	for key in ["x", "y", "r", "c", "key", "elements", "trace", "traces"]:
		if source.has(key):
			destination[key] = source[key].duplicate(true) if source[key] is Dictionary or source[key] is Array else source[key]
		else:
			destination.erase(key)


func _take_drag_preview() -> Control:
	var preview := _drag_preview
	_drag_preview = null
	return preview


func _reset_drag_tracking() -> void:
	_drag_unit_id = ""
	set_process(false)
	_drag_origin = Vector2i(-1, -1)
	_drag_preview_target = Vector2i(-1, -1)
	_drag_start_mouse_position = Vector2.ZERO
	_drag_has_moved = false


func _grid_for_unit_id(unit_id: String) -> Vector2i:
	return _rendered_grid_for_unit_id(unit_id)


func _start_drop_settle(preview: Control, unit_id: String, origin: Vector2i, requested: Vector2i, settled: Vector2i) -> void:
	var is_return := settled == origin and requested != origin
	var duration := DROP_RETURN_DURATION if is_return else DROP_SETTLE_DURATION
	if preview == null or not is_instance_valid(preview):
		_set_cell_unit_dragging(settled, false)
		_sync_enemy_damage_previews(true)
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
	_sync_enemy_damage_previews(true)


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


func _clear_drag_hover_highlight() -> void:
	if _hovered_grid.x >= 0 and _hovered_grid.y >= 0:
		_set_cell_hovered(_hovered_grid, false)
	_hovered_grid = Vector2i(-1, -1)
	if _drag_preview_target.x >= 0 and _drag_preview_target.y >= 0:
		_set_cell_hovered(_drag_preview_target, false)
	if _drag_hover_grid.x >= 0 and _drag_hover_grid.y >= 0:
		_set_cell_hovered(_drag_hover_grid, false)
	_drag_hover_grid = Vector2i(-1, -1)


func _request_cell_detail(grid: Vector2i) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	var data := _cell_data_at_grid(grid)
	var x := int(data.get("x", data.get("c", grid.x)))
	var y := int(data.get("y", data.get("r", grid.y)))
	cell_detail_requested.emit(
		Vector2i(x, y),
		String(data.get("unitId", data.get("unit_id", "")))
	)
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
	preview.position = unit_host.get_local_mouse_position() - _drag_offset
	preview.size = _cell_size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_host.add_child(preview)
	if preview.has_method("set_unit_data"):
		preview.call("set_unit_data", Dictionary(raw_data).duplicate(true), String(unit.get("side")), _assets)
	if preview.has_method("set_dragging"):
		preview.call("set_dragging", false)
	preview.z_as_relative = false
	preview.z_index = 180
	preview.modulate.a = 0.94
	unit_host.move_child(preview, unit_host.get_child_count() - 1)
	_drag_preview = preview


func _update_drag_preview() -> void:
	if _drag_unit_id == "" or _drag_preview == null or not is_instance_valid(_drag_preview):
		return
	_update_drag_preview_at_board_position(board_grid.get_local_mouse_position())


func _update_drag_preview_at_board_position(local_mouse: Vector2) -> void:
	if _drag_unit_id == "" or _drag_preview == null or not is_instance_valid(_drag_preview):
		return
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


func _restore_drag_visual_state() -> void:
	if _drag_unit_id == "":
		return
	_stop_enemy_damage_previews()
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
	_refresh_drag_incoming_damage_preview(target)
	if not _is_visible_board_cell(target.x, target.y):
		return
	_show_drag_attack_cells(_drag_attack_cells_for_target(target))


func _refresh_drag_incoming_damage_preview(target: Vector2i) -> void:
	if _drag_preview == null or not is_instance_valid(_drag_preview) \
			or not _drag_preview.has_method("start_damage_preview"):
		return
	if not _can_drag_preview_at(target):
		if _drag_preview.has_method("stop_damage_preview"):
			_drag_preview.call("stop_damage_preview")
		return
	var origin_cell := _cell_at(_drag_origin.x, _drag_origin.y)
	if origin_cell == null:
		return
	var cell_data := _cell_data_for_cell(origin_cell)
	var preview := _incoming_player_drag_damage_preview(cell_data)
	if not _damage_preview_is_complete(preview):
		if _drag_preview.has_method("stop_damage_preview"):
			_drag_preview.call("stop_damage_preview")
		return
	var current_hp := int(cell_data.get("hp", 0))
	var current_shield := int(cell_data.get("shield", 0))
	_drag_preview.call(
		"start_damage_preview",
		current_hp,
		_preview_int(preview, ["predictedHpTo", "predicted_hp_to", "hpTo", "hp_to"]),
		-1,
		_preview_int(preview, ["predictedDamage", "predicted_damage", "totalDamage", "total_damage", "damage", "threat"]),
		current_shield,
		_preview_int(preview, ["predictedShieldTo", "predicted_shield_to", "shieldTo", "shield_to"]),
		int(cell_data.get("max_hp", cell_data.get("maxHp", current_hp))),
		true
	)


func _clear_drag_attack_preview(stop_damage_previews: bool = true) -> void:
	if stop_damage_previews:
		_clear_drag_damage_previews()
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


func _clear_direction_hover_preview() -> void:
	for key in _direction_hover_highlight_keys:
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		var grid := Vector2i(int(parts[0]), int(parts[1]))
		var cell := _cell_at(grid.x, grid.y)
		if cell != null and cell.has_method("set_attack_highlight_blinking"):
			cell.call("set_attack_highlight_blinking", false)
		if not _drag_attack_highlight_keys.has(key):
			_clear_cell_highlight(grid)
	_direction_hover_highlight_keys.clear()


func _show_direction_hover_preview(unit_id: String, direction: String) -> void:
	_clear_direction_hover_preview()
	if _drag_unit_id != "" or _battle_input_locked:
		return
	for grid in _direction_preview_cells(unit_id, direction):
		if not _cell_allows_attack_highlight(grid):
			continue
		_set_cell_highlight(grid, "attack")
		var cell := _cell_at(grid.x, grid.y)
		if cell != null and cell.has_method("set_attack_highlight_blinking"):
			cell.call("set_attack_highlight_blinking", true)
		_direction_hover_highlight_keys.append(_cell_key(grid))


func _direction_preview_cells(unit_id: String, direction: String) -> Array[Vector2i]:
	var projected: Array[Vector2i] = _preview_presenter.call(
		"direction_cells",
		_last_snapshot,
		unit_id,
		direction,
		Vector2i(_board_columns, _board_rows)
	)
	return projected


func _rendered_grid_for_unit_id(unit_id: String) -> Vector2i:
	for cell in _cells:
		var data := _cell_data_for_cell(cell)
		if String(data.get("unitId", data.get("unit_id", ""))) == unit_id:
			return cell.call("get_grid_position") as Vector2i
	return Vector2i(-1, -1)


func _refresh_drag_hover_highlight(target: Vector2i, force: bool = false) -> void:
	if _drag_unit_id == "":
		return
	if not force and target == _drag_hover_grid:
		return
	if _drag_hover_grid.x >= 0 and _drag_hover_grid.y >= 0:
		_set_cell_hovered(_drag_hover_grid, false)
	_drag_hover_grid = Vector2i(-1, -1)
	if not _is_visible_board_cell(target.x, target.y) or not _can_drag_preview_at(target):
		return
	_drag_hover_grid = target
	_set_cell_hovered(target, true)


func _show_drag_attack_cells(cells: Array[Vector2i]) -> void:
	var enemy_attack_cells: Array[Vector2i] = []
	for index in range(cells.size()):
		var grid := cells[index]
		if not _cell_allows_attack_highlight(grid):
			continue
		_set_cell_highlight(grid, "attack")
		_drag_attack_highlight_keys.append(_cell_key(grid))
		if _cell_is_enemy_occupied(grid):
			enemy_attack_cells.append(grid)
	if not enemy_attack_cells.is_empty():
		_show_drag_damage_previews(enemy_attack_cells)
		var marker_grid := enemy_attack_cells[enemy_attack_cells.size() - 1]
		var preview := _drag_action_preview()
		_set_cell_attack_order_marker(marker_grid, int(preview.get("slotIndex", _selected_slot_index())) + 1)
		_drag_attack_marker_keys.append(_cell_key(marker_grid))


func _show_drag_damage_previews(enemy_cells: Array[Vector2i]) -> void:
	for grid in enemy_cells:
		var cell := _cell_at(grid.x, grid.y)
		if cell == null or not cell.has_method("get_unit_node"):
			continue
		var unit := cell.call("get_unit_node") as Control
		if unit == null or not unit.has_method("start_damage_preview"):
			continue
		var cell_data := _cell_data_for_cell(cell)
		var preview := _enemy_damage_preview_for_actor(cell_data, _drag_unit_id)
		if not _damage_preview_is_complete(preview):
			continue
		var unit_id := String(cell_data.get("unitId", cell_data.get("unit_id", "")))
		var current_hp := int(cell_data.get("hp", 0))
		var current_shield := int(cell_data.get("shield", 0))
		unit.call(
			"start_damage_preview",
			current_hp,
			_preview_int(preview, ["predictedHpTo", "predicted_hp_to", "hpTo", "hp_to"]),
			-1,
			_preview_int(preview, ["predictedDamage", "predicted_damage", "totalDamage", "total_damage", "damage", "threat"]),
			current_shield,
			_preview_int(preview, ["predictedShieldTo", "predicted_shield_to", "shieldTo", "shield_to"]),
			int(cell_data.get("max_hp", cell_data.get("maxHp", current_hp))),
			true
		)
		if unit_id != "" and not _drag_damage_preview_unit_ids.has(unit_id):
			_drag_damage_preview_unit_ids.append(unit_id)


func _clear_drag_damage_previews() -> void:
	for unit_id in _drag_damage_preview_unit_ids:
		var unit := _rendered_unit_node(unit_id)
		if unit != null and unit.has_method("stop_damage_preview"):
			unit.call("stop_damage_preview")
	_drag_damage_preview_unit_ids.clear()


func _release_drag_damage_previews() -> void:
	for unit_id in _drag_damage_preview_unit_ids:
		var unit := _rendered_unit_node(unit_id)
		if unit != null and unit.has_method("release_damage_preview"):
			unit.call("release_damage_preview", 1.0)
	_drag_damage_preview_unit_ids.clear()


func _rendered_unit_node(unit_id: String) -> Control:
	for cell in _cells:
		var cell_data := _cell_data_for_cell(cell)
		if String(cell_data.get("unitId", cell_data.get("unit_id", ""))) != unit_id:
			continue
		if cell.has_method("get_unit_node"):
			return cell.call("get_unit_node") as Control
	return null


func _can_drag_preview_at(target: Vector2i) -> bool:
	if not _is_visible_board_cell(target.x, target.y):
		return false
	var data := _cell_data_at_grid(target)
	var unit_id := String(data.get("unitId", data.get("unit_id", "")))
	return unit_id == "" or target == _drag_origin or unit_id == _drag_unit_id


func _drag_attack_cells_for_target(target: Vector2i) -> Array[Vector2i]:
	if not _can_drag_preview_at(target):
		return []
	var projected: Array[Vector2i] = _preview_presenter.call(
		"action_cells_for_drag",
		_last_snapshot,
		_drag_unit_id,
		target,
		Vector2i(_board_columns, _board_rows)
	)
	return projected


func _drag_action_preview() -> Dictionary:
	var previews := Dictionary(_last_snapshot.get(
		"action_preview_by_unit",
		_last_snapshot.get("actionPreviewByUnit", {})
	))
	if previews.has(_drag_unit_id):
		return Dictionary(previews[_drag_unit_id])
	return {}


func _is_visible_board_cell(x: int, y: int) -> bool:
	return bool(_board_controller.call("contains", Vector2i(_board_columns, _board_rows), x, y))


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


func _set_cell_hovered(grid: Vector2i, value: bool) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	var cell := _cell_at(grid.x, grid.y)
	if cell != null and cell.has_method("set_hovered"):
		cell.call("set_hovered", value)


func _clear_cell_highlight(grid: Vector2i) -> void:
	if not _is_visible_board_cell(grid.x, grid.y):
		return
	var cell := _cell_at(grid.x, grid.y)
	if cell == null:
		return
	if cell.has_method("clear_highlight"):
		cell.call("clear_highlight")


func _clear_all_cell_highlights() -> void:
	_direction_hover_highlight_keys.clear()
	for cell in _cells:
		if cell != null and cell.has_method("clear_highlight"):
			cell.call("clear_highlight")


func _sync_enemy_damage_previews(preserve_active_enemy_previews: bool = false) -> void:
	if _enemy_damage_preview_sync_epoch_msec < 0:
		_enemy_damage_preview_sync_epoch_msec = Time.get_ticks_msec()
	var active_preview_count := 0
	for cell in _cells:
		if cell == null or not cell.visible or not cell.has_method("get_unit_node"):
			continue
		var unit := cell.call("get_unit_node") as Control
		if unit == null or not unit.has_method("start_damage_preview"):
			continue
		var cell_data := _cell_data_for_cell(cell)
		var preview := _incoming_player_damage_preview(cell_data) \
			if _cell_data_is_friendly(cell_data) else _enemy_damage_preview(cell_data)
		if not _damage_preview_is_complete(preview):
			if preserve_active_enemy_previews and not _cell_data_is_friendly(cell_data) \
					and unit.has_method("get_damage_preview_snapshot") \
					and bool(Dictionary(unit.call(
						"get_damage_preview_snapshot"
					)).get("active", false)):
				continue
			unit.call("stop_damage_preview")
			continue
		var current_hp := int(cell_data.get("hp", 0))
		var projected_hp := _preview_int(preview, ["predictedHpTo", "predicted_hp_to", "hpTo", "hp_to"])
		var current_shield := int(cell_data.get("shield", 0))
		var projected_shield := _preview_int(preview, ["predictedShieldTo", "predicted_shield_to", "shieldTo", "shield_to"])
		var predicted_damage := _preview_int(preview, ["predictedDamage", "predicted_damage", "totalDamage", "total_damage", "damage", "threat"])
		active_preview_count += 1
		unit.call(
			"start_damage_preview",
			current_hp,
			projected_hp,
			_enemy_damage_preview_sync_epoch_msec,
			predicted_damage,
			current_shield,
			projected_shield,
			int(cell_data.get("max_hp", cell_data.get("maxHp", current_hp)))
		)
	if active_preview_count == 0:
		_enemy_damage_preview_sync_epoch_msec = -1


func _incoming_player_damage_preview(cell_data: Dictionary) -> Dictionary:
	var unit_id := String(cell_data.get("unitId", cell_data.get("unit_id", "")))
	if unit_id == "":
		return {}
	return Dictionary(_preview_presenter.call("incoming_preview", _last_snapshot, unit_id))


func _incoming_player_drag_damage_preview(cell_data: Dictionary) -> Dictionary:
	return _incoming_player_damage_preview(cell_data)


func _stop_enemy_damage_previews() -> void:
	_enemy_damage_preview_sync_epoch_msec = -1
	for cell in _cells:
		if cell == null or not cell.has_method("get_unit_node"):
			continue
		var unit := cell.call("get_unit_node") as Control
		if unit != null and unit.has_method("stop_damage_preview"):
			unit.call("stop_damage_preview")


func _enemy_damage_preview(cell_data: Dictionary) -> Dictionary:
	if not bool(cell_data.get("action_preview", cell_data.get("actionPreview", false))):
		return {}
	return _enemy_damage_preview_for_actor(cell_data, _selected_unit_id())


func _enemy_damage_preview_for_actor(cell_data: Dictionary, actor_id: String) -> Dictionary:
	if actor_id == "":
		return {}
	return Dictionary(_preview_presenter.call("target_preview", cell_data, actor_id))


func _cell_is_enemy_occupied(grid: Vector2i) -> bool:
	var data := _cell_data_at_grid(grid)
	if String(data.get("unitId", data.get("unit_id", ""))) == "":
		return false
	return not _cell_data_is_friendly(data)


func _cell_allows_attack_highlight(grid: Vector2i) -> bool:
	if not _is_visible_board_cell(grid.x, grid.y):
		return false
	var data := _cell_data_at_grid(grid)
	if String(data.get("unitId", data.get("unit_id", ""))) == "":
		return true
	return not _cell_data_is_friendly(data)


func _cell_data_is_friendly(data: Dictionary) -> bool:
	return String(data.get("side", data.get("unitSide", ""))) in ["player", "ally", "hero_leader", "player_leader"]


func _cell_has_draggable_player_unit(cell: Control) -> bool:
	if cell == null:
		return false
	var data := _cell_data_for_cell(cell)
	var unit_id := String(data.get("unitId", data.get("unit_id", "")))
	if unit_id == "" or _cell_data_is_hero(data):
		return false
	return String(data.get("side", data.get("unitSide", ""))) in ["player", "ally"]


func _cell_data_is_hero(data: Dictionary) -> bool:
	var unit_id := String(data.get("unitId", data.get("unit_id", "")))
	var unit_type := String(data.get("type", data.get("unitType", data.get("unit_type", "")))).to_lower()
	var side := String(data.get("side", data.get("unitSide", "")))
	return (
		unit_type == "hero"
		or unit_id in ["player_hero", "enemy_hero"]
		or side in ["hero_leader", "player_leader", "enemy_leader", "boss"]
	)


func _cell_has_unit(grid: Vector2i) -> bool:
	var data := _cell_data_at_grid(grid)
	return String(data.get("unitId", data.get("unit_id", ""))) != ""


func _cell_has_visible_elements(grid: Vector2i) -> bool:
	var raw_elements = _cell_data_at_grid(grid).get("elements", {})
	if not (raw_elements is Dictionary):
		return false
	for amount in Dictionary(raw_elements).values():
		if int(amount) > 0:
			return true
	return false


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


func _selected_unit_id() -> String:
	var selected_unit_id := String(_last_snapshot.get(
		"selected_unit_id",
		_last_snapshot.get("selectedUnitId", "")
	))
	if selected_unit_id != "":
		return selected_unit_id
	var selected := Dictionary(_last_snapshot.get("selected", {}))
	return String(selected.get("unitId", selected.get("unit_id", "")))


func _selected_slot_index() -> int:
	return int(_last_snapshot.get(
		"selected_action_slot_index",
		_last_snapshot.get("selectedActionSlotIndex", 0)
	))


func _damage_preview_is_complete(preview: Dictionary) -> bool:
	return (
		_has_any_preview_key(preview, ["predictedHpTo", "predicted_hp_to", "hpTo", "hp_to"])
		and _has_any_preview_key(preview, ["predictedShieldTo", "predicted_shield_to", "shieldTo", "shield_to"])
		and _has_any_preview_key(preview, ["predictedDamage", "predicted_damage", "totalDamage", "total_damage", "damage", "threat"])
	)


func _has_any_preview_key(preview: Dictionary, keys: Array) -> bool:
	for key_value in keys:
		if preview.has(String(key_value)):
			return true
	return false


func _preview_int(preview: Dictionary, keys: Array) -> int:
	for key_value in keys:
		var key := String(key_value)
		if preview.has(key):
			return int(preview[key])
	return 0


func _unit_data_by_id(snapshot: Dictionary, unit_id: String) -> Dictionary:
	if unit_id == "":
		return {}
	for value in Array(snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", unit.get("unitId", ""))) == unit_id:
			return unit
	return {}


func _clear_cell_unit_projection(cell: Dictionary) -> void:
	for key in ["unit_id", "unitId", "pet_id", "petId", "unitSide", "side", "unitName", "name"]:
		cell[key] = ""
	cell["hp"] = 0
	cell["shield"] = 0
	cell["atk"] = 0
	cell["leaderId"] = null
	for key in [
		"damage_cap", "damageCap", "incoming_damage_cap", "incomingDamageCap",
		"max_damage_per_hit", "maxDamagePerHit", "buffs",
	]:
		cell.erase(key)
