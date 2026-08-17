extends PanelContainer

signal command_requested(command: Dictionary)

const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")
const BattleCommandBuilderScript := preload("res://core_ui/scripts/battle/controllers/battle_command_builder.gd")
const BattleSnapshotView := preload("res://core_ui/scripts/battle/controllers/battle_snapshot_view.gd")

const STATE_SELECT := &"select"
const STATE_PREVIEW := &"preview"
const STATE_EXECUTING := &"executing"
const STATE_RESULT := &"result"

@onready var title_label: Label = $Margin/Content/Title
@onready var flow_state_label: Label = $Margin/Content/FlowState
@onready var summary_label: Label = $Margin/Content/Summary
@onready var reset_pets_button: Button = $Margin/Content/ResetPetsButton
@onready var skill_queue_title: Label = $Margin/Content/SkillQueueTitle
@onready var skill_queue_grid: GridContainer = $Margin/Content/SkillQueueGrid
@onready var all_out_button: Button = $Margin/Content/AllOutButton
@onready var end_turn_button: Button = $Margin/Content/EndTurnButton
@onready var monster_turn_button: Button = $Margin/Content/MonsterTurnButton

var _snapshot := {}
var _picked_skill_index := -1
var _trace_cursor := -1
var _latest_result_text := ""
var _input_locked := false
var _commands := BattleCommandBuilderScript.new()


func _ready() -> void:
	RuntimeUiPolicy.install()
	reset_pets_button.pressed.connect(func(): _emit("RESET_PETS"))
	for child in skill_queue_grid.get_children():
		child.move_requested.connect(_move_skill)
		child.slot_pressed.connect(_pick_or_move_skill)
	all_out_button.pressed.connect(func(): _emit("RUN_COMBAT_ROUND"))
	end_turn_button.pressed.connect(func(): _emit("END_PLAYER_TURN"))
	monster_turn_button.pressed.connect(func(): _emit("RUN_MONSTER_TURN"))
	_configure_focus_navigation()
	_apply_style()
	_refresh_visual_state()


func render_snapshot(snap: Dictionary) -> void:
	_snapshot = snap
	_update_result_feedback(snap)
	var selected_id := BattleSnapshotView.selected_unit_id(snap)
	var selected := _selected_unit(selected_id)
	var queue := BattleSnapshotView.skill_control_bar(snap)
	title_label.text = RuntimeUiPolicy.text("UI_ACTION_TITLE", [int(snap.get("battle_round", 0))])
	var summary_lines := [
		String(selected.get("name", selected_id if selected_id != "" else RuntimeUiPolicy.text("UI_ACTION_NO_SELECTION"))),
		_preview_summary(snap, selected_id, queue),
	]
	if _latest_result_text != "":
		summary_lines.append(_latest_result_text)
	summary_label.text = "\n".join(PackedStringArray(summary_lines))
	var reset_state := BattleSnapshotView.player_reset_state(snap)
	var reset_ready := bool(reset_state.get("eligible", false))
	var alive_threshold := int(reset_state.get("aliveThreshold", 2))
	var reset_charges := int(reset_state.get("charges", 0))
	var next_charge_round := int(reset_state.get("nextChargeRound", 5))
	var rounds_until_next_charge := int(reset_state.get(
		"roundsUntilNextCharge",
		reset_state.get("cooldownRemaining", 0)
	))
	if reset_ready:
		reset_pets_button.text = RuntimeUiPolicy.text("UI_ACTION_RESET_READY", [reset_charges])
	elif reset_charges > 0:
		reset_pets_button.text = RuntimeUiPolicy.text("UI_ACTION_RESET_THRESHOLD", [alive_threshold, reset_charges])
	else:
		reset_pets_button.text = RuntimeUiPolicy.text("UI_ACTION_RESET_WAIT", [next_charge_round, rounds_until_next_charge])
	var skill_catalog := Dictionary(snap.get("skill_catalog", {}))
	for index in range(skill_queue_grid.get_child_count()):
		var entry := Dictionary(queue[index]) if index < queue.size() else {}
		var skill_id := String(entry.get("skillId", entry.get("skill_id", "")))
		if String(entry.get("label", "")).strip_edges() == "" and skill_id != "":
			entry["label"] = String(Dictionary(skill_catalog.get(skill_id, {})).get("name", skill_id))
		skill_queue_grid.get_child(index).configure(index, entry)
	all_out_button.text = RuntimeUiPolicy.text("UI_ACTION_ALL_OUT")
	end_turn_button.text = RuntimeUiPolicy.text("UI_ACTION_END_TURN")
	monster_turn_button.text = RuntimeUiPolicy.text("UI_ACTION_MONSTER_TURN")
	visible = String(snap.get("phase", "")) == "battle"
	_apply_control_availability()
	_refresh_skill_queue_title()
	_refresh_skill_slot_states()
	_refresh_visual_state()
	call_deferred("_grab_initial_focus")


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	_apply_control_availability()
	_refresh_skill_queue_title()
	_refresh_skill_slot_states()
	_refresh_visual_state()


