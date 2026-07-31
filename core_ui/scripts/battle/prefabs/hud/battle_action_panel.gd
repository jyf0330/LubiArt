extends PanelContainer

signal command_requested(command: Dictionary)

@onready var title_label: Label = $Margin/Content/Title
@onready var summary_label: Label = $Margin/Content/Summary
@onready var reset_pets_button: Button = $Margin/Content/ResetPetsButton
@onready var skill_queue_title: Label = $Margin/Content/SkillQueueTitle
@onready var skill_queue_grid: GridContainer = $Margin/Content/SkillQueueGrid
@onready var all_out_button: Button = $Margin/Content/AllOutButton
@onready var end_turn_button: Button = $Margin/Content/EndTurnButton
@onready var monster_turn_button: Button = $Margin/Content/MonsterTurnButton

var _snapshot := {}
var _picked_skill_index := -1


func _ready() -> void:
	reset_pets_button.pressed.connect(func(): _emit("RESET_PETS"))
	for child in skill_queue_grid.get_children():
		child.move_requested.connect(_move_skill)
		child.slot_pressed.connect(_pick_or_move_skill)
	all_out_button.pressed.connect(func(): _emit("RUN_PLAYER_ALL_OUT"))
	end_turn_button.pressed.connect(func(): _emit("END_PLAYER_TURN"))
	monster_turn_button.pressed.connect(func(): _emit("RUN_MONSTER_TURN"))
	_apply_style()


func render_snapshot(snap: Dictionary) -> void:
	_snapshot = snap.duplicate(true)
	var selected_id := String(snap.get("selected_unit_id", snap.get("selectedUnitId", "")))
	var selected := _selected_unit(selected_id)
	var queue := Array(snap.get("selectedSkillQueue", snap.get("selected_skill_queue", [])))
	title_label.text = "行动控制 · 回合%d" % int(snap.get("battle_round", 0))
	summary_label.text = "%s\n%d 个技能 · 从左到右触发" % [
		String(selected.get("name", selected_id if selected_id != "" else "未选中宠物")),
		queue.size(),
	]
	var reset_state := Dictionary(Dictionary(snap.get("pet_reset", {})).get("player", {}))
	var reset_ready := bool(reset_state.get("eligible", false))
	var reset_count := int(reset_state.get("resetCount", 0))
	var alive_threshold := int(reset_state.get("aliveThreshold", 2))
	var reset_charges := int(reset_state.get("charges", 0))
	var next_charge_round := int(reset_state.get("nextChargeRound", 5))
	var cooldown_remaining := int(reset_state.get("cooldownRemaining", 0))
	reset_pets_button.disabled = not reset_ready
	if reset_ready:
		reset_pets_button.text = "重置宠物（可用%d次）" % reset_charges
	elif reset_charges > 0:
		reset_pets_button.text = "重置宠物（需存活≤%d，次数%d）" % [alive_threshold, reset_charges]
	else:
		reset_pets_button.text = "重置宠物（第%d回合+1次，等%d回合）" % [next_charge_round, cooldown_remaining]
	var skill_catalog := Dictionary(snap.get("skill_catalog", {}))
	for index in range(skill_queue_grid.get_child_count()):
		var entry := Dictionary(queue[index]) if index < queue.size() else {}
		var skill_id := String(entry.get("skillId", entry.get("skill_id", "")))
		if String(entry.get("label", "")).strip_edges() == "" and skill_id != "":
			entry["label"] = String(Dictionary(skill_catalog.get(skill_id, {})).get("name", skill_id))
		skill_queue_grid.get_child(index).configure(index, entry)
	skill_queue_title.text = "技能行动条 · 拖拽排序"
	all_out_button.text = "按顺序触发全部技能"
	all_out_button.disabled = selected_id == "" or queue.is_empty()
	visible = String(snap.get("phase", "")) == "battle"


