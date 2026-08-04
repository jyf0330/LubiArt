extends RefCounted

## Pointer/drag transaction for the authored BattleBoard. This controller owns
## only transient input and animation state. It emits semantic requests and
## never mutates Snapshot or gameplay authority.

signal command_requested(command: Dictionary)
signal cell_detail_requested(grid: Vector2i, unit_id: String)

const GameLogScript := preload("res://core/logging/game_log.gd")
const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")

const DRAG_CLICK_THRESHOLD := 12.0
const DROP_SETTLE_DURATION := 0.12
const DROP_RETURN_DURATION := 0.16

var _board: Control = null
var _board_grid: Control = null
var _unit_host: Control = null
var _assets: RefCounted = null
var _preview: RefCounted = null

var _hovered_grid := Vector2i(-1, -1)
var _drag_unit_id := ""
var _drag_origin := Vector2i(-1, -1)
var _drag_preview: Control = null
var _drag_offset := Vector2.ZERO
var _drag_hover_grid := Vector2i(-1, -1)
var _drag_start_mouse_position := Vector2.ZERO
var _drag_has_moved := false
var _drop_settle_active := false
var _drop_settle_preview: Control = null
var _drop_settle_tween: Tween = null
var _drop_settle_unit_id := ""
var _drop_settle_grid := Vector2i(-1, -1)
var _suppress_next_select := false
var _input_locked := false


func configure(
	board: Control,
	board_grid: Control,
	unit_host: Control,
	assets: RefCounted,
	preview: RefCounted
) -> void:
	_board = board
	_board_grid = board_grid
	_unit_host = unit_host
	_assets = assets
	_preview = preview


func set_assets(assets: RefCounted) -> void:
	_assets = assets


func set_input_locked(locked: bool) -> void:
	if _input_locked != locked:
		GameLogScript.debug("表现/输入锁", "战斗棋盘输入状态变化", {"状态": "锁定" if locked else "解锁"})
	_input_locked = locked
	if locked:
		_set_cursor_grabbing(false)
		_set_cursor_pet_hover(false)
	else:
		_refresh_cursor_hover_state()


func hovered_grid() -> Vector2i:
	return _hovered_grid


func process_drag() -> void:
	_update_drag_preview()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and _drag_unit_id == "":
		_refresh_cursor_hover_state()
	if _input_locked:
		return false
	if event is InputEventMouseMotion and _drag_unit_id != "":
		var motion := event as InputEventMouseMotion
		var board_local := _board_grid.get_global_transform_with_canvas().affine_inverse() * motion.position
		_update_drag_preview_at_board_position(board_local)
		return false
	if _drag_unit_id == "" or not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
		return false
	var board_local := _board_grid.get_global_transform_with_canvas().affine_inverse() * mouse_event.position
	_finish_unit_drag(_grid_from_board_position(board_local))
	return true


func on_cell_selected(grid: Vector2i) -> void:
	if _input_locked:
		return
	if _suppress_next_select:
		_suppress_next_select = false
		return
	if _cell_has_player_unit(grid):
		_select_player_unit_and_request_detail(grid)
		return
	if _cell_has_unit(grid) or _cell_has_visible_elements(grid):
		_request_cell_detail(grid)
		return
	cell_detail_requested.emit(Vector2i(-1, -1), "")
	command_requested.emit({"type": "SELECT_CELL", "x": grid.x, "y": grid.y, "cell": {"x": grid.x, "y": grid.y}})


func on_cell_pressed(grid: Vector2i) -> void:
	if not _input_locked:
		_start_unit_drag(grid)


func on_cell_released(grid: Vector2i) -> void:
	if not _input_locked and _drag_unit_id != "":
		_finish_unit_drag(grid)


func on_cell_hovered(grid: Vector2i) -> void:
	if _drag_unit_id != "" and _preview != null:
		_preview.call("update_drag", grid, true)
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


func on_cell_unhovered(grid: Vector2i) -> void:
	if _hovered_grid == grid:
		_set_cell_hovered(grid, false)
		_hovered_grid = Vector2i(-1, -1)
	if _drag_unit_id == "":
		_set_cursor_pet_hover(false)


func cancel_for_board_resize() -> void:
	if _drag_unit_id != "":
		_finish_unit_drag(Vector2i(-1, -1))
	_hovered_grid = Vector2i(-1, -1)
	_drag_hover_grid = Vector2i(-1, -1)


