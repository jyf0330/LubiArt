extends RefCounted

## Test-only observer/driver for BattleArtScene. Production code never preloads
## this helper; it uses authored nodes, public owner APIs and real cell signals.

const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const BattlePreviewPresenterScript := preload("res://core_ui/scripts/battle/controllers/battle_preview_presenter.gd")

var _scene: Control = null
var _board: Control = null
var _hud: Control = null
var _overlay: Control = null
var _vfx: Control = null
var _last_command: Dictionary = {}
var _round_banner_observed := false
var _active_drag_origin := Vector2i(-1, -1)
var _active_drag_target := Vector2i(-1, -1)
var _drag_pointer_offset := Vector2.ZERO
var _preview_presenter := BattlePreviewPresenterScript.new()


func _init(battle_scene: Control) -> void:
	_scene = battle_scene
	if _scene == null:
		return
	_board = _scene.get_node_or_null("Board") as Control
	_hud = _scene.get_node_or_null("Hud") as Control
	_overlay = _scene.get_node_or_null("OverlayHost") as Control
	_vfx = _scene.get_node_or_null("Board/VfxHost") as Control
	if _scene.has_signal("command_requested"):
		_scene.connect("command_requested", Callable(self, "_on_command_requested"))
	if _vfx != null:
		_vfx.child_entered_tree.connect(_on_vfx_child_entered)
		for child in _vfx.get_children():
			_on_vfx_child_entered(child)


func is_ready() -> bool:
	return _scene != null and _board != null and _hud != null and _overlay != null and _vfx != null


func board_summary() -> Dictionary:
	if _board == null:
		return {}
	var dimensions := Vector2i.ZERO
	if _board.has_method("board_dimensions"):
		dimensions = _board.call("board_dimensions") as Vector2i
	var cell_host := _board.get_node_or_null("CellHost") as Control
	var active_count := 0
	var pool_count := 0
	var cell_size := Vector2.ZERO
	if cell_host != null:
		pool_count = cell_host.get_child_count()
		for child in cell_host.get_children():
			if child is Control and child.visible:
				active_count += 1
				if cell_size == Vector2.ZERO:
					cell_size = (child as Control).size
	return {
		"width": dimensions.x,
		"height": dimensions.y,
		"activeCellCount": active_count,
		"poolCellCount": pool_count,
		"cellSize": cell_size,
	}


func rendered_cell_count() -> int:
	return int(_board.call("rendered_cell_count")) \
		if _board != null and _board.has_method("rendered_cell_count") else 0


func cell_at(grid: Vector2i) -> Control:
	if _board == null:
		return null
	var cell_host := _board.get_node_or_null("CellHost")
	if cell_host == null:
		return null
	for child in cell_host.get_children():
		if child is Control and child.visible and child.has_method("get_grid_position") \
				and (child.call("get_grid_position") as Vector2i) == grid:
			return child as Control
	return null


func cell_summary(grid: Vector2i) -> Dictionary:
	var cell := cell_at(grid)
	if cell == null:
		return {}
	var raw_data = cell.get("cell_data")
	var data := Dictionary(raw_data).duplicate(true) if raw_data is Dictionary else {}
	var unit := cell.call("get_unit_node") as Control if cell.has_method("get_unit_node") else null
	return {
		"grid": {"x": grid.x, "y": grid.y},
		"data": data,
		"unitVisible": unit != null and unit.visible,
		"hoverVisible": bool(cell.call("is_hover_highlight_visible")) if cell.has_method("is_hover_highlight_visible") else false,
		"attackBlinking": bool(cell.call("is_attack_highlight_blinking")) if cell.has_method("is_attack_highlight_blinking") else false,
	}


func required_asset_manifest_available() -> bool:
	var assets := BattleAssetRegistryScript.new()
	return assets.has_method("manifest_has_required_assets") \
		and bool(assets.call("manifest_has_required_assets"))


func primary_buttons_enabled() -> bool:
	if _hud == null:
		return false
	var auto_button := _hud.get_node_or_null("BattlePrimaryActions/AutoArrangeButton") as BaseButton
	var begin_button := _hud.get_node_or_null("BattlePrimaryActions/BeginTurnButton") as BaseButton
	return auto_button != null and begin_button != null \
		and not auto_button.disabled and not begin_button.disabled


func initial_round_banner_observed() -> bool:
	return _round_banner_observed


func spawn_prefab_samples() -> Dictionary:
	if _vfx != null and _vfx.has_method("debug_spawn_prefab_samples"):
		return Dictionary(_vfx.call("debug_spawn_prefab_samples"))
	return {}