func is_input_locked() -> bool:
	return _input_locked


func focus_default() -> void:
	if _input_locked or not is_visible_in_tree():
		return
	for child in skill_queue_grid.get_children():
		var button := child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return
	for button in [reset_pets_button, all_out_button, end_turn_button, monster_turn_button]:
		if not button.disabled:
			button.grab_focus()
			return


func focus_navigation_summary() -> Dictionary:
	var result := {}
	for button in _focus_controls():
		result[String(button.name)] = {
			"left": String(button.focus_neighbor_left),
			"right": String(button.focus_neighbor_right),
			"top": String(button.focus_neighbor_top),
			"bottom": String(button.focus_neighbor_bottom),
			"next": String(button.focus_next),
			"previous": String(button.focus_previous),
		}
	return result


func feedback_text() -> String:
	return summary_label.text


func visual_state_summary() -> Dictionary:
	return {
		"state": String(_visual_state()),
		"flow_text": flow_state_label.text,
		"picked_skill_index": _picked_skill_index,
		"accent": _state_accent(_visual_state()).to_html(false),
	}


func _emit(command_type: String) -> void:
	var command := Dictionary(_commands.build(command_type, _snapshot))
	if not command.is_empty():
		command_requested.emit(command)


func _move_skill(from_index: int, to_index: int) -> void:
	if _input_locked:
		return
	var queue := BattleSnapshotView.skill_control_bar(_snapshot)
	if from_index < 0 or from_index >= queue.size() or to_index < 0 or to_index >= queue.size():
		return
	var ordered_ids: Array = []
	for entry_value in queue:
		var entry := Dictionary(entry_value)
		ordered_ids.append(String(entry.get("entryId", entry.get("entry_id", ""))))
	var moved: Variant = ordered_ids.pop_at(from_index)
	ordered_ids.insert(to_index, moved)
	command_requested.emit(_commands.set_skill_control_order(ordered_ids))
	_picked_skill_index = -1
	_latest_result_text = ""
	_refresh_skill_queue_title()
	_refresh_skill_slot_states()
	_refresh_visual_state()


func _pick_or_move_skill(index: int) -> void:
	if _input_locked:
		return
	_latest_result_text = ""
	if _picked_skill_index < 0:
		_picked_skill_index = index
	elif _picked_skill_index == index:
		_picked_skill_index = -1
	else:
		_move_skill(_picked_skill_index, index)
		return
	_refresh_skill_queue_title()
	_refresh_skill_slot_states()
	_refresh_visual_state()


func _preview_summary(snap: Dictionary, selected_id: String, queue: Array) -> String:
	if selected_id == "":
		return RuntimeUiPolicy.text("UI_ACTION_SELECT_PET")
	var cells := Array(snap.get("selected_action_cells", snap.get("selectedActionCells", [])))
	return RuntimeUiPolicy.text("UI_ACTION_PREVIEW", [cells.size(), queue.size()])


