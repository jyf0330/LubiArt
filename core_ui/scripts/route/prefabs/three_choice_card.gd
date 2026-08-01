@tool
extends Control

@export_range(0, 2, 1) var slot_index := 1:
	set(value):
		slot_index = int(clamp(value, 0, SLOT_LAYOUTS.size() - 1))
		_apply_slot_layout()

@export_group("Manual Layout")
@export var content_offset := Vector2(-10.0, 0.0):
	set(value):
		content_offset = value
		_apply_slot_layout()
@export var portrait_offset := Vector2.ZERO:
	set(value):
		portrait_offset = value
		_apply_slot_layout()
@export var icon_offset := Vector2.ZERO:
	set(value):
		icon_offset = value
		_apply_slot_layout()
@export var incense_burner_offset := Vector2.ZERO:
	set(value):
		incense_burner_offset = value
		_apply_slot_layout()
@export var hover_smoke_offset := Vector2.ZERO:
	set(value):
		hover_smoke_offset = value
		_apply_slot_layout()
@export var route_highlight_offset := Vector2.ZERO:
	set(value):
		route_highlight_offset = value
		_apply_slot_layout()

const SLOT_LAYOUTS := [
	{
		"highlight": Rect2(-27.0, 0.0, 292.0, 417.0),
		"portrait": Rect2(12.0, 71.0, 218.0, 192.0),
		"icon": Rect2(110.0, 0.0, 40.0, 62.0),
		"smoke": Rect2(16.0, 115.0, 119.0, 151.0),
		"burner": Rect2(75.0, 258.0, 110.0, 118.0),
	},
	{
		"highlight": Rect2(-29.0, 0.0, 299.0, 414.0),
		"portrait": Rect2(57.0, 76.0, 120.0, 195.0),
		"icon": Rect2(107.0, 0.0, 40.0, 62.0),
		"smoke": Rect2(20.0, 115.0, 119.0, 151.0),
		"burner": Rect2(75.0, 258.0, 110.0, 118.0),
	},
	{
		"highlight": Rect2(-24.0, 0.0, 295.0, 412.0),
		"portrait": Rect2(60.0, 82.0, 147.0, 183.0),
		"icon": Rect2(110.0, 0.0, 40.0, 62.0),
		"smoke": Rect2(11.0, 115.0, 119.0, 151.0),
		"burner": Rect2(75.0, 258.0, 110.0, 118.0),
	},
]
const ROUTE_HIGHLIGHT_TEXTURES := [
	preload("res://art/images/route/three_choice_psd/route_highlight_1.png"),
	preload("res://art/images/route/three_choice_psd/route_highlight_2.png"),
	preload("res://art/images/route/three_choice_psd/route_highlight_3.png"),
]


func _ready() -> void:
	_apply_slot_layout()


func set_slot_index(index: int) -> void:
	slot_index = index


func set_portrait(texture: Texture2D) -> void:
	var portrait := get_node_or_null("Portrait") as TextureRect
	if portrait != null:
		portrait.texture = texture


func set_kind_icon(texture: Texture2D) -> void:
	var icon := get_node_or_null("KindIcon") as TextureRect
	if icon != null:
		icon.texture = texture


func set_route_highlight(texture: Texture2D) -> void:
	var highlight := get_node_or_null("RouteHighlight") as TextureRect
	if highlight != null:
		highlight.texture = texture


func set_hovered(is_hovered: bool) -> void:
	var smoke := get_node_or_null("HoverSmoke") as CanvasItem
	if smoke != null:
		smoke.visible = is_hovered
	var highlight := get_node_or_null("RouteHighlight") as CanvasItem
	if highlight != null:
		highlight.visible = is_hovered


func clear() -> void:
	set_portrait(null)
	set_route_highlight(null)
	set_hovered(false)


func _apply_slot_layout() -> void:
	var layout := Dictionary(SLOT_LAYOUTS[slot_index])
	_apply_rect(get_node_or_null("RouteHighlight") as Control, Rect2(layout["highlight"]), route_highlight_offset)
	_apply_rect(get_node_or_null("Portrait") as Control, Rect2(layout["portrait"]), portrait_offset)
	_apply_rect(get_node_or_null("KindIcon") as Control, Rect2(layout["icon"]), icon_offset)
	_apply_rect(get_node_or_null("HoverSmoke") as Control, Rect2(layout["smoke"]), hover_smoke_offset)
	_apply_rect(get_node_or_null("IncenseBurner") as Control, Rect2(layout["burner"]), incense_burner_offset)
	_apply_slot_route_highlight_texture()


func _apply_rect(node: Control, rect: Rect2, manual_offset: Vector2) -> void:
	if node == null:
		return
	node.position = rect.position + content_offset + manual_offset
	node.size = rect.size


func _apply_slot_route_highlight_texture() -> void:
	var highlight := get_node_or_null("RouteHighlight") as TextureRect
	if highlight == null:
		return
	highlight.texture = ROUTE_HIGHLIGHT_TEXTURES[slot_index]