func open_first_pet_detail() -> Dictionary:
	var fallback := {}
	for cell in _visible_cells():
		var data := _cell_data(cell)
		var unit_id := String(data.get("unitId", data.get("unit_id", "")))
		if unit_id == "":
			continue
		var grid := cell.call("get_grid_position") as Vector2i
		var row := {
			"opened": true,
			"unitId": unit_id,
			"name": String(data.get("unitName", data.get("name", ""))),
			"grid": {"x": grid.x, "y": grid.y},
		}
		if fallback.is_empty():
			fallback = row
		if String(data.get("side", data.get("unitSide", ""))) in ["player", "ally", "hero", "hero_leader", "player_leader"]:
			cell.emit_signal("cell_selected", grid.x, grid.y)
			return row
	if not fallback.is_empty():
		var grid_value := Dictionary(fallback["grid"])
		var grid := Vector2i(int(grid_value["x"]), int(grid_value["y"]))
		var cell := cell_at(grid)
		cell.emit_signal("cell_selected", grid.x, grid.y)
		return fallback
	return {"opened": false}


func open_first_element_detail() -> Dictionary:
	for cell in _visible_cells():
		var data := _cell_data(cell)
		if String(data.get("unitId", data.get("unit_id", ""))) != "":
			continue
		var elements_value = data.get("elements", {})
		if not (elements_value is Dictionary) or not _has_visible_elements(Dictionary(elements_value)):
			continue
		var grid := cell.call("get_grid_position") as Vector2i
		cell.emit_signal("cell_selected", grid.x, grid.y)
		return {
			"opened": true,
			"grid": {"x": grid.x, "y": grid.y},
			"elements": Dictionary(elements_value).duplicate(true),
		}
	return {"opened": false}


func clear_detail() -> void:
	if _overlay != null and _overlay.has_method("clear"):
		_overlay.call("clear")


func detail_summary() -> Dictionary:
	if _overlay == null:
		return {"visible": false}
	var detail_node := _first_visible_detail(_overlay)
	if detail_node == null:
		return {"visible": false, "unitId": "", "lineCount": 0, "text": "", "usesSharedPrefab": false}
	var text_value := String(detail_node.call("get_display_text")) \
		if detail_node.has_method("get_display_text") else ""
	var unit_id := ""
	if detail_node.has_method("get_detail_snapshot"):
		var detail := Dictionary(detail_node.call("get_detail_snapshot"))
		unit_id = String(detail.get("id", detail.get("unitId", "")))
	return {
		"visible": detail_node.visible,
		"unitId": unit_id,
		"lineCount": text_value.split("\n", false).size(),
		"text": text_value,
		"usesSharedPrefab": detail_node.scene_file_path == "res://art/prefabs/pet/pet_detail.tscn",
	}


func selected_action_range_summary(_snapshot: Dictionary = {}) -> Dictionary:
	for cell in _visible_cells():
		if not cell.has_method("get_unit_node"):
			continue
		var unit := cell.call("get_unit_node") as Control
		if unit == null or not unit.has_method("get_action_block_attack_range_snapshot"):
			continue
		var summary := Dictionary(unit.call("get_action_block_attack_range_snapshot"))
		if int(summary.get("visibleCellCount", 0)) <= 0:
			continue
		summary["unitId"] = String(unit.call("get_unit_id")) if unit.has_method("get_unit_id") else ""
		return summary
	return {"unitId": "", "visibleCellCount": 0}


func first_player_drag_case(snapshot: Dictionary = {}) -> Dictionary:
	for cell in _visible_cells():
		var data := _cell_data(cell)
		var unit_id := String(data.get("unitId", data.get("unit_id", "")))
		if unit_id == "" or not String(data.get("side", data.get("unitSide", ""))) in ["player", "ally"] \
				or _is_hero(data):
			continue
		var origin := cell.call("get_grid_position") as Vector2i
		var adjacent := _first_empty_adjacent(origin)
		if adjacent.x < 0:
			continue
		var target := _first_target_hitting_enemy(snapshot, unit_id, origin)
		if target.x < 0:
			target = adjacent
		return {
			"unitId": unit_id,
			"origin": {"x": origin.x, "y": origin.y},
			"target": {"x": target.x, "y": target.y},
		}
	return {}


