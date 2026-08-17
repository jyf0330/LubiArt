extends RefCounted

## Deterministic value projector for battle reads. Configured collaborators are
## shared stateless services; each call receives and returns detached values.

const BattleQueryContextScript := preload("res://core/commands/battle_query_context.gd")
const BattleQuerySessionScript := preload("res://core/commands/battle_query_session.gd")
const PreviewHorizonScript := preload("res://core/commands/preview_horizon.gd")
const ValueDamagePreviewPortScript := preload("res://core/ports/value_damage_preview_port.gd")
const BattleBoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")
const SkillShapeRulesScript := preload("res://core/battle/skills/skill_shape_rules.gd")

const PLAYER := "player"
const ENEMY := "enemy"

var _action_slot_service: RefCounted = null
var _attack_option_service: RefCounted = null
var _targeting_service: RefCounted = null
var _stat_query_service: RefCounted = null
var _quality_effect_registry: RefCounted = null
var _quality_hit_context_projector: RefCounted = null
var _threat_target_policy: RefCounted = null
var _damage_resolver: RefCounted = null
var _stat_semantic_pipeline: RefCounted = null
var _mechanic_projection_service: RefCounted = null


func configure(
	action_slot_service: RefCounted,
	attack_option_service: RefCounted,
	targeting_service: RefCounted,
	stat_query_service: RefCounted,
	quality_effect_registry: RefCounted,
	quality_hit_context_projector: RefCounted,
	threat_target_policy: RefCounted,
	damage_resolver: RefCounted,
	stat_semantic_pipeline: RefCounted,
	mechanic_projection_service: RefCounted
) -> RefCounted:
	_action_slot_service = action_slot_service
	_attack_option_service = attack_option_service
	_targeting_service = targeting_service
	_stat_query_service = stat_query_service
	_quality_effect_registry = quality_effect_registry
	_quality_hit_context_projector = quality_hit_context_projector
	_threat_target_policy = threat_target_policy
	_damage_resolver = damage_resolver
	_stat_semantic_pipeline = stat_semantic_pipeline
	_mechanic_projection_service = mechanic_projection_service
	return self


func action_slots(context: Dictionary, unit: Dictionary) -> Array:
	if not _valid(context) or unit.is_empty():
		return []
	return _action_slots(context, unit)


func snapshot_projection(context: Dictionary, unit: Dictionary) -> Dictionary:
	# A Snapshot asks for these five projections from the exact same immutable
	# context. Validate that value boundary once instead of recursively walking
	# the full content database once per projection.
	if not _valid(context):
		return {
			"actionSlots": [],
			"selectedActionCells": [],
			"actionPreviewByUnit": {},
			"actionBlockRangesByUnit": {},
			"board": {},
		}
	return {
		"actionSlots": [] if unit.is_empty() else _action_slots(context, unit),
		"selectedActionCells": _selected_action_cells(context),
		"actionPreviewByUnit": _action_preview_by_unit(context),
		"actionBlockRangesByUnit": _action_block_ranges_by_unit(context),
		"board": _project_board(context),
	}


func begin(context: Dictionary) -> RefCounted:
	if not _valid(context):
		return null
	return BattleQuerySessionScript.new(self, context)


func selected_action_cells(context: Dictionary) -> Array:
	if not _valid(context):
		return []
	return _selected_action_cells(context)


func action_preview_by_unit(context: Dictionary) -> Dictionary:
	if not _valid(context):
		return {}
	return _action_preview_by_unit(context)


func action_block_ranges_by_unit(context: Dictionary) -> Dictionary:
	if not _valid(context):
		return {}
	return _action_block_ranges_by_unit(context)


func selected_action_preview_by_cell(context: Dictionary) -> Dictionary:
	if not _valid(context):
		return {}
	return _selected_action_preview_by_cell(context)


func project_action_grid(context: Dictionary, request: Dictionary = {}) -> Array:
	if not _valid(context):
		return []
	return _project_action_grid(context, request)


func project_board(context: Dictionary) -> Dictionary:
	if not _valid(context):
		return {}
	return _project_board(context)


func _project_board(context: Dictionary) -> Dictionary:
	var board_value := Dictionary(context.get("board", {}))
	var width := int(board_value.get("width", 0))
	var height := int(board_value.get("height", 0))
	var preview_rows_by_cell := _preview_rows_by_cell(context)
	var threat_by_cell := _threat_grid_by_cell(context)
	var placement_damage := Dictionary(context.get("placementDamageByUnit", {}))
	var cells: Array = []
	for y in range(height):
		for x in range(width):
			var occupant := _unit_at(context, x, y)
			var leader := _leader_at(context, x, y) if occupant.is_empty() else {}
			var key := _cell_key(x, y)
			var cell := {
				"x": x, "y": y, "r": y, "c": x, "key": key,
				"unit_id": "", "unitId": "", "pet_id": "", "petId": "",
				"unitSide": "", "side": "", "unitName": "", "name": "",
				"hp": 0, "shield": 0, "atk": 0, "leaderId": null,
			}
			if not occupant.is_empty():
				cell["unit_id"] = String(occupant.get("id", ""))
				cell["unitId"] = String(occupant.get("id", ""))
				cell["pet_id"] = String(occupant.get("pet_id", occupant.get("petId", "")))
				cell["petId"] = String(cell["pet_id"])
				cell["side"] = String(occupant.get("side", ""))
				cell["unitSide"] = String(occupant.get("side", ""))
				cell["name"] = String(occupant.get("name", ""))
				cell["unitName"] = String(occupant.get("name", ""))
				cell["hp"] = int(occupant.get("hp", 0))
				cell["shield"] = int(occupant.get("shield", 0))
				cell["atk"] = _resolved_stat_value(context, occupant, "atk", {"hook": EffectHookIdsScript.SNAPSHOT})
				cell["resolvedStats"] = Dictionary(_stat_query_service.call(
					"values_from_resolved",
					Dictionary(_stat_query_service.call(
						"resolve_all",
						occupant,
						Dictionary(context.get("gameData", {})),
						EffectHookIdsScript.SNAPSHOT,
						{"cache_key": "%s:%s" % [int(context.get("stateVersion", 0)), String(occupant.get("id", ""))]}
					))
				))
				var board_elements := _cell_elements_at(context, x, y)
				cell["elements"] = board_elements if _has_visible_elements(board_elements) else ElementRulesScript.normalize_layers(Dictionary(occupant.get("elements", {})))
			elif not leader.is_empty():
				cell["unit_id"] = String(leader.get("id", ""))
				cell["unitId"] = String(leader.get("id", ""))
				cell["side"] = String(leader.get("side", ""))
				cell["unitSide"] = String(leader.get("side", ""))
				cell["name"] = String(leader.get("name", ""))
				cell["unitName"] = String(leader.get("name", ""))
				cell["hp"] = int(leader.get("hp", 0))
				cell["shield"] = int(leader.get("shield", 0))
				cell["atk"] = _resolved_stat_value(context, leader, "atk", {"hook": EffectHookIdsScript.SNAPSHOT})
				cell["mechanics"] = Array(leader.get("mechanics", [])).duplicate(true)
				cell["buffs"] = Array(leader.get("buffs", [])).duplicate(true)
				cell["leaderId"] = String(leader.get("id", ""))
				cell["elements"] = _cell_elements_at(context, x, y)
			else:
				cell["elements"] = _cell_elements_at(context, x, y)
			cell["trace"] = _board_trace_at(context, x, y)
			cell["traces"] = _board_traces_at(context, x, y)
			if preview_rows_by_cell.has(key):
				var preview_rows := Array(preview_rows_by_cell[key]).duplicate(true)
				var active_preview := _board_preview_payload(_active_preview_row(preview_rows))
				cell["previews"] = preview_rows
				cell["preview"] = active_preview
				cell["action_preview"] = true
				cell["action_preview_data"] = active_preview.duplicate(true)
			if threat_by_cell.has(key):
				cell["threat"] = Dictionary(threat_by_cell[key]).duplicate(true)
			var unit_id := String(cell.get("unitId", ""))
			if unit_id != "" and placement_damage.has(unit_id):
				cell["threat"] = Dictionary(placement_damage[unit_id]).duplicate(true)
			cells.append(cell)
	var board := BattleBoardDimensionsScript.to_snapshot(width, height)
	board["size"] = width
	board["dimensions"] = {"width": width, "height": height}
	board["cells"] = cells
	return board.duplicate(true)