func clear_transient_state() -> void:
	if _drag_unit_id != "":
		var preview_node := _take_drag_preview()
		_set_cell_unit_dragging(_drag_origin, false)
		_reset_drag_tracking()
		_free_drop_preview(preview_node)
	if _drop_settle_active:
		if _board != null and _board.is_inside_tree():
			_finish_drop_settle(_drop_settle_preview, _drop_settle_unit_id, _drop_settle_grid)
		else:
			_discard_drop_settle()
	_clear_drag_hover_highlight()
	if _preview != null:
		_preview.call("clear_transient_state")


func restore_after_snapshot() -> void:
	if _drag_unit_id != "":
		var origin_cell := _cell_at(_drag_origin)
		if origin_cell != null and origin_cell.has_method("set_unit_dragging"):
			origin_cell.call("set_unit_dragging", true)
		if _preview != null:
			_preview.call("restore_drag_after_snapshot", _drag_preview)
		if _drag_hover_grid.x >= 0:
			_refresh_drag_hover_highlight(_drag_hover_grid, true)
	_restore_drop_settle_visual_state()


func dispose() -> void:
	_set_cursor_grabbing(false)
	_set_cursor_pet_hover(false)
	_free_drop_preview(_take_drag_preview())
	_discard_drop_settle()
	_drag_unit_id = ""
	_drag_origin = Vector2i(-1, -1)
	_hovered_grid = Vector2i(-1, -1)
	_drag_hover_grid = Vector2i(-1, -1)
	_board = null
	_board_grid = null
	_unit_host = null
	_assets = null
	_preview = null


func _start_unit_drag(grid: Vector2i) -> void:
	if _drop_settle_active:
		_finish_drop_settle(_drop_settle_preview, _drop_settle_unit_id, _drop_settle_grid)
	var cell := _cell_at(grid)
	if not _cell_has_draggable_player_unit(cell):
		return
	var unit := cell.call("get_unit_node") as Control
	if unit == null or not unit.has_method("get_unit_id"):
		return
	cell_detail_requested.emit(Vector2i(-1, -1), "")
	_drag_unit_id = String(unit.call("get_unit_id"))
	_set_cursor_pet_hover(false)
	_set_cursor_grabbing(true)
	_board.set_process(true)
	_drag_origin = grid
	_drag_offset = _board_grid.get_local_mouse_position() - _cell_origin(grid)
	_drag_start_mouse_position = _board_grid.get_local_mouse_position()
	_drag_has_moved = false
	_set_cell_unit_dragging(grid, true)
	_select_player_unit(grid)
	_create_drag_preview(unit)
	if _preview != null:
		_preview.call("begin_drag", _drag_unit_id, _drag_origin, _drag_preview)
	_update_drag_preview()


func _finish_unit_drag(target: Vector2i) -> void:
	if _drag_unit_id == "":
		return
	var dragged_unit_id := _drag_unit_id
	var origin := _drag_origin
	var was_dragged := _drag_has_moved
	var can_drop := _can_drop_dragged_unit_at(target)
	var settle_preview := _take_drag_preview()
	_board.call("_clear_cell_highlight", origin)
	if _preview != null:
		_preview.call("finish_drag", true)
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
	var settled_grid := origin
	if can_drop and bool(_board.call("_apply_local_unit_drop", dragged_unit_id, origin, target)):
		command_requested.emit({
			"type": "MOVE_HERO",
			"unitId": dragged_unit_id,
			"x": target.x,
			"y": target.y,
			"cell": {"x": target.x, "y": target.y}
		})
		settled_grid = target
	_suppress_next_select = true
	_start_drop_settle(settle_preview, dragged_unit_id, origin, target, settled_grid)
	_refresh_cursor_hover_at(target)


func _can_drop_dragged_unit_at(target: Vector2i) -> bool:
	if not _is_visible_board_cell(target) or target == _drag_origin:
		return false
	return not _cell_has_unit(target)


func _take_drag_preview() -> Control:
	var preview_node := _drag_preview
	_drag_preview = null
	return preview_node


func _reset_drag_tracking() -> void:
	_drag_unit_id = ""
	_board.set_process(false)
	_drag_origin = Vector2i(-1, -1)
	_drag_start_mouse_position = Vector2.ZERO
	_drag_has_moved = false


