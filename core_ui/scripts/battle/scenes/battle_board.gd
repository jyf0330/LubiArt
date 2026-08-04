extends Control

## Authored Board responsibility root. It owns board geometry, cell/unit pools
## and Snapshot projection. Independent pointer and preview lifecycles live in
## presentation-only collaborators.

signal command_requested(command: Dictionary)
signal cell_detail_requested(grid: Vector2i, unit_id: String)

const BattleBoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const BattleBoardControllerScript := preload("res://core_ui/scripts/battle/controllers/battle_board_controller.gd")
const BattleBoardLayoutScript := preload("res://core_ui/scripts/battle/controllers/battle_board_layout.gd")
const BattleBoardDragInteractionScript := preload("res://core_ui/scripts/battle/controllers/battle_board_drag_interaction.gd")
const BattleBoardPreviewCoordinatorScript := preload("res://core_ui/scripts/battle/controllers/battle_board_preview_coordinator.gd")
const BattlePreviewPresenterScript := preload("res://core_ui/scripts/battle/controllers/battle_preview_presenter.gd")
const BattleCellScene := preload("res://art/prefabs/terrain/terrain.tscn")
const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")

const DEFAULT_BOARD_COLUMNS := BattleBoardDimensionsScript.DEFAULT_WIDTH
const DEFAULT_BOARD_ROWS := BattleBoardDimensionsScript.DEFAULT_HEIGHT
const CELL_GAP := Vector2.ZERO

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
var _last_rendered_cell_count := 0
var _board_controller := BattleBoardControllerScript.new()
var _board_layout := BattleBoardLayoutScript.new()
var _preview_coordinator := BattleBoardPreviewCoordinatorScript.new()
var _drag_interaction := BattleBoardDragInteractionScript.new()
var _unit_nodes_by_id := {}
var _unit_pool: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	set_process(false)
	_preview_coordinator.call("configure", self, BattlePreviewPresenterScript.new())
	_drag_interaction.call("configure", self, board_grid, unit_host, _assets, _preview_coordinator)
	_drag_interaction.command_requested.connect(_on_interaction_command_requested)
	_drag_interaction.cell_detail_requested.connect(_on_interaction_cell_detail_requested)
	_build_board()


func configure(assets: RefCounted) -> void:
	_assets = assets
	_drag_interaction.call("set_assets", assets)


func set_input_locked(locked: bool) -> void:
	_drag_interaction.call("set_input_locked", locked)
	_preview_coordinator.call("set_input_locked", locked)


func show_direction_preview(unit_id: String, direction: String) -> void:
	_preview_coordinator.call("show_direction_preview", unit_id, direction)


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
	_drag_interaction.call("clear_transient_state")


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
	_drag_interaction.call("dispose")


func _process(_delta: float) -> void:
	_drag_interaction.call("process_drag")


func _input(event: InputEvent) -> void:
	if bool(_drag_interaction.call("handle_input", event)):
		get_viewport().set_input_as_handled()


func render_snapshot(snapshot: Dictionary, cells: Array, pending_reset_ids: Dictionary = {}) -> void:
	_last_snapshot = snapshot.duplicate(true)
	_render_battle_background(snapshot)
	_missing_mappings = {}
	var board_data := Dictionary(snapshot.get("board", {}))
	_set_board_dimensions(BattleBoardDimensionsScript.from_board(board_data, Vector2i(_board_columns, _board_rows)))
	_ensure_board()
	_last_rendered_cell_count = 0
	_render_board_cells(cells, pending_reset_ids)
	_preview_coordinator.call("render_snapshot", _last_snapshot)
	_drag_interaction.call("restore_after_snapshot")


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
			cell.call("set_hovered", (_drag_interaction.call("hovered_grid") as Vector2i) == Vector2i(x, y))
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
	_drag_interaction.call("cancel_for_board_resize")
	_board_columns = normalized.x
	_board_rows = normalized.y
	_build_board()


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
	_drag_interaction.call("on_cell_selected", Vector2i(x, y))


func _on_cell_pressed(x: int, y: int) -> void:
	_drag_interaction.call("on_cell_pressed", Vector2i(x, y))


func _on_cell_released(x: int, y: int) -> void:
	_drag_interaction.call("on_cell_released", Vector2i(x, y))


func _on_cell_hovered(x: int, y: int) -> void:
	_drag_interaction.call("on_cell_hovered", Vector2i(x, y))


func _on_cell_unhovered(x: int, y: int) -> void:
	_drag_interaction.call("on_cell_unhovered", Vector2i(x, y))


func _on_interaction_command_requested(command: Dictionary) -> void:
	command_requested.emit(command.duplicate(true))


func _on_interaction_cell_detail_requested(grid: Vector2i, unit_id: String) -> void:
	cell_detail_requested.emit(grid, unit_id)


func _apply_local_unit_drop(unit_id: String, origin: Vector2i, target: Vector2i) -> bool:
	var origin_cell := _cell_at(origin.x, origin.y)
	var target_cell := _cell_at(target.x, target.y)
	var target_data := _cell_data_for_cell(target_cell)
	if origin_cell == null or target_cell == null \
			or String(target_data.get("unitId", target_data.get("unit_id", ""))) != "":
		return false
	var origin_data := _cell_data_for_cell(origin_cell).duplicate(true)
	target_data = target_data.duplicate(true)
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



func _rendered_grid_for_unit_id(unit_id: String) -> Vector2i:
	for cell in _cells:
		var data := _cell_data_for_cell(cell)
		if String(data.get("unitId", data.get("unit_id", ""))) == unit_id:
			return cell.call("get_grid_position") as Vector2i
	return Vector2i(-1, -1)



func _rendered_unit_node(unit_id: String) -> Control:
	for cell in _cells:
		var cell_data := _cell_data_for_cell(cell)
		if String(cell_data.get("unitId", cell_data.get("unit_id", ""))) != unit_id:
			continue
		if cell.has_method("get_unit_node"):
			return cell.call("get_unit_node") as Control
	return null



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


func _presentation_cells() -> Array[Control]:
	return _cells


func _presentation_cell_size() -> Vector2:
	return _cell_size



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