func _update_result_feedback(snap: Dictionary) -> void:
	var events := Array(snap.get("battleTrace", snap.get("battle_trace", [])))
	if _trace_cursor < 0 or events.size() < _trace_cursor:
		_trace_cursor = events.size()
		_latest_result_text = ""
		return
	if events.size() == _trace_cursor:
		return
	var skill_count := 0
	var combo_count := 0
	var final_damage := 0
	var hp_damage := 0
	var shield_damage := 0
	for index in range(_trace_cursor, events.size()):
		var event := Dictionary(events[index])
		match String(event.get("type", "")):
			"SKILL_TRIGGERED":
				skill_count += 1
			"SKILL_COMBO_TRIGGERED":
				combo_count += 1
			"DAMAGE_APPLIED":
				var payload := Dictionary(event.get("payload", {}))
				final_damage += int(payload.get("finalDamage", 0))
				hp_damage += int(payload.get("hpDamage", 0))
				shield_damage += int(payload.get("shieldDamage", 0))
	_trace_cursor = events.size()
	var parts: Array[String] = []
	if skill_count > 0:
		parts.append(RuntimeUiPolicy.text("UI_ACTION_SKILL_COUNT", [skill_count]))
	if combo_count > 0:
		parts.append(RuntimeUiPolicy.text("UI_ACTION_COMBO_COUNT", [combo_count]))
	if final_damage > 0:
		parts.append(RuntimeUiPolicy.text("UI_ACTION_DAMAGE", [final_damage, hp_damage, shield_damage]))
	if not parts.is_empty():
		_latest_result_text = RuntimeUiPolicy.text("UI_ACTION_RESULT", [" · ".join(PackedStringArray(parts))])


func _apply_control_availability() -> void:
	if not is_node_ready():
		return
	var phase_is_battle := String(_snapshot.get("phase", "")) == "battle"
	var queue := BattleSnapshotView.skill_control_bar(_snapshot)
	var reset_state := BattleSnapshotView.player_reset_state(_snapshot)
	reset_pets_button.disabled = _input_locked or not phase_is_battle or not bool(reset_state.get("eligible", false))
	for child in skill_queue_grid.get_children():
		var skill_id := String(child.get("skill_id")) if child.get("skill_id") != null else ""
		(child as Button).disabled = _input_locked or not phase_is_battle or skill_id == ""
	all_out_button.disabled = _input_locked or not phase_is_battle or queue.is_empty()
	end_turn_button.disabled = _input_locked or not phase_is_battle
	monster_turn_button.disabled = _input_locked or not phase_is_battle


func _refresh_skill_queue_title() -> void:
	if _input_locked:
		skill_queue_title.text = RuntimeUiPolicy.text("UI_ACTION_EXECUTING")
	elif _picked_skill_index >= 0:
		skill_queue_title.text = RuntimeUiPolicy.text("UI_ACTION_PICKED", [_picked_skill_index + 1])
	else:
		skill_queue_title.text = RuntimeUiPolicy.text("UI_ACTION_QUEUE_HINT")


func _refresh_skill_slot_states() -> void:
	if not is_node_ready():
		return
	for index in range(skill_queue_grid.get_child_count()):
		var button := skill_queue_grid.get_child(index) as Button
		var picked := index == _picked_skill_index
		if button.has_method("set_picked"):
			button.call("set_picked", picked)
		_apply_button_palette(button, Color("b78337") if picked else Color("665638"), picked)
		if picked:
			button.add_theme_stylebox_override("normal", _flat_style(Color("513813"), Color("ffd77a"), 3, 7))
			button.add_theme_color_override("font_color", Color("fff4ca"))


