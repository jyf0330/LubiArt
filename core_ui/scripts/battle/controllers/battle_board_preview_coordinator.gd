extends RefCounted

## Owns transient board previews already described by a public Snapshot.
## It may manipulate presentation nodes, but never calculates combat rules or
## mutates the authoritative Snapshot.

var _board: Control = null
var _presenter: RefCounted = null
var _last_snapshot: Dictionary = {}
var _input_locked := false

var _drag_unit_id := ""
var _drag_origin := Vector2i(-1, -1)
var _drag_preview: Control = null
var _drag_preview_target := Vector2i(-1, -1)
var _drag_attack_highlight_keys: Array[String] = []
var _drag_attack_marker_keys: Array[String] = []
var _drag_damage_preview_unit_ids: Array[String] = []
var _direction_hover_highlight_keys: Array[String] = []
var _enemy_damage_preview_sync_epoch_msec := -1


func configure(board: Control, presenter: RefCounted) -> void:
	_board = board
	_presenter = presenter


func set_input_locked(locked: bool) -> void:
	_input_locked = locked


func render_snapshot(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot.duplicate(true)
	_clear_all_cell_highlights()
	_apply_selected_action_block_ranges()
	sync_enemy_damage_previews()


func show_direction_preview(unit_id: String, direction: String) -> void:
	if unit_id == "" or direction == "":
		_clear_direction_hover_preview()
		return
	_show_direction_hover_preview(unit_id, direction)


func begin_drag(unit_id: String, origin: Vector2i, preview: Control) -> void:
	_drag_unit_id = unit_id
	_drag_origin = origin
	_drag_preview = preview
	_drag_preview_target = Vector2i(-1, -1)
	_stop_enemy_damage_previews()


func update_drag(target: Vector2i, force: bool = false) -> void:
	_refresh_drag_attack_preview(target, force)


func finish_drag(release_damage_previews: bool = false) -> void:
	if release_damage_previews:
		_release_drag_damage_previews()
	_clear_drag_attack_preview(not release_damage_previews)
	_drag_unit_id = ""
	_drag_origin = Vector2i(-1, -1)
	_drag_preview = null
	_drag_preview_target = Vector2i(-1, -1)


func clear_transient_state() -> void:
	finish_drag(false)
	_clear_direction_hover_preview()
	_stop_enemy_damage_previews()


func restore_drag_after_snapshot(preview: Control) -> void:
	if _drag_unit_id == "":
		return
	_drag_preview = preview
	_stop_enemy_damage_previews()
	if _drag_preview_target.x >= 0:
		_refresh_drag_attack_preview(_drag_preview_target, true)


func can_drag_preview_at(target: Vector2i) -> bool:
	if not _is_visible_board_cell(target):
		return false
	var data := _cell_data_at_grid(target)
	var unit_id := String(data.get("unitId", data.get("unit_id", "")))
	return unit_id == "" or target == _drag_origin or unit_id == _drag_unit_id


func sync_enemy_damage_previews(preserve_active_enemy_previews: bool = false) -> void:
	if _board == null:
		return
	if _enemy_damage_preview_sync_epoch_msec < 0:
		_enemy_damage_preview_sync_epoch_msec = Time.get_ticks_msec()
	var active_preview_count := 0
	for cell_value in _presentation_cells():
		var cell := cell_value as Control
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


func _apply_selected_action_block_ranges() -> void:
	for cell_value in _presentation_cells():
		var cell := cell_value as Control
		if cell == null or not cell.has_method("get_unit_node"):
			continue
		var unit_node := cell.call("get_unit_node") as Control
		if unit_node != null and unit_node.has_method("hide_action_block_attack_ranges"):
			unit_node.call("hide_action_block_attack_ranges")
	if String(_last_snapshot.get("phase", "")) != "battle":
		return
	var selected_unit_id := _selected_unit_id()
	if selected_unit_id == "":
		return
	var ranges_by_unit := Dictionary(_last_snapshot.get(
		"action_block_ranges_by_unit",
		_last_snapshot.get("actionBlockRangesByUnit", {})
	))
	if not ranges_by_unit.has(selected_unit_id):
		return
	var selected_unit := _unit_data_by_id(selected_unit_id)
	var selected_grid := Vector2i(
		int(selected_unit.get("x", -1)),
		int(selected_unit.get("y", -1))
	)
	if not _is_visible_board_cell(selected_grid):
		return
	var selected_cell := _cell_at(selected_grid)
	if selected_cell == null or not selected_cell.has_method("get_unit_node"):
		return
	var selected_unit_node := selected_cell.call("get_unit_node") as Control
	if selected_unit_node != null and selected_unit_node.has_method("show_action_block_attack_ranges"):
		selected_unit_node.call(
			"show_action_block_attack_ranges",
			Array(ranges_by_unit[selected_unit_id]),
			_board.call("_presentation_cell_size") as Vector2,
			selected_grid,
			(_board.get_node("CellHost") as Control).size,
			(_board.get_node("CellHost") as Control).global_position,
			Dictionary(_board.call("_attack_range_geometry"))
		)


func _refresh_drag_attack_preview(target: Vector2i, force: bool = false) -> void:
	if _drag_unit_id == "":
		return
	if not force and target == _drag_preview_target:
		return
	_clear_drag_attack_preview()
	_drag_preview_target = target
	_refresh_drag_incoming_damage_preview(target)
	if not _is_visible_board_cell(target):
		return
	_show_drag_attack_cells(_drag_attack_cells_for_target(target))


func _refresh_drag_incoming_damage_preview(target: Vector2i) -> void:
	if _drag_preview == null or not is_instance_valid(_drag_preview) \
			or not _drag_preview.has_method("start_damage_preview"):
		return
	if not can_drag_preview_at(target):
		if _drag_preview.has_method("stop_damage_preview"):
			_drag_preview.call("stop_damage_preview")
		return
	var origin_cell := _cell_at(_drag_origin)
	if origin_cell == null:
		return
	var cell_data := _cell_data_for_cell(origin_cell)
	var preview := _incoming_player_damage_preview(cell_data)
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
		var grid := _grid_from_key(key)
		if grid.x >= 0:
			_board.call("_clear_cell_highlight", grid)
	_drag_attack_highlight_keys.clear()
	for key in _drag_attack_marker_keys:
		var grid := _grid_from_key(key)
		if grid.x >= 0:
			_board.call("_clear_cell_attack_order_marker", grid)
	_drag_attack_marker_keys.clear()


func _clear_direction_hover_preview() -> void:
	for key in _direction_hover_highlight_keys:
		var grid := _grid_from_key(key)
		if grid.x < 0:
			continue
		var cell := _cell_at(grid)
		if cell != null and cell.has_method("set_attack_highlight_blinking"):
			cell.call("set_attack_highlight_blinking", false)
		if not _drag_attack_highlight_keys.has(key):
			_board.call("_clear_cell_highlight", grid)
	_direction_hover_highlight_keys.clear()


func _show_direction_hover_preview(unit_id: String, direction: String) -> void:
	_clear_direction_hover_preview()
	if _drag_unit_id != "" or _input_locked or _presenter == null:
		return
	var projected: Array[Vector2i] = _presenter.call(
		"direction_cells",
		_last_snapshot,
		unit_id,
		direction,
		_board.call("board_dimensions") as Vector2i
	)
	for grid in projected:
		if not _cell_allows_attack_highlight(grid):
			continue
		_board.call("_set_cell_highlight", grid, "attack")
		var cell := _cell_at(grid)
		if cell != null and cell.has_method("set_attack_highlight_blinking"):
			cell.call("set_attack_highlight_blinking", true)
		_direction_hover_highlight_keys.append(String(_board.call("_cell_key", grid)))


func _show_drag_attack_cells(cells: Array[Vector2i]) -> void:
	var enemy_attack_cells: Array[Vector2i] = []
	for grid in cells:
		if not _cell_allows_attack_highlight(grid):
			continue
		_board.call("_set_cell_highlight", grid, "attack")
		_drag_attack_highlight_keys.append(String(_board.call("_cell_key", grid)))
		if _cell_is_enemy_occupied(grid):
			enemy_attack_cells.append(grid)
	if enemy_attack_cells.is_empty():
		return
	_show_drag_damage_previews(enemy_attack_cells)
	var marker_grid := enemy_attack_cells[enemy_attack_cells.size() - 1]
	var preview := _drag_action_preview()
	_board.call("_set_cell_attack_order_marker", marker_grid, int(preview.get("slotIndex", _selected_slot_index())) + 1)
	_drag_attack_marker_keys.append(String(_board.call("_cell_key", marker_grid)))


func _show_drag_damage_previews(enemy_cells: Array[Vector2i]) -> void:
	for grid in enemy_cells:
		var cell := _cell_at(grid)
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


func _drag_attack_cells_for_target(target: Vector2i) -> Array[Vector2i]:
	if not can_drag_preview_at(target) or _presenter == null:
		return []
	var projected: Array[Vector2i] = _presenter.call(
		"action_cells_for_drag",
		_last_snapshot,
		_drag_unit_id,
		target,
		_board.call("board_dimensions") as Vector2i
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


func _stop_enemy_damage_previews() -> void:
	_enemy_damage_preview_sync_epoch_msec = -1
	for cell_value in _presentation_cells():
		var cell := cell_value as Control
		if cell == null or not cell.has_method("get_unit_node"):
			continue
		var unit := cell.call("get_unit_node") as Control
		if unit != null and unit.has_method("stop_damage_preview"):
			unit.call("stop_damage_preview")


func _clear_all_cell_highlights() -> void:
	_direction_hover_highlight_keys.clear()
	for cell_value in _presentation_cells():
		var cell := cell_value as Control
		if cell != null and cell.has_method("clear_highlight"):
			cell.call("clear_highlight")


func _incoming_player_damage_preview(cell_data: Dictionary) -> Dictionary:
	var unit_id := String(cell_data.get("unitId", cell_data.get("unit_id", "")))
	if unit_id == "" or _presenter == null:
		return {}
	return Dictionary(_presenter.call("incoming_preview", _last_snapshot, unit_id))


func _enemy_damage_preview(cell_data: Dictionary) -> Dictionary:
	if not bool(cell_data.get("action_preview", cell_data.get("actionPreview", false))):
		return {}
	return _enemy_damage_preview_for_actor(cell_data, _selected_unit_id())


func _enemy_damage_preview_for_actor(cell_data: Dictionary, actor_id: String) -> Dictionary:
	if actor_id == "" or _presenter == null:
		return {}
	return Dictionary(_presenter.call("target_preview", cell_data, actor_id))


func _cell_is_enemy_occupied(grid: Vector2i) -> bool:
	var data := _cell_data_at_grid(grid)
	if String(data.get("unitId", data.get("unit_id", ""))) == "":
		return false
	return not _cell_data_is_friendly(data)


func _cell_allows_attack_highlight(grid: Vector2i) -> bool:
	if not _is_visible_board_cell(grid):
		return false
	var data := _cell_data_at_grid(grid)
	if String(data.get("unitId", data.get("unit_id", ""))) == "":
		return true
	return not _cell_data_is_friendly(data)


func _cell_data_is_friendly(data: Dictionary) -> bool:
	return String(data.get("side", data.get("unitSide", ""))) in ["player", "ally", "hero_leader", "player_leader"]


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


func _unit_data_by_id(unit_id: String) -> Dictionary:
	if unit_id == "":
		return {}
	for value in Array(_last_snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", unit.get("unitId", ""))) == unit_id:
			return unit
	return {}


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


func _presentation_cells() -> Array:
	return Array(_board.call("_presentation_cells")) if _board != null else []


func _cell_at(grid: Vector2i) -> Control:
	return _board.call("_cell_at", grid.x, grid.y) as Control if _board != null else null


func _cell_data_at_grid(grid: Vector2i) -> Dictionary:
	return Dictionary(_board.call("_cell_data_at_grid", grid)) if _board != null else {}


func _cell_data_for_cell(cell: Node) -> Dictionary:
	return Dictionary(_board.call("_cell_data_for_cell", cell)) if _board != null else {}


func _rendered_unit_node(unit_id: String) -> Control:
	return _board.call("_rendered_unit_node", unit_id) as Control if _board != null else null


func _is_visible_board_cell(grid: Vector2i) -> bool:
	return bool(_board.call("_is_visible_board_cell", grid.x, grid.y)) if _board != null else false


func _grid_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))