func start_first_player_drag(snapshot: Dictionary = {}) -> Dictionary:
	var drag_case := first_player_drag_case(snapshot)
	if drag_case.is_empty():
		return {}
	var origin_value := Dictionary(drag_case["origin"])
	var target_value := Dictionary(drag_case["target"])
	var origin := Vector2i(int(origin_value["x"]), int(origin_value["y"]))
	var target := Vector2i(int(target_value["x"]), int(target_value["y"]))
	var started := start_drag(origin, target)
	drag_case["started"] = bool(started.get("started", false))
	drag_case["preview_was_active"] = bool(started.get("preview_was_active", false))
	return drag_case


func start_drag(origin: Vector2i, target: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	_active_drag_origin = origin
	_active_drag_target = target
	_last_command = {}
	var origin_cell := cell_at(_active_drag_origin)
	if origin_cell == null:
		return {"started": false, "dragging": false, "preview_was_active": false}
	var origin_position := origin_cell.get_global_rect().get_center()
	_drag_pointer_offset = origin_position - origin_cell.get_global_rect().position
	Input.warp_mouse(origin_position)
	var motion := InputEventMouseMotion.new()
	motion.position = origin_position
	motion.global_position = origin_position
	_scene.get_viewport().push_input(motion, true)
	origin_cell.emit_signal("cell_hovered", _active_drag_origin.x, _active_drag_origin.y)
	origin_cell.emit_signal("cell_pressed", _active_drag_origin.x, _active_drag_origin.y)
	return {
		"started": _drag_preview_node() != null,
		"dragging": _drag_preview_node() != null,
		"preview_was_active": _drag_preview_node() != null,
		"origin": {"x": origin.x, "y": origin.y},
		"target": {"x": target.x, "y": target.y},
	}


func update_drag(target: Vector2i, _snapshot: Dictionary = {}) -> Dictionary:
	_active_drag_target = target
	var target_cell := cell_at(target)
	if target_cell == null or _scene == null:
		return drag_summary()
	var target_position := target_cell.get_global_rect().position + _drag_pointer_offset
	target_cell.emit_signal("cell_hovered", target.x, target.y)
	Input.warp_mouse(target_position)
	var motion := InputEventMouseMotion.new()
	motion.position = target_position
	motion.global_position = target_position
	_scene.get_viewport().push_input(motion, true)
	await _scene.get_tree().process_frame
	target_cell.emit_signal("cell_hovered", target.x, target.y)
	return drag_summary()


func stabilize_drag_preview_for_capture(target: Vector2i) -> bool:
	var target_cell := cell_at(target)
	var preview := _drag_preview_node()
	if target_cell == null or preview == null or _board == null:
		return false
	# The retired production debug path pinned the preview to the authored
	# floating-point cell origin every frame. Real mouse coordinates are integer
	# pixels, so deterministic before/after captures reproduce that test-only
	# framing after the real input path has already created and moved the drag.
	target_cell.emit_signal("cell_hovered", target.x, target.y)
	_board.set_process(false)
	preview.position = target_cell.position
	return true


func finish_drag(target: Vector2i) -> Dictionary:
	_last_command = {}
	var target_cell := cell_at(target)
	if target_cell != null:
		target_cell.emit_signal("cell_released", target.x, target.y)
	_active_drag_origin = Vector2i(-1, -1)
	_active_drag_target = Vector2i(-1, -1)
	_drag_pointer_offset = Vector2.ZERO
	return _last_command.duplicate(true)


func cancel_drag() -> void:
	if _active_drag_origin.x >= 0:
		finish_drag(_active_drag_origin)
	else:
		var preview := _drag_preview_node()
		if preview != null:
			preview.queue_free()


func drag_summary(_snapshot: Dictionary = {}) -> Dictionary:
	var highlighted: Array[Dictionary] = []
	for cell in _visible_cells():
		if cell.has_method("is_attack_highlight_blinking") \
				and bool(cell.call("is_attack_highlight_blinking")):
			var grid := cell.call("get_grid_position") as Vector2i
			highlighted.append({"x": grid.x, "y": grid.y})
	return {
		"dragging": _drag_preview_node() != null,
		"preview_was_active": _drag_preview_node() != null,
		"target": {"x": _active_drag_target.x, "y": _active_drag_target.y},
		"attack_highlight_count": highlighted.size(),
		"attack_cells": highlighted,
		"command": _last_command.duplicate(true),
	}


func hover_cell(grid: Vector2i, hovered: bool) -> bool:
	var cell := cell_at(grid)
	if cell == null:
		return false
	cell.emit_signal("cell_hovered" if hovered else "cell_unhovered", grid.x, grid.y)
	return true


func press_hud_command(command_type: StringName) -> Dictionary:
	_last_command = {}
	if _hud == null:
		return {}
	var button: BaseButton = null
	match String(command_type):
		"AUTO_POSITION_HEROES":
			button = _hud.get_node_or_null("BattlePrimaryActions/AutoArrangeButton") as BaseButton
		"RUN_COMBAT_ROUND":
			button = _hud.get_node_or_null("BattlePrimaryActions/BeginTurnButton") as BaseButton
		"END_PLAYER_TURN":
			button = _hud.get_node_or_null("BattleActionPanel/Margin/Content/EndTurnButton") as BaseButton
		"RUN_MONSTER_TURN":
			button = _hud.get_node_or_null("BattleActionPanel/Margin/Content/MonsterTurnButton") as BaseButton
	if button != null and not button.disabled:
		button.emit_signal("pressed")
	return _last_command.duplicate(true)


func emit_command_request(command: Dictionary) -> Dictionary:
	if _scene == null or command.is_empty():
		return {}
	_last_command = command.duplicate(true)
	_scene.emit_signal("command_requested", command.duplicate(true))
	return command.duplicate(true)


func _on_command_requested(command: Dictionary) -> void:
	_last_command = command.duplicate(true)


func _on_vfx_child_entered(node: Node) -> void:
	if node != null and node.name == &"RoundFeedback":
		_round_banner_observed = true


func _visible_cells() -> Array[Control]:
	var result: Array[Control] = []
	if _board == null:
		return result
	var cell_host := _board.get_node_or_null("CellHost")
	if cell_host == null:
		return result
	for child in cell_host.get_children():
		if child is Control and child.visible and child.has_method("get_grid_position"):
			result.append(child as Control)
	return result


func _cell_data(cell: Control) -> Dictionary:
	var raw_data = cell.get("cell_data") if cell != null else null
	return Dictionary(raw_data) if raw_data is Dictionary else {}


func _first_empty_adjacent(origin: Vector2i) -> Vector2i:
	for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var target: Vector2i = origin + Vector2i(offset)
		var cell := cell_at(target)
		if cell != null and String(_cell_data(cell).get("unitId", _cell_data(cell).get("unit_id", ""))) == "":
			return target
	return Vector2i(-1, -1)


func _first_target_hitting_enemy(snapshot: Dictionary, unit_id: String, origin: Vector2i) -> Vector2i:
	if snapshot.is_empty() or _board == null:
		return Vector2i(-1, -1)
	var dimensions := _board.call("board_dimensions") as Vector2i
	var first_visible_preview_target := Vector2i(-1, -1)
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			var target := Vector2i(x, y)
			if target == origin:
				continue
			var target_cell := cell_at(target)
			if target_cell == null:
				continue
			var target_unit_id := String(_cell_data(target_cell).get("unitId", _cell_data(target_cell).get("unit_id", "")))
			if target_unit_id != "":
				continue
			var attack_cells: Array[Vector2i] = _preview_presenter.call(
				"action_cells_for_drag", snapshot, unit_id, target, dimensions
			)
			if not attack_cells.is_empty() and first_visible_preview_target.x < 0:
				first_visible_preview_target = target
			for attack_grid in attack_cells:
				var attack_cell := cell_at(attack_grid)
				if attack_cell != null and _is_enemy(_cell_data(attack_cell)):
					return target
	return first_visible_preview_target


func _is_enemy(data: Dictionary) -> bool:
	return String(data.get("unitId", data.get("unit_id", ""))) != "" \
		and not String(data.get("side", data.get("unitSide", ""))) in ["player", "ally", "hero", "hero_leader", "player_leader"]


func _is_hero(data: Dictionary) -> bool:
	var unit_id := String(data.get("unitId", data.get("unit_id", "")))
	var unit_type := String(data.get("type", data.get("unitType", data.get("unit_type", "")))).to_lower()
	var side := String(data.get("side", data.get("unitSide", "")))
	return unit_type == "hero" or unit_id in ["player_hero", "enemy_hero"] \
		or side in ["hero_leader", "player_leader", "enemy_leader", "boss"]


func _has_visible_elements(elements: Dictionary) -> bool:
	for amount in elements.values():
		if int(amount) > 0:
			return true
	return false


func _first_visible_detail(root_node: Node) -> Control:
	for child in root_node.get_children():
		if child is Control and not child.visible:
			continue
		if child is Control and child.visible \
				and (child.has_method("get_detail_snapshot") or child.has_method("get_display_text")):
			return child as Control
		var nested := _first_visible_detail(child)
		if nested != null:
			return nested
	return null


func _drag_preview_node() -> Control:
	if _board == null:
		return null
	return _board.get_node_or_null("UnitHost/BattleUnitDragPreview") as Control