func _emit(command_type: String) -> void:
	var selected_id := String(_snapshot.get("selected_unit_id", _snapshot.get("selectedUnitId", "")))
	var slot_index := int(_snapshot.get("selected_action_slot_index", _snapshot.get("selectedActionSlotIndex", 0)))
	match command_type:
		"SELECT_ACTION_SLOT":
			var slots := Array(_snapshot.get("selected_action_slots", _snapshot.get("selectedActionSlots", [])))
			command_requested.emit({"type": command_type, "slotId": (slot_index + 1) % max(1, slots.size())})
		"SET_ACTION_DIRECTION":
			command_requested.emit({"type": command_type, "unitId": selected_id, "slotId": slot_index, "dir": _next_direction()})
		"SET_ACTION_AP":
			command_requested.emit({"type": command_type, "unitId": selected_id, "slotId": slot_index, "ap": _next_ap()})
		"USE_ACTION_SLOT":
			command_requested.emit({"type": command_type, "unitId": selected_id, "slotId": slot_index, "ap": _selected_ap()})
		_:
			command_requested.emit({"type": command_type})


func _move_skill(from_index: int, to_index: int) -> void:
	var queue := Array(_snapshot.get("selectedSkillQueue", _snapshot.get("selected_skill_queue", [])))
	if from_index < 0 or from_index >= queue.size() or to_index < 0 or to_index >= queue.size():
		return
	var ordered_ids: Array = []
	for entry_value in queue:
		var entry := Dictionary(entry_value)
		ordered_ids.append(String(entry.get("skillId", entry.get("skill_id", ""))))
	var moved: Variant = ordered_ids.pop_at(from_index)
	ordered_ids.insert(to_index, moved)
	command_requested.emit({
		"type": "SET_SKILL_ORDER",
		"unitId": String(_snapshot.get("selected_unit_id", _snapshot.get("selectedUnitId", ""))),
		"orderedSkillIds": ordered_ids,
	})
	_picked_skill_index = -1


func _pick_or_move_skill(index: int) -> void:
	if _picked_skill_index < 0:
		_picked_skill_index = index
		skill_queue_title.text = "已选第%d格 · 再点目标格移动" % (index + 1)
		return
	if _picked_skill_index == index:
		_picked_skill_index = -1
		skill_queue_title.text = "技能行动条 · 拖拽排序"
		return
	_move_skill(_picked_skill_index, index)


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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.043, 0.03, 0.94)
	style.border_color = Color(0.8, 0.6, 0.28, 0.95)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", style)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("ffe8b0"))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.055, 0.025, 0.95))
	summary_label.add_theme_font_size_override("font_size", 18)
	summary_label.add_theme_color_override("font_color", Color("f2ead7"))
	summary_label.add_theme_stylebox_override("normal", _flat_style(Color(0.12, 0.09, 0.055, 0.9), Color(0.55, 0.4, 0.2, 0.85), 1, 7, 8.0))
	skill_queue_title.add_theme_font_size_override("font_size", 17)
	skill_queue_title.add_theme_color_override("font_color", Color("e8c77a"))
	_apply_button_palette(reset_pets_button, Color("5c8a62"), true)
	for child in skill_queue_grid.get_children():
		_apply_button_palette(child as Button, Color("665638"), false)
	_apply_button_palette(all_out_button, Color("9b4938"), true)
	_apply_button_palette(end_turn_button, Color("615944"), false)
	_apply_button_palette(monster_turn_button, Color("615944"), false)


func _apply_button_palette(button: Button, accent: Color, emphasized: bool) -> void:
	button.add_theme_font_size_override("font_size", 18 if emphasized else 17)
	button.add_theme_color_override("font_color", Color("fff2d0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("ffe39a"))
	button.add_theme_color_override("font_disabled_color", Color(0.67, 0.64, 0.57, 0.72))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_color_override("font_outline_color", Color(0.05, 0.035, 0.02, 0.9))
	button.add_theme_stylebox_override("normal", _flat_style(accent.darkened(0.48), accent.lightened(0.18), 1 if not emphasized else 2, 7))
	button.add_theme_stylebox_override("hover", _flat_style(accent.darkened(0.28), accent.lightened(0.35), 2, 7))
	button.add_theme_stylebox_override("pressed", _flat_style(accent.darkened(0.58), Color("ffe09a"), 2, 7))
	button.add_theme_stylebox_override("focus", _flat_style(accent.darkened(0.4), Color("ffe09a"), 2, 7))
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
