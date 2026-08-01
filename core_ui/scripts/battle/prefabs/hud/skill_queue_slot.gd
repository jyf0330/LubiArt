extends Button

signal move_requested(from_index: int, to_index: int)
signal slot_pressed(index: int)

const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")

var queue_index := -1
var skill_id := ""
var _picked := false


func _ready() -> void:
	RuntimeUiPolicy.install()
	pressed.connect(func(): slot_pressed.emit(queue_index))


func configure(index: int, entry: Dictionary) -> void:
	queue_index = index
	skill_id = String(entry.get("skillId", entry.get("skill_id", "")))
	var label := String(entry.get("label", "")).strip_edges()
	if label == "":
		label = skill_id
	text = "%d  %s" % [index + 1, label]
	tooltip_text = RuntimeUiPolicy.text("UI_ACTION_SKILL_TOOLTIP")
	disabled = skill_id == ""


func set_picked(picked: bool) -> void:
	_picked = picked
	set_meta("battle_action_picked", picked)


func is_picked() -> bool:
	return _picked


func _get_drag_data(_at_position: Vector2) -> Variant:
	if skill_id == "":
		return null
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 18)
	preview.add_theme_color_override("font_color", Color("fff2d0"))
	set_drag_preview(preview)
	return {"kind": "skill_queue", "from_index": queue_index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary \
		and String(Dictionary(data).get("kind", "")) == "skill_queue" \
		and int(Dictionary(data).get("from_index", -1)) != queue_index


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	move_requested.emit(int(Dictionary(data).get("from_index", -1)), queue_index)