func _start_drop_settle(
	preview_node: Control,
	unit_id: String,
	origin: Vector2i,
	requested: Vector2i,
	settled: Vector2i
) -> void:
	var is_return := settled == origin and requested != origin
	var duration := DROP_RETURN_DURATION if is_return else DROP_SETTLE_DURATION
	if preview_node == null or not is_instance_valid(preview_node):
		_set_cell_unit_dragging(settled, false)
		_sync_enemy_damage_previews(true)
		return
	_drop_settle_active = true
	_drop_settle_preview = preview_node
	_drop_settle_unit_id = unit_id
	_drop_settle_grid = settled
	_set_cell_unit_dragging(settled, true)
	preview_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_node.z_as_relative = false
	preview_node.z_index = 180
	preview_node.modulate.a = 0.94
	_drop_settle_tween = _board.create_tween()
	_drop_settle_tween.set_trans(Tween.TRANS_QUINT)
	_drop_settle_tween.set_ease(Tween.EASE_OUT)
	_drop_settle_tween.tween_property(preview_node, "position", _cell_origin(settled), duration)
	_drop_settle_tween.parallel().tween_property(preview_node, "modulate:a", 1.0, duration)
	_drop_settle_tween.finished.connect(
		Callable(self, "_finish_drop_settle").bind(preview_node, unit_id, settled)
	)


func _finish_drop_settle(preview_node: Control, _unit_id: String, settled: Vector2i) -> void:
	if not _drop_settle_active or _drop_settle_preview != preview_node:
		return
	_discard_drop_settle()
	_set_cell_unit_dragging(settled, false)
	_sync_enemy_damage_previews(true)


func _discard_drop_settle() -> void:
	if _drop_settle_tween != null and _drop_settle_tween.is_valid():
		_drop_settle_tween.kill()
	_drop_settle_tween = null
	if _drop_settle_preview != null and is_instance_valid(_drop_settle_preview):
		_drop_settle_preview.visible = false
		_drop_settle_preview.queue_free()
	_drop_settle_preview = null
	_drop_settle_active = false
	_drop_settle_unit_id = ""
	_drop_settle_grid = Vector2i(-1, -1)


func _restore_drop_settle_visual_state() -> void:
	if not _drop_settle_active or _drop_settle_unit_id == "":
		return
	var current_grid := _board.call("_rendered_grid_for_unit_id", _drop_settle_unit_id) as Vector2i
	if current_grid.x >= 0 and current_grid.y >= 0:
		_drop_settle_grid = current_grid
	_set_cell_unit_dragging(_drop_settle_grid, true)


func _request_cell_detail(grid: Vector2i) -> void:
	if not _is_visible_board_cell(grid):
		return
	var data := _cell_data_at_grid(grid)
	var x := int(data.get("x", data.get("c", grid.x)))
	var y := int(data.get("y", data.get("r", grid.y)))
	cell_detail_requested.emit(
		Vector2i(x, y),
		String(data.get("unitId", data.get("unit_id", "")))
	)
	command_requested.emit({"type": "GET_CELL_DETAIL", "x": x, "y": y, "cell": {"x": x, "y": y}})


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
	var preview_node := BattleUnitScene.instantiate() as Control
	if preview_node == null:
		return
	preview_node.name = "BattleUnitDragPreview"
	preview_node.position = _unit_host.get_local_mouse_position() - _drag_offset
	preview_node.size = _board.call("_presentation_cell_size") as Vector2
	preview_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_host.add_child(preview_node)
	if preview_node.has_method("set_unit_data"):
		preview_node.call("set_unit_data", Dictionary(raw_data).duplicate(true), String(unit.get("side")), _assets)
	if preview_node.has_method("set_dragging"):
		preview_node.call("set_dragging", false)
	preview_node.z_as_relative = false
	preview_node.z_index = 180
	preview_node.modulate.a = 0.94
	_unit_host.move_child(preview_node, _unit_host.get_child_count() - 1)
	_drag_preview = preview_node


func _update_drag_preview() -> void:
	if _drag_unit_id == "" or _drag_preview == null or not is_instance_valid(_drag_preview):
		return
	_update_drag_preview_at_board_position(_board_grid.get_local_mouse_position())


func _update_drag_preview_at_board_position(local_mouse: Vector2) -> void:
	if _drag_unit_id == "" or _drag_preview == null or not is_instance_valid(_drag_preview):
		return
	_drag_preview.position = local_mouse - _drag_offset
	if local_mouse.distance_to(_drag_start_mouse_position) >= DRAG_CLICK_THRESHOLD:
		_drag_has_moved = true
	var target := _grid_from_board_position(local_mouse)
	if target != _drag_origin:
		_drag_has_moved = true
	if _preview != null:
		_preview.call("update_drag", target)
	_refresh_drag_hover_highlight(target)


func _clear_drag_preview() -> void:
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null