func project_cell_detail(context: Dictionary, request: Dictionary) -> Dictionary:
	if not _valid(context):
		return {}
	var x := _request_x(request)
	var y := _request_y(request)
	if not _inside(context, x, y):
		return {}
	var projected_cell := _projected_cell_at(project_board(context), x, y)
	return _project_cell_detail(context, x, y, projected_cell)


func project_all_cell_details(context: Dictionary) -> Array:
	if not _valid(context):
		return []
	var board := project_board(context)
	var projected_by_key: Dictionary = {}
	for cell_value in Array(board.get("cells", [])):
		var cell := Dictionary(cell_value)
		projected_by_key[_cell_key(int(cell.get("x", -1)), int(cell.get("y", -1)))] = cell
	var dimensions := Dictionary(context.get("board", {}))
	var out: Array = []
	for y in range(int(dimensions.get("height", 0))):
		for x in range(int(dimensions.get("width", 0))):
			out.append(_project_cell_detail(
				context,
				x,
				y,
				Dictionary(projected_by_key.get(_cell_key(x, y), {}))
			))
	return out


func _project_cell_detail(context: Dictionary, x: int, y: int, projected_cell: Dictionary) -> Dictionary:
	var occupant := _unit_at(context, x, y)
	var leader := _leader_at(context, x, y) if occupant.is_empty() else {}
	var detail_unit := occupant if not occupant.is_empty() else leader
	return {
		"r": y,
		"c": x,
		"x": x,
		"y": y,
		"key": _cell_key(x, y),
		"terrain": {},
		"elements": Dictionary(projected_cell.get("elements", {})).duplicate(true),
		"unit": _project_unit_detail(context, detail_unit),
		"preview": Dictionary(projected_cell.get("preview", {})).duplicate(true),
		"threat": Dictionary(projected_cell.get("threat", {})).duplicate(true),
		"trace": Dictionary(projected_cell.get("trace", {})).duplicate(true),
		"traces": Array(projected_cell.get("traces", [])).duplicate(true),
	}


func _projected_cell_at(board: Dictionary, x: int, y: int) -> Dictionary:
	for cell_value in Array(board.get("cells", [])):
		var candidate := Dictionary(cell_value)
		if int(candidate.get("x", -1)) == x and int(candidate.get("y", -1)) == y:
			return candidate
	return {}


func _project_unit_detail(context: Dictionary, unit: Dictionary) -> Dictionary:
	if unit.is_empty():
		return {}
	var game_data := Dictionary(context.get("gameData", {}))
	var resolved_document := Dictionary(_stat_query_service.call(
		"resolve_all", unit, game_data, EffectHookIdsScript.CELL_DETAIL
	))
	var resolved_stats := Dictionary(_stat_query_service.call("values_from_resolved", resolved_document))
	var maximum_hp: int = int(resolved_stats.get("max_hp", unit.get("max_hp", unit.get("maxHp", unit.get("hp", 0)))))
	var attack: int = int(resolved_stats.get("atk", unit.get("atk", unit.get("attack", 0))))
	var defense: int = int(resolved_stats.get("def", unit.get("def", unit.get("defense", 0))))
	return {
		"id": String(unit.get("id", "")),
		"pet_id": String(unit.get("pet_id", unit.get("petId", ""))),
		"petId": String(unit.get("pet_id", unit.get("petId", ""))),
		"name": String(unit.get("name", "")),
		"displayName": String(unit.get("displayName", unit.get("name", ""))),
		"side": String(unit.get("side", "")),
		"camp": String(unit.get("camp", unit.get("side", ""))),
		"role": String(unit.get("role", "")),
		"quality": String(unit.get("quality", "")),
		"element": String(unit.get("element", "")),
		"element_types": Array(unit.get("element_types", [])).duplicate(true),
		"hp": int(unit.get("hp", 0)),
		"max_hp": maximum_hp,
		"maxHp": maximum_hp,
		"atk": attack,
		"attack": attack,
		"def": defense,
		"defense": defense,
		"resolved_stats": resolved_stats,
		"resolvedStats": resolved_stats.duplicate(true),
		"shield": int(unit.get("shield", 0)),
		"ap": int(unit.get("ap", 0)),
		"move_range": max(0, _resolved_stat_value(context, unit, "move_range", {"hook": EffectHookIdsScript.MOVEMENT})),
		"attack_count": max(0, _resolved_stat_value(context, unit, "attack_count", {"hook": EffectHookIdsScript.ACTION_COUNT})) if String(unit.get("side", "")) == ENEMY else 0,
		"active": bool(unit.get("active", true)),
		"alive": bool(unit.get("alive", int(unit.get("hp", 0)) > 0)),
		"x": int(unit.get("x", -1)),
		"y": int(unit.get("y", -1)),
		"skill": unit.get("skill", ""),
		"mechanics": Array(unit.get("mechanics", [])).duplicate(true),
		"buffs": Array(unit.get("buffs", [])).duplicate(true),
		"elements": ElementRulesScript.normalize_layers(Dictionary(unit.get("elements", {}))),
		"quality_progression": Dictionary(unit.get("quality_progression", {})).duplicate(true),
		"quality_upgrade": Dictionary(unit.get("quality_upgrade", {})).duplicate(true),
		"shape_id": SkillShapeRulesScript.shape_id_for_unit(unit, game_data),
		"shape": String(unit.get("shape", "")),
		"range": String(unit.get("range", "")),
		"attack_shape": SkillShapeRulesScript.shape_definition(unit, game_data),
	}


