extends PanelContainer

signal command_requested(command: Dictionary)

@onready var title_label: Label = $Margin/Content/Title
@onready var summary_label: Label = $Margin/Content/Summary
@onready var reset_pets_button: Button = $Margin/Content/ResetPetsButton
@onready var action_slot_button: Button = $Margin/Content/ActionSlotButton
@onready var direction_button: Button = $Margin/Content/DirectionButton
@onready var action_ap_button: Button = $Margin/Content/ActionApButton
@onready var cast_button: Button = $Margin/Content/CastButton
@onready var all_out_button: Button = $Margin/Content/AllOutButton
@onready var end_turn_button: Button = $Margin/Content/EndTurnButton
@onready var monster_turn_button: Button = $Margin/Content/MonsterTurnButton

var _snapshot := {}


func _ready() -> void:
	reset_pets_button.pressed.connect(func(): _emit("RESET_PETS"))
	action_slot_button.pressed.connect(func(): _emit("SELECT_ACTION_SLOT"))
	direction_button.pressed.connect(func(): _emit("SET_ACTION_DIRECTION"))
	action_ap_button.pressed.connect(func(): _emit("SET_ACTION_AP"))
	cast_button.pressed.connect(func(): _emit("USE_ACTION_SLOT"))
	all_out_button.pressed.connect(func(): _emit("RUN_PLAYER_ALL_OUT"))
	end_turn_button.pressed.connect(func(): _emit("END_PLAYER_TURN"))
	monster_turn_button.pressed.connect(func(): _emit("RUN_MONSTER_TURN"))
	_apply_style()


func render_snapshot(snap: Dictionary) -> void:
	_snapshot = snap.duplicate(true)
	var selected_id := String(snap.get("selected_unit_id", snap.get("selectedUnitId", "")))
	var selected := _selected_unit(selected_id)
	var slots := Array(snap.get("selected_action_slots", snap.get("selectedActionSlots", [])))
	var slot_index := int(snap.get("selected_action_slot_index", snap.get("selectedActionSlotIndex", 0)))
	var slot := Dictionary(slots[slot_index]) if slot_index >= 0 and slot_index < slots.size() else {}
	title_label.text = "行动控制 · 回合%d" % int(snap.get("battle_round", 0))
	summary_label.text = "%s\n槽位 %d/%d · AP %d · 方向 %s" % [
		String(selected.get("name", selected_id if selected_id != "" else "未选中宠物")),
		slot_index + 1,
		slots.size(),
		int(slot.get("selected_ap", slot.get("selectedAp", snap.get("selected_action_ap", 0)))),
		_direction_label(String(slot.get("direction", "right")))
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
	action_slot_button.text = "切换行动槽（%d/%d）" % [slot_index + 1, slots.size()]
	direction_button.text = "调整方向：%s" % _direction_label(String(slot.get("direction", "right")))
	action_ap_button.text = "调整 AP：%d" % int(slot.get("selected_ap", slot.get("selectedAp", snap.get("selected_action_ap", 0))))
	cast_button.disabled = selected_id == "" or slots.is_empty()
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
	_apply_button_palette(reset_pets_button, Color("5c8a62"), true)
	_apply_button_palette(action_slot_button, Color("665638"), false)
	_apply_button_palette(direction_button, Color("665638"), false)
	_apply_button_palette(action_ap_button, Color("665638"), false)
	_apply_button_palette(cast_button, Color("9b6d2f"), true)
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