func _refresh_visual_state() -> void:
	if not is_node_ready():
		return
	var state := _visual_state()
	var accent := _state_accent(state)
	match state:
		STATE_EXECUTING:
			flow_state_label.text = RuntimeUiPolicy.text("UI_ACTION_FLOW_EXECUTING")
		STATE_RESULT:
			flow_state_label.text = RuntimeUiPolicy.text("UI_ACTION_FLOW_RESULT")
		STATE_PREVIEW:
			flow_state_label.text = RuntimeUiPolicy.text("UI_ACTION_FLOW_PREVIEW")
		_:
			flow_state_label.text = RuntimeUiPolicy.text("UI_ACTION_FLOW_SELECT")
	add_theme_stylebox_override("panel", _panel_style(accent))
	title_label.add_theme_color_override("font_color", accent.lightened(0.42))
	flow_state_label.add_theme_color_override("font_color", Color("fff8e5"))
	flow_state_label.add_theme_stylebox_override("normal", _flat_style(accent.darkened(0.64), accent.lightened(0.16), 2, 8, 8.0))
	summary_label.add_theme_stylebox_override("normal", _flat_style(Color(0.12, 0.09, 0.055, 0.94), accent.darkened(0.15), 2 if state != STATE_SELECT else 1, 7, 8.0))
	skill_queue_title.add_theme_color_override("font_color", accent.lightened(0.25) if _input_locked else Color("e8c77a"))


func _visual_state() -> StringName:
	if _input_locked:
		return STATE_EXECUTING
	if _latest_result_text != "":
		return STATE_RESULT
	var selected_id := String(_snapshot.get("selected_unit_id", _snapshot.get("selectedUnitId", "")))
	return STATE_PREVIEW if selected_id != "" else STATE_SELECT


func _state_accent(state: StringName) -> Color:
	match state:
		STATE_PREVIEW:
			return Color("63b6d2")
		STATE_EXECUTING:
			return Color("e59a42")
		STATE_RESULT:
			return Color("73bd78")
		_:
			return Color("c6a15e")


func _grab_initial_focus() -> void:
	if get_viewport().gui_get_focus_owner() == null:
		focus_default()


func _configure_focus_navigation() -> void:
	var slots: Array[Button] = []
	for child in skill_queue_grid.get_children():
		var button := child as Button
		button.focus_mode = Control.FOCUS_ALL
		slots.append(button)
	for button in [reset_pets_button, all_out_button, end_turn_button, monster_turn_button]:
		button.focus_mode = Control.FOCUS_ALL
	_set_directional_neighbors(reset_pets_button, reset_pets_button, reset_pets_button, reset_pets_button, slots[0])
	for index in range(slots.size()):
		var column := index % 2
		var top := reset_pets_button if index < 2 else slots[index - 2]
		var bottom := all_out_button if index >= slots.size() - 2 else slots[index + 2]
		var left := slots[index - 1] if column == 1 else slots[index]
		var right := slots[index + 1] if column == 0 else slots[index]
		_set_directional_neighbors(slots[index], left, right, top, bottom)
	_set_directional_neighbors(all_out_button, all_out_button, all_out_button, slots[slots.size() - 2], end_turn_button)
	_set_directional_neighbors(end_turn_button, end_turn_button, end_turn_button, all_out_button, monster_turn_button)
	_set_directional_neighbors(monster_turn_button, monster_turn_button, monster_turn_button, end_turn_button, monster_turn_button)
	var ordered := _focus_controls()
	for index in range(ordered.size()):
		var previous := ordered[(index - 1 + ordered.size()) % ordered.size()]
		var next := ordered[(index + 1) % ordered.size()]
		ordered[index].focus_previous = ordered[index].get_path_to(previous)
		ordered[index].focus_next = ordered[index].get_path_to(next)


func _set_directional_neighbors(control: Control, left: Control, right: Control, top: Control, bottom: Control) -> void:
	control.focus_neighbor_left = control.get_path_to(left)
	control.focus_neighbor_right = control.get_path_to(right)
	control.focus_neighbor_top = control.get_path_to(top)
	control.focus_neighbor_bottom = control.get_path_to(bottom)


func _focus_controls() -> Array[Button]:
	var controls: Array[Button] = [reset_pets_button]
	for child in skill_queue_grid.get_children():
		controls.append(child as Button)
	controls.append(all_out_button)
	controls.append(end_turn_button)
	controls.append(monster_turn_button)
	return controls