func project_damage(
	context: Dictionary,
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String = "",
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> Dictionary:
	if not _valid(context) or _damage_resolver == null:
		return {}
	return _project_damage(context, source, target, amount, element, trace_context, damage_props)


func _project_damage(
	context: Dictionary,
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String = "",
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> Dictionary:
	var effective_trace_context := trace_context.duplicate(true)
	if String(effective_trace_context.get("sourceType", "")).strip_edges() == "":
		effective_trace_context["sourceType"] = "preview_effect"
	var effective_props := DamagePropsScript.resolve(
		damage_props,
		String(effective_trace_context.get("sourceType", "preview_effect"))
	)
	return Dictionary(_damage_resolver.call(
		"preview",
		ValueDamagePreviewPortScript.new(context, _stat_query_service, _stat_semantic_pipeline),
		source.duplicate(true),
		target.duplicate(true),
		amount,
		element,
		effective_trace_context,
		effective_props
	)).duplicate(true)


func project_settlement(
	context: Dictionary,
	after_elements: Dictionary,
	element: String,
	source: Dictionary = {}
) -> Dictionary:
	if not _valid(context):
		return {}
	return _project_settlement(context, after_elements, element, source)


func _project_settlement(
	context: Dictionary,
	after_elements: Dictionary,
	element: String,
	_source: Dictionary = {}
) -> Dictionary:
	element = ElementRulesScript.canonical(element)
	if not ElementRulesScript.SETTLEMENT_ELEMENTS.has(element):
		return {}
	var layers: int = max(0, int(after_elements.get(element, 0)))
	if layers < 3:
		return {}
	if _mechanic_projection_service == null:
		return {}
	var plan := Dictionary(_mechanic_projection_service.call(
		"element_settlement_plan",
		Array(context.get("units", [])).duplicate(true),
		_battle_mechanisms(context),
		after_elements.duplicate(true),
		element
	))
	if not bool(plan.get("ok", false)):
		return {}
	return {
		"element": element,
		"layers": layers,
		"rawDamage": int(plan.get("damage", 0)),
		"formula": "sum_1_to_n",
	}


func project_unit_diff_rows(context: Dictionary) -> Array:
	if not _valid(context):
		return []
	var out: Array = []
	for item in Array(context.get("units", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var unit := Dictionary(item)
		out.append({
			"id": String(unit.get("id", "")),
			"name": String(unit.get("name", "")),
			"side": String(unit.get("side", "")),
			"hp": int(unit.get("hp", 0)),
			"shield": int(unit.get("shield", 0)),
			"x": int(unit.get("x", -1)),
			"y": int(unit.get("y", -1)),
			"alive": int(unit.get("hp", 0)) > 0,
			"elements": ElementRulesScript.normalize_layers(Dictionary(unit.get("elements", {}))),
		})
	return out


func _valid(context: Dictionary) -> bool:
	return BattleQueryContextScript.validate(context).is_empty()


func _action_slots(context: Dictionary, unit: Dictionary) -> Array:
	if unit.is_empty() or _action_slot_service == null:
		return []
	var selection := Dictionary(context.get("selection", {}))
	return Array(_action_slot_service.call("project_slots", unit, {
		"availableAp": int(selection.get("ap", 0)),
		"selectedApChoices": Dictionary(context.get("actionApChoices", {})),
		"directions": Dictionary(context.get("actionDirections", {})),
		"shapeDefinition": SkillShapeRulesScript.shape_definition(unit, Dictionary(context.get("gameData", {}))),
	})).duplicate(true)


func _selected_action_cells(context: Dictionary) -> Array:
	if String(context.get("phase", "")) != "battle":
		return []
	var unit := _selected_unit(context)
	if unit.is_empty() or String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
		return []
	return _action_cells_for_unit(context, unit, _selected_action_slot(context, unit))


func _action_cells_for_unit(context: Dictionary, unit: Dictionary, slot: Dictionary) -> Array:
	if slot.is_empty() or bool(slot.get("used", false)):
		return []
	var option := _attack_option_for_direction(context, unit, String(slot.get("direction", "right")))
	if option.is_empty():
		return []
	var cells: Array = []
	var index := 0
	for item in Array(option.get("cells", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		var x := int(row.get("x", -1))
		var y := int(row.get("y", -1))
		if not _inside(context, x, y):
			continue
		var occupant := _unit_at(context, x, y)
		cells.append({
			"index": index,
			"x": x, "y": y, "c": x, "r": y,
			"preview_type": "empty" if occupant.is_empty() else ("target" if String(occupant.get("side", "")) == ENEMY else "ally"),
			"target_unit_id": "" if occupant.is_empty() else String(occupant.get("id", "")),
			"target_name": "" if occupant.is_empty() else String(occupant.get("name", occupant.get("id", ""))),
		})
		index += 1
	return cells


func _action_preview_by_unit(context: Dictionary) -> Dictionary:
	var previews := {}
	if String(context.get("phase", "")) != "battle":
		return previews
	for unit_value in Array(context.get("units", [])):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
			continue
		var slots := _action_slots(context, unit)
		if slots.is_empty():
			continue
		var slot_index := _preview_slot_index_for_unit(context, unit, slots)
		var slot := Dictionary(slots[slot_index])
		var unit_id := String(unit.get("id", ""))
		if unit_id == "":
			continue
		previews[unit_id] = {
			"unitId": unit_id,
			"origin": {"x": int(unit.get("x", -1)), "y": int(unit.get("y", -1))},
			"slotIndex": slot_index,
			"direction": String(slot.get("direction", "right")),
			"shapeId": String(slot.get("shape_id", "")),
			"available": not bool(slot.get("used", false)),
			"cells": _action_cells_for_unit(context, unit, slot),
		}
	return previews


func _action_block_ranges_by_unit(context: Dictionary) -> Dictionary:
	var ranges_by_unit := {}
	if String(context.get("phase", "")) != "battle":
		return ranges_by_unit
	for unit_value in Array(context.get("units", [])):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
			continue
		var unit_id := String(unit.get("id", ""))
		if unit_id == "":
			continue
		var origin := {"x": int(unit.get("x", -1)), "y": int(unit.get("y", -1))}
		var block_ranges: Array[Dictionary] = []
		var slots := _action_slots(context, unit)
		for slot_index in range(mini(3, slots.size())):
			var slot := Dictionary(slots[slot_index])
			block_ranges.append({
				"slotIndex": slot_index,
				"origin": origin.duplicate(true),
				"direction": String(slot.get("direction", "right")),
				"available": not bool(slot.get("used", false)),
				"cells": _action_cells_for_unit(context, unit, slot),
			})
		ranges_by_unit[unit_id] = block_ranges
	return ranges_by_unit


func _preview_slot_index_for_unit(context: Dictionary, unit: Dictionary, slots: Array) -> int:
	var selection := Dictionary(context.get("selection", {}))
	if String(unit.get("id", "")) == String(selection.get("unitId", "")):
		return clampi(int(selection.get("slotIndex", 0)), 0, slots.size() - 1)
	for index in range(slots.size()):
		if not bool(Dictionary(slots[index]).get("used", false)):
			return index
	return 0


func _selected_action_preview_by_cell(context: Dictionary) -> Dictionary:
	if String(context.get("phase", "")) != "battle":
		return {}
	var unit := _selected_unit(context)
	if unit.is_empty() or String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
		return {}
	var slot := _selected_action_slot(context, unit)
	if slot.is_empty() or bool(slot.get("used", false)):
		return {}
	var direction := ShapeGeometryScript.normalize_direction(String(slot.get("direction", "right")))
	var option := _attack_option_for_direction(context, unit, direction)
	if option.is_empty():
		return {}
	var selection := Dictionary(context.get("selection", {}))
	var action_element_layers: int = int(slot.get("effective_layers", slot.get("layers", 1))) * max(1, int(slot.get("strike_count", 1)))
	var preview: Dictionary = {}
	for item in Array(option.get("cells", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var cell := Dictionary(item)
		var x := int(cell.get("x", -1))
		var y := int(cell.get("y", -1))
		if not _inside(context, x, y):
			continue
		var occupant := _unit_at(context, x, y)
		var preview_type := "empty"
		var target_id := ""
		var target_name := ""
		if not occupant.is_empty():
			target_id = String(occupant.get("id", ""))
			target_name = String(occupant.get("name", target_id))
			preview_type = "target" if String(occupant.get("side", "")) == ENEMY else "ally"
		preview[_cell_key(x, y)] = {
			"unit_id": String(unit.get("id", "")),
			"slot_index": int(slot.get("index", selection.get("slotIndex", 0))),
			"slot_label": String(slot.get("label", "")),
			"element": String(slot.get("element", "")),
			"layers": action_element_layers,
			"base_layers": int(slot.get("base_layers", slot.get("layers", 1))),
			"ap": int(slot.get("selected_ap", 1)),
			"shape_id": String(option.get("shape_id", slot.get("shape_id", ""))),
			"shape_name": String(option.get("shape_name", slot.get("shape_name", ""))),
			"direction": direction,
			"direction_label": ShapeGeometryScript.direction_label(direction),
			"preview_type": preview_type,
			"target_unit_id": target_id,
			"target_name": target_name,
		}
	return preview


func _project_action_grid(context: Dictionary, action: Dictionary) -> Array:
	if String(context.get("phase", "")) != "battle":
		return []
	var actors: Array = []
	for candidate_value in Array(context.get("units", [])):
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate := Dictionary(candidate_value)
		if String(candidate.get("side", "")) == PLAYER and int(candidate.get("hp", 0)) > 0:
			actors.append(candidate)
	if actors.is_empty():
		return []
	var active_unit := _preview_unit_for_action(context, action)
	var active_unit_id := String(active_unit.get("id", "")) if not active_unit.is_empty() else String(Dictionary(actors[0]).get("id", ""))
	var out: Array = []
	var projected_elements_by_cell := {}
	var projected_units_by_id := {}
	var selected_slot_index := int(Dictionary(context.get("selection", {})).get("slotIndex", 0))
	for order in range(actors.size()):
		var unit := Dictionary(actors[order])
		var is_active_actor := String(unit.get("id", "")) == active_unit_id
		var actor_action := action if is_active_actor else {}
		var slots := _action_slots(context, unit)
		if slots.is_empty():
			continue
		var slot_index := _preview_slot_index_for_action(actor_action, selected_slot_index if is_active_actor else 0, slots.size())
		var slot := Dictionary(slots[slot_index])
		if bool(slot.get("used", false)):
			continue
		var direction := _preview_direction_for_action(context, actor_action, unit, slot_index)
		var selected_ap := _preview_ap_for_action(context, actor_action, unit, slot_index)
		var option := _attack_option_for_direction(context, unit, direction)
		if option.is_empty():
			continue
		var effective_layers: int = max(1, int(slot.get("base_layers", slot.get("layers", 1)))) * selected_ap
		var action_element_layers: int = effective_layers * max(1, int(slot.get("strike_count", 1)))
		var preview_targets := _enemies_in_attack_option(context, unit, option)
		for item in Array(option.get("cells", [])):
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var cell := Dictionary(item)
			var x := int(cell.get("x", -1))
			var y := int(cell.get("y", -1))
			if not _inside(context, x, y):
				continue
			var target := _unit_at(context, x, y)
			if target.is_empty():
				continue
			var target_id := String(target.get("id", ""))
			var target_projection := Dictionary(projected_units_by_id.get(target_id, {}))
			if not target_projection.is_empty() and int(target_projection.get("hp", 0)) <= 0:
				continue
			var actor_side := String(unit.get("side", ""))
			var target_side := String(target.get("side", ""))
			var hits_enemy := target_side != "" and target_side != actor_side
			var hits_ally := target_side != "" and target_side == actor_side
			var quality_delta := int(cell.get("quality_damage_delta", 0))
			var base_raw_damage: int = max(0, _resolved_stat_value(context, unit, "atk", {"hook": EffectHookIdsScript.ACTION_PROJECTION, "target": target}))
			var raw_damage: int = max(0, base_raw_damage + quality_delta)
			if hits_enemy:
				var preview_hit_index := _preview_hit_index_for_target(preview_targets, target_id)
				raw_damage = _preview_quality_damage_for_hit(context, unit, option, preview_targets, target, preview_hit_index, base_raw_damage)
			var slot_element := String(slot.get("element", ""))
			var cell_key := _cell_key(x, y)
			var before_elements := Dictionary(projected_elements_by_cell.get(cell_key, _cell_elements_at(context, x, y))).duplicate(true)
			var after_elements := before_elements.duplicate(true)
			after_elements[slot_element] = int(after_elements.get(slot_element, 0)) + action_element_layers
			var same_element_before := int(before_elements.get(slot_element, 0))
			var link_elements: Array = []
			for element_key in before_elements.keys():
				var link_element := String(element_key)
				if link_element != slot_element and int(before_elements.get(element_key, 0)) > 0:
					link_elements.append(link_element)
			var settlement := _project_settlement(context, after_elements, slot_element, unit)
			var projected_hp: int = max(0, int(target_projection.get("hp", target.get("hp", 0))))
			var projected_shield: int = max(0, int(target_projection.get("shield", target.get("shield", 0))))
			var settlement_projection := {}
			if not settlement.is_empty():
				settlement_projection = _damage_projection(context, unit, int(settlement.get("rawDamage", 0)), target, hits_enemy, slot_element, projected_hp, projected_shield, "elemental")
				projected_hp = int(settlement_projection.get("hp_to", projected_hp))
				projected_shield = int(settlement_projection.get("shield_to", projected_shield))
			var action_projection := _damage_projection(context, unit, raw_damage, target, hits_enemy, slot_element, projected_hp, projected_shield, "physical")
			var projected_after_elements := after_elements.duplicate(true)
			if not settlement.is_empty():
				projected_after_elements[String(settlement.get("element", slot_element))] = 0
			projected_elements_by_cell[cell_key] = projected_after_elements
			projected_units_by_id[target_id] = {
				"hp": int(action_projection.get("hp_to", projected_hp)),
				"shield": int(action_projection.get("shield_to", projected_shield)),
			}
			var first_projection := Dictionary(settlement_projection) if not settlement_projection.is_empty() else Dictionary(action_projection)
			var predicted_damage := int(settlement_projection.get("final", 0)) + int(action_projection.get("final", 0))
			var predicted_raw_damage := int(settlement_projection.get("raw", 0)) + int(action_projection.get("raw", 0))
			var predicted_hp_damage := int(settlement_projection.get("hp_damage", 0)) + int(action_projection.get("hp_damage", 0))
			var predicted_shield_damage := int(settlement_projection.get("shield_damage", 0)) + int(action_projection.get("shield_damage", 0))
			out.append({
				"r": y, "c": x, "x": x, "y": y,
				"previewHorizon": PreviewHorizonScript.IMMEDIATE_ACTION,
				"previewId": "%s:%s:%d,%d" % [String(unit.get("id", "")), String(slot.get("slot_id", slot_index)), y, x],
				"actorId": String(unit.get("id", "")),
				"actorName": String(unit.get("name", unit.get("displayName", ""))),
				"order": order,
				"isActiveActor": is_active_actor,
				"slotId": String(slot.get("slot_id", "")),
				"slotIndex": slot_index,
				"slotLabel": String(slot.get("label", "")),
				"direction": direction,
				"directionLabel": ShapeGeometryScript.direction_label(direction),
				"shapeId": String(option.get("shape_id", slot.get("shape_id", ""))),
				"shapeName": String(option.get("shape_name", slot.get("shape_name", ""))),
				"element": String(slot.get("element", "")),
				"layers": action_element_layers,
				"ap": selected_ap,
				"targetId": target_id,
				"targetName": String(target.get("name", target.get("displayName", ""))),
				"hitEnemy": hits_enemy,
				"hitAlly": hits_ally,
				"friendlyFire": hits_ally and predicted_damage > 0,
				"predictedDamage": predicted_damage,
				"predictedRawDamage": predicted_raw_damage,
				"predictedHpDamage": predicted_hp_damage,
				"predictedShieldDamage": predicted_shield_damage,
				"predictedHpFrom": int(first_projection.get("hp_from", 0)),
				"predictedHpTo": int(action_projection.get("hp_to", 0)),
				"predictedShieldFrom": int(first_projection.get("shield_from", 0)),
				"predictedShieldTo": int(action_projection.get("shield_to", 0)),
				"predictedActionDamage": int(action_projection.get("final", 0)),
				"predictedActionRawDamage": int(action_projection.get("raw", 0)),
				"predictedSettlementDamage": int(settlement_projection.get("final", 0)),
				"predictedSettlementRawDamage": int(settlement_projection.get("raw", 0)),
				"settlement": settlement,
				"triggersElementLink": same_element_before > 0 or link_elements.size() > 0 or not settlement.is_empty(),
				"elementLinks": link_elements,
				"predictedKill": bool(settlement_projection.get("killed", false)) or bool(action_projection.get("killed", false)),
				"preview_type": "target" if hits_enemy else "ally",
				"text": "%s %s %s%d层 %s -> %d,%d %s" % [
					String(unit.get("name", "我方")), String(slot.get("label", "")), slot_element,
					action_element_layers, ShapeGeometryScript.direction_label(direction), y, x,
					String(target.get("name", target.get("id", ""))),
				],
			})
	return out


func _preview_rows_by_cell(context: Dictionary, action: Dictionary = {}) -> Dictionary:
	var by_cell: Dictionary = {}
	for row_value in _project_action_grid(context, action):
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(row_value)
		var x := int(row.get("x", row.get("c", -1)))
		var y := int(row.get("y", row.get("r", -1)))
		if not _inside(context, x, y):
			continue
		var key := _cell_key(x, y)
		var rows: Array = Array(by_cell.get(key, [])).duplicate(true)
		rows.append(row.duplicate(true))
		by_cell[key] = rows
	return by_cell


func _active_preview_row(rows: Array) -> Dictionary:
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY and bool(Dictionary(row_value).get("isActiveActor", false)):
			return Dictionary(row_value).duplicate(true)
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY:
			return Dictionary(row_value).duplicate(true)
	return {}


func _board_preview_payload(row: Dictionary) -> Dictionary:
	if row.is_empty():
		return {}
	var payload := row.duplicate(true)
	payload["unit_id"] = String(payload.get("actorId", payload.get("unit_id", "")))
	payload["slot_index"] = int(payload.get("slotIndex", payload.get("slot_index", 0)))
	payload["slot_label"] = String(payload.get("slotLabel", payload.get("slot_label", "")))
	payload["shape_id"] = String(payload.get("shapeId", payload.get("shape_id", "")))
	payload["shape_name"] = String(payload.get("shapeName", payload.get("shape_name", "")))
	payload["direction_label"] = String(payload.get("directionLabel", payload.get("direction_label", "")))
	payload["target_unit_id"] = String(payload.get("targetId", payload.get("target_unit_id", "")))
	return payload


func _damage_projection(
	context: Dictionary,
	source: Dictionary,
	raw_damage: int,
	target: Dictionary,
	hits_enemy: bool,
	element: String = "",
	hp_override: Variant = null,
	shield_override: Variant = null,
	calculation_kind: String = "physical"
) -> Dictionary:
	var hp_from: int = max(0, int(hp_override)) if hp_override != null else max(0, int(target.get("hp", 0)))
	var shield_from: int = max(0, int(shield_override)) if shield_override != null else max(0, int(target.get("shield", 0)))
	var final_damage := 0
	if hits_enemy:
		var projected_target := target.duplicate(true)
		projected_target["hp"] = hp_from
		projected_target["shield"] = shield_from
		final_damage = int(_project_damage(
			context, source, projected_target, raw_damage, element,
			{"sourceType": "action_projection", "calculationKind": calculation_kind}
		).get("final", 0))
	var shield_damage: int = min(shield_from, final_damage)
	var hp_damage: int = min(hp_from, max(0, final_damage - shield_damage))
	return {
		"raw": raw_damage if hits_enemy else 0,
		"final": shield_damage + hp_damage,
		"hp_damage": hp_damage,
		"shield_damage": shield_damage,
		"hp_from": hp_from,
		"hp_to": max(0, hp_from - hp_damage),
		"shield_from": shield_from,
		"shield_to": max(0, shield_from - shield_damage),
		"killed": hits_enemy and hp_from > 0 and hp_from - hp_damage <= 0,
	}


func _preview_hit_index_for_target(targets: Array, target_id: String) -> int:
	for index in range(targets.size()):
		if String(Dictionary(targets[index]).get("id", "")) == target_id:
			return index
	return -1


func _preview_quality_damage_for_hit(
	context: Dictionary,
	attacker: Dictionary,
	option: Dictionary,
	targets: Array,
	target: Dictionary,
	hit_index: int,
	base_damage: int
) -> int:
	var damage: int = max(0, base_damage + int(_quality_hit_context_projector.call("cell_damage_delta", option, target)))
	if hit_index < 0:
		return damage
	var attacker_copy := attacker.duplicate(true)
	var quality_context := Dictionary(_quality_hit_context_projector.call(
		"build",
		attacker_copy,
		option,
		targets,
		target,
		hit_index,
		damage,
		_option_all_cells_occupied(context, option),
		_mark_matches_unit(Dictionary(Dictionary(attacker.get("quality_runtime", {})).get("marked_cell", {})), target)
	))
	quality_context["preview"] = true
	return int(_quality_effect_registry.call("effect_for_unit", attacker).call("modify_hit_damage", quality_context))


func _threat_grid_by_cell(context: Dictionary) -> Dictionary:
	var by_cell: Dictionary = {}
	if String(context.get("phase", "")) != "battle":
		return by_cell
	for enemy_value in Array(context.get("units", [])):
		if typeof(enemy_value) != TYPE_DICTIONARY:
			continue
		var enemy := Dictionary(enemy_value)
		if String(enemy.get("side", "")) != ENEMY or int(enemy.get("hp", 0)) <= 0:
			continue
		var target := _nearest_player(context, enemy)
		if target.is_empty():
			continue
		var distance: int = abs(int(enemy.get("x", 0)) - int(target.get("x", 0))) + abs(int(enemy.get("y", 0)) - int(target.get("y", 0)))
		var enemy_id := String(enemy.get("id", ""))
		var enemy_name := String(enemy.get("name", enemy_id))
		if distance == 1:
			var attack: int = max(0, _resolved_stat_value(context, enemy, "atk", {"hook": EffectHookIdsScript.THREAT_PROJECTION, "target": target}))
			var raw_damage := int(_project_damage(
				context, enemy, target, attack, String(enemy.get("element", "")),
				{"sourceType": "threat_projection"}
			).get("final", 0))
			var shield_from: int = max(0, int(target.get("shield", 0)))
			var hp_from: int = max(0, int(target.get("hp", 0)))
			var shield_damage: int = min(shield_from, raw_damage)
			var hp_damage: int = min(hp_from, max(0, raw_damage - shield_damage))
			var hit := {
				"targetId": String(target.get("id", "")),
				"targetName": String(target.get("name", target.get("id", ""))),
				"r": int(target.get("y", -1)), "c": int(target.get("x", -1)),
				"raw": raw_damage, "damage": raw_damage,
				"shieldDamage": shield_damage, "hpDamage": hp_damage,
				"lethal": hp_from > 0 and hp_from - hp_damage <= 0,
			}
			_threat_add_cell(context, by_cell, int(target.get("x", -1)), int(target.get("y", -1)), {
				"type": "attack", "unitId": enemy_id, "unitName": enemy_name,
				"targetId": String(target.get("id", "")),
				"damage": raw_damage, "threat": raw_damage,
				"lethal": bool(hit.get("lethal", false)), "hits": [hit],
				"actionIndex": 0, "actionLabel": "第1槽", "actionCount": 1,
				"totalDamage": raw_damage,
			})
		else:
			var step := _project_enemy_next_step(context, enemy, target)
			if step.is_empty():
				continue
			_threat_add_cell(context, by_cell, int(step.get("x", -1)), int(step.get("y", -1)), {
				"type": "move_path", "unitId": enemy_id, "unitName": enemy_name,
				"threat": 1, "finalMove": true,
			})
	return by_cell


func _threat_add_cell(context: Dictionary, by_cell: Dictionary, x: int, y: int, patch: Dictionary) -> void:
	if not _inside(context, x, y):
		return
	var key := _cell_key(x, y)
	var current := Dictionary(by_cell.get(key, {
		"r": y, "c": x, "x": x, "y": y,
		"type": String(patch.get("type", "attack")),
		"damage": 0, "threat": 0, "hits": [], "actionIndexes": [],
	})).duplicate(true)
	var before_damage := int(current.get("damage", 0))
	var before_threat := int(current.get("threat", 0))
	var hits := Array(current.get("hits", [])).duplicate(true)
	var action_indexes := Array(current.get("actionIndexes", [])).duplicate(true)
	for patch_key in patch.keys():
		current[patch_key] = patch[patch_key]
	current["damage"] = before_damage + int(patch.get("damage", 0))
	current["threat"] = before_threat + int(patch.get("threat", patch.get("damage", 0)))
	for hit in Array(patch.get("hits", [])):
		hits.append(hit)
	current["hits"] = hits
	if patch.has("actionIndex") and not action_indexes.has(int(patch.get("actionIndex", 0))):
		action_indexes.append(int(patch.get("actionIndex", 0)))
	current["actionIndexes"] = action_indexes
	if bool(patch.get("lethal", false)):
		current["lethal"] = true
	by_cell[key] = current


func _project_enemy_next_step(context: Dictionary, enemy: Dictionary, target: Dictionary) -> Dictionary:
	var ux := int(enemy.get("x", -1))
	var uy := int(enemy.get("y", -1))
	var tx := int(target.get("x", -1))
	var ty := int(target.get("y", -1))
	var next_x := ux
	var next_y := uy
	if abs(tx - ux) >= abs(ty - uy):
		next_x += int(sign(tx - ux))
	else:
		next_y += int(sign(ty - uy))
	if not _inside(context, next_x, next_y):
		return {}
	var occupant := _unit_at(context, next_x, next_y)
	if not occupant.is_empty() and String(occupant.get("id", "")) != String(enemy.get("id", "")):
		return {}
	return {"x": next_x, "y": next_y, "r": next_y, "c": next_x}


func _nearest_player(context: Dictionary, enemy: Dictionary) -> Dictionary:
	var living_players: Array = []
	for target_value in Array(context.get("units", [])):
		var target := Dictionary(target_value)
		if String(target.get("side", "")) != PLAYER or int(target.get("hp", 0)) <= 0:
			continue
		living_players.append(target)
	var taunt_candidates: Array = []
	if _mechanic_projection_service != null:
		taunt_candidates = Array(_mechanic_projection_service.call(
			"threat_candidates",
			Array(context.get("units", [])).duplicate(true),
			_battle_mechanisms(context),
			{"enemy": enemy.duplicate(true)}
		)).duplicate(true)
	var selection := Dictionary(_threat_target_policy.call(
		"select", enemy, living_players, _leader_for_side(context, PLAYER), taunt_candidates
	))
	return Dictionary(selection.get("target", {}))


func _preview_unit_for_action(context: Dictionary, action: Dictionary) -> Dictionary:
	var unit_id := String(action.get("unitId", ""))
	if unit_id == "": unit_id = String(action.get("unit_id", ""))
	if unit_id == "": unit_id = String(action.get("heroId", ""))
	if unit_id == "": unit_id = String(action.get("hero_id", ""))
	if unit_id == "": unit_id = String(action.get("id", ""))
	if unit_id != "":
		var requested := _unit_by_id(context, unit_id)
		if not requested.is_empty():
			return requested
	var selected := _selected_unit(context)
	if not selected.is_empty():
		return selected
	for candidate in Array(context.get("units", [])):
		var row := Dictionary(candidate)
		if String(row.get("side", "")) == PLAYER and int(row.get("hp", 0)) > 0:
			return row
	return {}


func _preview_slot_index_for_action(action: Dictionary, fallback_index: int, slot_count: int) -> int:
	if slot_count <= 0:
		return 0
	if action.has("slotId") or action.has("slot_id") or action.has("slotIndex") or action.has("slot_index") or action.has("index"):
		return clampi(_action_slot_index(action), 0, slot_count - 1)
	return clampi(fallback_index, 0, slot_count - 1)


func _preview_direction_for_action(context: Dictionary, action: Dictionary, unit: Dictionary, slot_index: int) -> String:
	var requested := String(action.get("dir", action.get("direction", ""))).strip_edges()
	if requested != "":
		return ShapeGeometryScript.normalize_direction(requested)
	return ShapeGeometryScript.normalize_direction(String(_action_slot_service.call(
		"stored_direction", unit, slot_index, Dictionary(context.get("actionDirections", {}))
	)))


func _preview_ap_for_action(context: Dictionary, action: Dictionary, unit: Dictionary, slot_index: int) -> int:
	var available_ap := int(Dictionary(context.get("selection", {})).get("ap", 0))
	if action.has("ap") or action.has("actionAp") or action.has("action_ap"):
		return clampi(max(1, _action_ap(action)), 1, max(1, available_ap))
	return int(_action_slot_service.call(
		"selected_ap", unit, slot_index, Dictionary(context.get("actionApChoices", {})), available_ap
	))


func _attack_option_for_direction(context: Dictionary, attacker: Dictionary, direction: String) -> Dictionary:
	var definition := SkillShapeRulesScript.shape_definition(attacker, Dictionary(context.get("gameData", {})))
	var upgrade := Dictionary(attacker.get("quality_upgrade", {}))
	var options := Array(_attack_option_service.call(
		"build_options",
		attacker,
		int(Dictionary(context.get("board", {})).get("width", 0)),
		int(Dictionary(context.get("board", {})).get("height", 0)),
		definition,
		_quality_effect_registry.call("effect_for_unit", attacker),
		String(upgrade.get("name", upgrade.get("id", "")))
	))
	return Dictionary(_attack_option_service.call("option_for_direction", options, direction))


func _enemies_in_attack_option(context: Dictionary, attacker: Dictionary, option: Dictionary) -> Array:
	var target_side := PLAYER if String(attacker.get("side", PLAYER)) == ENEMY else ENEMY
	var targets := Array(_targeting_service.call(
		"targets_in_option", attacker, option, Array(context.get("units", [])),
		_leader_for_side(context, target_side), target_side
	))
	_quality_effect_registry.call("effect_for_unit", attacker).call("sort_targets", targets, option)
	return targets


func _resolved_stat_value(context: Dictionary, unit: Dictionary, stat_id: String, query_context: Dictionary = {}) -> int:
	var hook := String(query_context.get("hook", EffectHookIdsScript.BATTLE))
	return int(_stat_query_service.call(
		"value", unit, Dictionary(context.get("gameData", {})), stat_id, hook, query_context
	))


func _option_all_cells_occupied(context: Dictionary, option: Dictionary) -> bool:
	for cell in Array(option.get("cells", [])):
		var row := Dictionary(cell)
		if _unit_at(context, int(row.get("x", -1)), int(row.get("y", -1))).is_empty():
			return false
	return true


func _mark_matches_unit(marked_cell: Dictionary, unit: Dictionary) -> bool:
	return (
		not marked_cell.is_empty()
		and int(marked_cell.get("x", marked_cell.get("c", -1))) == int(unit.get("x", -2))
		and int(marked_cell.get("y", marked_cell.get("r", -1))) == int(unit.get("y", -2))
	)


func _selected_action_slot(context: Dictionary, unit: Dictionary) -> Dictionary:
	var slots := _action_slots(context, unit)
	if slots.is_empty():
		return {}
	var index := clampi(int(Dictionary(context.get("selection", {})).get("slotIndex", 0)), 0, slots.size() - 1)
	return Dictionary(slots[index])


func _selected_unit(context: Dictionary) -> Dictionary:
	return _unit_by_id(context, String(Dictionary(context.get("selection", {})).get("unitId", "")))


func _unit_by_id(context: Dictionary, unit_id: String) -> Dictionary:
	for value in Array(context.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", "")) == unit_id:
			return unit
	return {}


func _unit_at(context: Dictionary, x: int, y: int) -> Dictionary:
	for value in Array(context.get("units", [])):
		var unit := Dictionary(value)
		if int(unit.get("hp", 0)) > 0 and int(unit.get("x", -1)) == x and int(unit.get("y", -1)) == y:
			return unit
	return {}


func _leader_for_side(context: Dictionary, side: String) -> Dictionary:
	var leaders := Dictionary(context.get("leaders", {}))
	return Dictionary(leaders.get("player" if side == PLAYER else "enemy", {}))


func _leader_at(context: Dictionary, x: int, y: int) -> Dictionary:
	for leader_value in Dictionary(context.get("leaders", {})).values():
		var leader := Dictionary(leader_value)
		if bool(leader.get("alive", false)) and int(leader.get("x", -1)) == x and int(leader.get("y", -1)) == y:
			return leader
	return {}


func _inside(context: Dictionary, x: int, y: int) -> bool:
	var board := Dictionary(context.get("board", {}))
	return x >= 0 and y >= 0 and x < int(board.get("width", 0)) and y < int(board.get("height", 0))


func _cell_elements_at(context: Dictionary, x: int, y: int) -> Dictionary:
	return ElementRulesScript.normalize_layers(Dictionary(
		Dictionary(context.get("cellElements", {})).get(_cell_key(x, y), {})
	))


func _board_trace_at(context: Dictionary, x: int, y: int) -> Dictionary:
	var value: Variant = Dictionary(context.get("boardTraces", {})).get(_cell_key(x, y), {})
	if typeof(value) == TYPE_ARRAY:
		var rows := Array(value)
		return {} if rows.is_empty() else Dictionary(rows[rows.size() - 1]).duplicate(true)
	return Dictionary(value).duplicate(true)


func _board_traces_at(context: Dictionary, x: int, y: int) -> Array:
	var value: Variant = Dictionary(context.get("boardTraces", {})).get(_cell_key(x, y), {})
	if typeof(value) == TYPE_ARRAY:
		return Array(value).duplicate(true)
	if typeof(value) == TYPE_DICTIONARY and not Dictionary(value).is_empty():
		return [Dictionary(value).duplicate(true)]
	return []


func _has_visible_elements(elements: Dictionary) -> bool:
	for element in elements.keys():
		if int(elements.get(element, 0)) > 0:
			return true
	return false


func _battle_mechanisms(context: Dictionary) -> Array:
	var battle := Dictionary(Dictionary(context.get("gameData", {})).get("battle", {}))
	return Array(battle.get("mechanisms", [])).duplicate(true)


func _action_slot_index(action: Dictionary) -> int:
	return int(action.get("slotId", action.get("slot_id", action.get("slotIndex", action.get("slot_index", action.get("index", 0))))))


func _action_ap(action: Dictionary) -> int:
	return int(action.get("ap", action.get("actionAp", action.get("action_ap", 0))))


func _request_x(request: Dictionary) -> int:
	if request.has("x"):
		return int(request["x"])
	if request.has("c"):
		return int(request["c"])
	if request.has("col"):
		return int(request["col"])
	var cell := Dictionary(request.get("cell", {}))
	if cell.is_empty():
		cell = Dictionary(request.get("to", {}))
	return int(cell.get("c", cell.get("x", -1)))


func _request_y(request: Dictionary) -> int:
	if request.has("y"):
		return int(request["y"])
	if request.has("r"):
		return int(request["r"])
	if request.has("row"):
		return int(request["row"])
	var cell := Dictionary(request.get("cell", {}))
	if cell.is_empty():
		cell = Dictionary(request.get("to", {}))
	return int(cell.get("r", cell.get("y", -1)))


func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]