func _refresh_drag_hover_highlight(target: Vector2i, force: bool = false) -> void:
	if _drag_unit_id == "":
		return
	if not force and target == _drag_hover_grid:
		return
	if _drag_hover_grid.x >= 0 and _drag_hover_grid.y >= 0:
		_set_cell_hovered(_drag_hover_grid, false)
	_drag_hover_grid = Vector2i(-1, -1)
	if not _is_visible_board_cell(target) or not _can_drag_preview_at(target):
		return
	_drag_hover_grid = target
	_set_cell_hovered(target, true)


func _clear_drag_hover_highlight() -> void:
	if _hovered_grid.x >= 0 and _hovered_grid.y >= 0:
		_set_cell_hovered(_hovered_grid, false)
	_hovered_grid = Vector2i(-1, -1)
	if _drag_hover_grid.x >= 0 and _drag_hover_grid.y >= 0:
		_set_cell_hovered(_drag_hover_grid, false)
	_drag_hover_grid = Vector2i(-1, -1)


func _cell_has_player_unit(grid: Vector2i) -> bool:
	var cell := _cell_at(grid)
	return cell != null and cell.has_method("has_player_unit") and bool(cell.call("has_player_unit"))


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


func _mouse_is_over_draggable_pet(cell: Control) -> bool:
	if not _cell_has_draggable_player_unit(cell):
		return false
	var unit := cell.call("get_unit_node") as Control
	if unit == null:
		return false
	var mouse_position := _board.get_viewport().get_mouse_position()
	if unit.has_method("contains_art_point"):
		return bool(unit.call("contains_art_point", mouse_position))
	return unit.get_global_rect().has_point(mouse_position)


func _refresh_cursor_hover_state() -> void:
	if _input_locked or _drag_unit_id != "" or _hovered_grid.x < 0 or _hovered_grid.y < 0:
		_set_cursor_pet_hover(false)
		return
	_set_cursor_pet_hover(_mouse_is_over_draggable_pet(_cell_at(_hovered_grid)))


func _refresh_cursor_hover_at(grid: Vector2i) -> void:
	if _input_locked or _drag_unit_id != "":
		_set_cursor_pet_hover(false)
		return
	_set_cursor_pet_hover(_mouse_is_over_draggable_pet(_cell_at(grid)))


func _game_cursor() -> Node:
	if _board == null or not _board.is_inside_tree():
		return null
	return _board.get_tree().get_first_node_in_group(&"game_cursor")


func _set_cursor_pet_hover(active: bool) -> void:
	var cursor := _game_cursor()
	if cursor != null and cursor.has_method("set_pet_hover"):
		cursor.call("set_pet_hover", active)


func _set_cursor_grabbing(active: bool) -> void:
	var cursor := _game_cursor()
	if cursor != null and cursor.has_method("set_grabbing"):
		cursor.call("set_grabbing", active)


func _sync_enemy_damage_previews(preserve_active_enemy_previews: bool = false) -> void:
	if _preview != null:
		_preview.call("sync_enemy_damage_previews", preserve_active_enemy_previews)


func _can_drag_preview_at(target: Vector2i) -> bool:
	return bool(_preview.call("can_drag_preview_at", target)) if _preview != null else false


func _set_cell_unit_dragging(grid: Vector2i, is_dragging: bool) -> void:
	if not _is_visible_board_cell(grid):
		return
	var cell := _cell_at(grid)
	if cell != null and cell.has_method("set_unit_dragging"):
		cell.call("set_unit_dragging", is_dragging)


func _set_cell_hovered(grid: Vector2i, value: bool) -> void:
	if _board != null:
		_board.call("_set_cell_hovered", grid, value)


func _free_drop_preview(preview_node: Control) -> void:
	if preview_node != null and is_instance_valid(preview_node):
		preview_node.queue_free()


func _cell_at(grid: Vector2i) -> Control:
	return _board.call("_cell_at", grid.x, grid.y) as Control if _board != null else null


func _cell_data_at_grid(grid: Vector2i) -> Dictionary:
	return Dictionary(_board.call("_cell_data_at_grid", grid)) if _board != null else {}


func _cell_data_for_cell(cell: Node) -> Dictionary:
	return Dictionary(_board.call("_cell_data_for_cell", cell)) if _board != null else {}


func _cell_origin(grid: Vector2i) -> Vector2:
	return _board.call("_cell_origin", grid.x, grid.y) as Vector2 if _board != null else Vector2.ZERO


func _grid_from_board_position(local_position: Vector2) -> Vector2i:
	return _board.call("_grid_from_board_position", local_position) as Vector2i if _board != null else Vector2i(-1, -1)


func _is_visible_board_cell(grid: Vector2i) -> bool:
	return bool(_board.call("_is_visible_board_cell", grid.x, grid.y)) if _board != null else false