func _selected_unit(id: String) -> Dictionary:
	for value in Array(_snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", unit.get("unitId", ""))) == id:
			return unit
	return {}


func _selected_ap() -> int:
	var slots := Array(_snapshot.get("selected_action_slots", _snapshot.get("selectedActionSlots", [])))
	var index := int(_snapshot.get("selected_action_slot_index", _snapshot.get("selectedActionSlotIndex", 0)))
	if index >= 0 and index < slots.size():
		return int(Dictionary(slots[index]).get("selected_ap", Dictionary(slots[index]).get("selectedAp", 1)))
	return 1


func _next_ap() -> int:
	var ap_left: int = max(1, int(_snapshot.get("ap", 1)))
	var current := _selected_ap()
	return 1 if current >= ap_left else current + 1


func _next_direction() -> String:
	var directions := ["right", "down", "left", "up"]
	var slots := Array(_snapshot.get("selected_action_slots", _snapshot.get("selectedActionSlots", [])))
	var index := int(_snapshot.get("selected_action_slot_index", _snapshot.get("selectedActionSlotIndex", 0)))
	var current := String(Dictionary(slots[index]).get("direction", "right")) if index >= 0 and index < slots.size() else "right"
	return directions[(directions.find(current) + 1) % directions.size()]


func _direction_label(direction: String) -> String:
	return {"right": "向右", "down": "向下", "left": "向左", "up": "向上"}.get(direction, direction)


func _apply_style() -> void:
	add_theme_stylebox_override("panel", _panel_style(_state_accent(STATE_SELECT)))
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("ffe8b0"))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.055, 0.025, 0.95))
	flow_state_label.add_theme_font_size_override("font_size", 16)
	flow_state_label.add_theme_constant_override("outline_size", 2)
	flow_state_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.9))
	summary_label.add_theme_font_size_override("font_size", 18)
	summary_label.add_theme_color_override("font_color", Color("f2ead7"))
	skill_queue_title.add_theme_font_size_override("font_size", 17)
	skill_queue_title.add_theme_color_override("font_color", Color("e8c77a"))
	_apply_button_palette(reset_pets_button, Color("5c8a62"), true)
	_refresh_skill_slot_states()
	_apply_button_palette(all_out_button, Color("9b4938"), true)
	_apply_button_palette(end_turn_button, Color("615944"), false)
	_apply_button_palette(monster_turn_button, Color("615944"), false)


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := _flat_style(Color(0.055, 0.043, 0.03, 0.96), accent, 3, 12, 0.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 8
	return style


func _apply_button_palette(button: Button, accent: Color, emphasized: bool) -> void:
	button.add_theme_font_size_override("font_size", 18 if emphasized else 17)
	button.add_theme_color_override("font_color", Color("fff2d0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("ffe39a"))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.67, 0.64, 0.57, 0.72))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_color_override("font_outline_color", Color(0.05, 0.035, 0.02, 0.9))
	button.add_theme_stylebox_override("normal", _flat_style(accent.darkened(0.48), accent.lightened(0.18), 1 if not emphasized else 2, 7))
	button.add_theme_stylebox_override("hover", _flat_style(accent.darkened(0.28), accent.lightened(0.35), 2, 7))
	button.add_theme_stylebox_override("pressed", _flat_style(accent.darkened(0.58), Color("ffe09a"), 2, 7))
	var focus_style := _flat_style(accent.darkened(0.32), Color("fff1b5"), 3, 7)
	focus_style.expand_margin_left = 2.0
	focus_style.expand_margin_top = 2.0
	focus_style.expand_margin_right = 2.0
	focus_style.expand_margin_bottom = 2.0
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_stylebox_override("disabled", _flat_style(Color(0.1, 0.09, 0.075, 0.62), Color(0.3, 0.27, 0.22, 0.55), 1, 7))


func _flat_style(background: Color, border: Color, border_width: int, radius: int, horizontal_padding: float = 6.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
