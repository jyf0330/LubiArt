extends Control

signal map_selected(map_id: String)

const MAP_BUTTONS := {
	"lowland_evening": NodePath("Panel/Margin/Content/MapGrid/LowlandEvening"),
	"grassland_evening": NodePath("Panel/Margin/Content/MapGrid/GrasslandEvening"),
	"grassland_morning": NodePath("Panel/Margin/Content/MapGrid/GrasslandMorning"),
	"pond_evening": NodePath("Panel/Margin/Content/MapGrid/PondEvening"),
	"pond_morning": NodePath("Panel/Margin/Content/MapGrid/PondMorning"),
	"mountain_evening": NodePath("Panel/Margin/Content/MapGrid/MountainEvening"),
	"mountain_morning": NodePath("Panel/Margin/Content/MapGrid/MountainMorning"),
	"lowland_morning": NodePath("Panel/Margin/Content/MapGrid/LowlandMorning"),
	"forest_spring": NodePath("Panel/Margin/Content/MapGrid/ForestSpring"),
	"forest_autumn": NodePath("Panel/Margin/Content/MapGrid/ForestAutumn"),
	"mountain_new": NodePath("Panel/Margin/Content/MapGrid/NewMountain"),
}

@onready var dim_background: ColorRect = $DimBackground
@onready var close_button: Button = $Panel/Margin/Content/Header/CloseButton

var _current_map_id := "mountain_new"


func _ready() -> void:
	close_button.pressed.connect(close)
	dim_background.gui_input.connect(_on_dim_background_gui_input)
	for map_id in MAP_BUTTONS:
		var button := get_node(MAP_BUTTONS[map_id]) as TextureButton
		button.pressed.connect(_on_map_button_pressed.bind(String(map_id)))
	visible = false
	_refresh_selection()


func open(current_map_id: String) -> void:
	_current_map_id = current_map_id
	_refresh_selection()
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func get_current_map_id() -> String:
	return _current_map_id


func get_map_button_count() -> int:
	return MAP_BUTTONS.size()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_map_button_pressed(map_id: String) -> void:
	_current_map_id = map_id
	_refresh_selection()
	map_selected.emit(map_id)
	close()


func _on_dim_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()


func _refresh_selection() -> void:
	for map_id in MAP_BUTTONS:
		var button := get_node(MAP_BUTTONS[map_id]) as TextureButton
		var border := button.get_node("SelectionBorder") as Panel
		border.visible = String(map_id) == _current_map_id
