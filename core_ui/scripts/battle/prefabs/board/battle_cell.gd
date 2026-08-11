@tool
extends Panel

signal cell_selected(x: int, y: int)
signal cell_pressed(x: int, y: int)
signal cell_released(x: int, y: int)
signal cell_hovered(x: int, y: int)
signal cell_unhovered(x: int, y: int)

const DefaultCellImage := preload("res://art/images/battle/runtime/images/cell_anchor_transparent.svg")
const LANDING_TILE_TEXTURES := {
	"fire": preload("res://art/images/shared/pets/battle_complete/landing_fire.png"),
	"water": preload("res://art/images/shared/pets/battle_complete/landing_water.png"),
	"earth": preload("res://art/images/shared/pets/battle_complete/landing_earth.png"),
	"wind": preload("res://art/images/shared/pets/battle_complete/landing_wind.png"),
}

const STYLE_DEFAULT_BG := Color(0.48, 0.50, 0.53, 0.30)
const STYLE_DEFAULT_BORDER := Color(0.78, 0.82, 0.86, 0.45)
const STYLE_DEPLOY_BG := Color(0.14, 0.44, 1.0, 0.28)
const STYLE_DEPLOY_BORDER := Color(0.28, 0.68, 1.0, 0.66)
const STYLE_CORNER_RADIUS := 12
const STYLE_SHADOW_COLOR := Color(0.13, 0.08, 0.03, 0.16)
const STYLE_SHADOW_SIZE := 5
const STYLE_SHADOW_OFFSET := Vector2(0.0, 3.0)
const PERSPECTIVE_DEFAULT_FILL := Color(0.82, 0.84, 0.86, 0.015)
const PERSPECTIVE_DEFAULT_BORDER := Color(0.86, 0.89, 0.91, 0.12)
const ATTACK_HIGHLIGHT_FILL := Color(0.92, 0.1, 0.08, 0.42)
const RANGE_HIGHLIGHT_FILL := Color(1.0, 0.16, 0.10, 0.30)
@export var use_perspective_geometry := false
@export var polygon := PackedVector2Array([
	Vector2(3.660006, 0.0),
	Vector2(124.66, 0.0),
	Vector2(124.66, 109.57143),
	Vector2(0.0, 109.57143),
])

@onready var cell_image: TextureRect = $CellImage
@onready var _attack_highlight: Polygon2D = $AttackHighlight
@onready var _attack_highlight_border: Line2D = $AttackHighlightBorder
@onready var _hover_highlight: Polygon2D = $HoverHighlight
@onready var _hover_highlight_border: Line2D = $HoverHighlightBorder
@onready var _ground_element_effects: Control = $GroundElementEffects
@onready var _landing_tile_art: TextureRect = $GroundElementEffects/LandingTileArt
@onready var _element_impact_layer: Control = $GroundElementEffects/ImpactLayer

var grid_x := 0
var grid_y := 0
var cell_data: Dictionary = {}
var _unit_node: Control = null
var _missing_mappings: Dictionary = {}
var _highlight_mode := ""
var _assets: RefCounted = null
var _attack_order_marker: TextureRect = null
var _transient_element_visual_dirty := false
var _unit_stat_layout_scale := 1.0
var _active_element_tile_variant := ""
var _is_hovered := false
var _attack_highlight_blink_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_attack_highlight_geometry()
	_update_attack_highlight()
	_sync_interaction_highlight_geometry()
	_update_interaction_highlights()
	if use_perspective_geometry:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		queue_redraw()
	else:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		queue_redraw()
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func setup_grid_position(
	x: int,
	y: int,
	cell_size: Vector2,
	origin: Vector2,
	front_row_height: float = 0.0
) -> void:
	grid_x = x
	grid_y = y
	name = "BattleCell_%d_%d" % [grid_x, grid_y]
	if not use_perspective_geometry:
		position = origin
		size = cell_size
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_unit_stat_layout_scale = 1.0
	if use_perspective_geometry and front_row_height > 0.0:
		_unit_stat_layout_scale = clampf(size.y / front_row_height, 0.1, 1.0)
	_apply_unit_stat_layout_scale()
	_sync_attack_highlight_geometry()
	_sync_interaction_highlight_geometry()
	queue_redraw()


func setup_authored_grid_position(
	x: int,
	y: int,
	cell_rect: Rect2,
	cell_polygon: PackedVector2Array,
	front_row_height: float
) -> void:
	grid_x = x
	grid_y = y
	name = "BattleCell_%d_%d" % [grid_x, grid_y]
	position = cell_rect.position
	size = cell_rect.size
	polygon = cell_polygon
	_unit_stat_layout_scale = clampf(size.y / front_row_height, 0.1, 1.0) if front_row_height > 0.0 else 1.0
	_apply_unit_stat_layout_scale()
	_sync_attack_highlight_geometry()
	_sync_interaction_highlight_geometry()
	queue_redraw()


func uses_perspective_geometry() -> bool:
	return use_perspective_geometry and polygon.size() >= 3


func contains_board_point(board_position: Vector2) -> bool:
	return _has_point(board_position - position)


func get_grid_position() -> Vector2i:
	return Vector2i(grid_x, grid_y)


func get_unit_node() -> Control:
	return _unit_node


func set_unit_node(unit: Control) -> void:
	_unit_node = unit
	_apply_unit_stat_layout_scale()


func set_cell_image(texture_resource: Texture2D, tint: Color = Color.WHITE) -> void:
	cell_image.texture = texture_resource
	cell_image.modulate = tint


func clear_cell_image() -> void:
	cell_image.texture = DefaultCellImage
	cell_image.modulate = Color.WHITE


func get_center_position() -> Vector2:
	return position + size * 0.5


func set_cell_data(data: Dictionary, assets: RefCounted) -> void:
	cell_data = data.duplicate(true)
	_assets = assets
	_missing_mappings = {}
	clear_element_visuals()
	_attack_order_marker = null
	_transient_element_visual_dirty = false
	var unit_id := String(cell_data.get("unitId", cell_data.get("unit_id", "")))
	if unit_id == "" and _unit_node != null:
		_unit_node = null
	_render_element_tile(Dictionary(cell_data.get("elements", {})))


func _apply_unit_stat_layout_scale() -> void:
	if _unit_node != null and _unit_node.has_method("set_battle_stat_layout_scale"):
		var cell_corners := polygon if uses_perspective_geometry() else PackedVector2Array()
		_unit_node.call("set_battle_stat_layout_scale", _unit_stat_layout_scale, cell_corners)


func set_highlight(mode: String) -> void:
	if mode == "selected":
		mode = ""
	_highlight_mode = mode
	if mode != "attack":
		set_attack_highlight_blinking(false)
	_update_attack_highlight()
	queue_redraw()


func set_hovered(value: bool) -> void:
	_is_hovered = value
	_update_interaction_highlights()


func is_hover_highlight_visible() -> bool:
	return _hover_highlight != null and _hover_highlight.visible


func clear_highlight() -> void:
	set_highlight("")


func set_attack_highlight_blinking(active: bool) -> void:
	if _attack_highlight_blink_tween != null and _attack_highlight_blink_tween.is_valid():
		_attack_highlight_blink_tween.kill()
	_attack_highlight_blink_tween = null
	_set_attack_highlight_alpha(1.0)
	if not active or _highlight_mode != "attack":
		return
	_attack_highlight_blink_tween = create_tween().set_loops()
	_attack_highlight_blink_tween.tween_method(_set_attack_highlight_alpha, 1.0, 0.22, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_attack_highlight_blink_tween.tween_method(_set_attack_highlight_alpha, 0.22, 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_attack_highlight_blinking() -> bool:
	return (
		_highlight_mode == "attack"
		and _attack_highlight_blink_tween != null
		and _attack_highlight_blink_tween.is_valid()
	)


func _set_attack_highlight_alpha(alpha: float) -> void:
	if _attack_highlight != null:
		_attack_highlight.modulate.a = alpha
	if _attack_highlight_border != null:
		_attack_highlight_border.modulate.a = alpha


func show_attack_order_marker(_texture_resource: Texture2D) -> void:
	clear_attack_order_marker()


func clear_attack_order_marker() -> void:
	if is_instance_valid(_attack_order_marker):
		_attack_order_marker.queue_free()
	_attack_order_marker = null


func clear_element_visuals() -> void:
	clear_element_tile()
	_clear_children(_element_impact_layer)


func show_element_tile(element: String) -> void:
	if _has_unit_occupant():
		clear_element_tile()
		return
	var variant_id := _element_tile_variant_id(element)
	var tile_texture := _element_tile_texture(variant_id)
	_landing_tile_art.texture = tile_texture
	_landing_tile_art.visible = tile_texture != null
	_active_element_tile_variant = variant_id if tile_texture != null else ""


func clear_element_tile() -> void:
	_landing_tile_art.visible = false
	_active_element_tile_variant = ""


func get_active_element_tile_variant() -> String:
	return _active_element_tile_variant


func show_transient_element_tile(element: String) -> void:
	show_element_tile(element)
	_transient_element_visual_dirty = _active_element_tile_variant != ""


func consume_transient_element_visual_dirty() -> bool:
	var was_dirty := _transient_element_visual_dirty
	_transient_element_visual_dirty = false
	return was_dirty


func play_element_impact(
	element: String,
	persist_tile: bool = true
) -> Node:
	if _has_unit_occupant():
		clear_element_tile()
		return null
	if persist_tile:
		show_transient_element_tile(element)
	if _element_impact_layer == null:
		return null
	var source_texture := _element_tile_texture(_element_tile_variant_id(element))
	if source_texture == null:
		return null
	var pulse := TextureRect.new()
	pulse.name = "ElementImpact"
	pulse.set_meta("element_impact", true)
	pulse.set_meta("element_tile_variant", _element_tile_variant_id(element))
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.texture = source_texture
	pulse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pulse.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pulse.size = size
	pulse.position = Vector2.ZERO
	pulse.pivot_offset = pulse.size * 0.5
	pulse.scale = Vector2.ONE * 0.62
	pulse.modulate.a = 0.94
	_element_impact_layer.add_child(pulse)
	var tween := pulse.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector2.ONE * 1.12, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.08)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		if is_instance_valid(pulse):
			pulse.queue_free()
	)
	return pulse


func has_player_unit() -> bool:
	var side := String(cell_data.get("side", cell_data.get("unitSide", "")))
	return String(cell_data.get("unitId", cell_data.get("unit_id", ""))) != "" and side in ["player", "hero_leader"]


func _has_unit_occupant() -> bool:
	if _unit_node != null and is_instance_valid(_unit_node):
		return true
	return String(cell_data.get("unitId", cell_data.get("unit_id", ""))) != ""


func set_unit_dragging(is_dragging: bool) -> void:
	if _unit_node != null and _unit_node.has_method("set_dragging"):
		_unit_node.call("set_dragging", is_dragging)


func get_missing_mapping_report() -> Array:
	var values := _missing_mappings.values()
	values.sort_custom(func(a, b):
		return String(Dictionary(a).get("key", "")) < String(Dictionary(b).get("key", ""))
	)
	return values


func _clear_content() -> void:
	clear_element_visuals()
	_unit_node = null
	_attack_order_marker = null
	_transient_element_visual_dirty = false


func _render_element_tile(elements: Dictionary) -> void:
	clear_element_tile()
	var element_configs := [
		{"visual_id": "neutral", "keys": ["无", "neutral"]},
		{"visual_id": "fire", "keys": ["火", "fire"]},
		{"visual_id": "water", "keys": ["水", "water"]},
		{"visual_id": "grass", "keys": ["草", "grass"]},
		{"visual_id": "electric", "keys": ["雷", "electric"]},
		{"visual_id": "ice", "keys": ["冰", "ice"]},
		{"visual_id": "ground", "keys": ["地", "ground"]},
		{"visual_id": "dark", "keys": ["暗", "dark"]},
		{"visual_id": "dragon", "keys": ["龙", "dragon"]}
	]
	var primary_visual_id := ""
	var primary_layers := 0
	for element_config in element_configs:
		var config := Dictionary(element_config)
		var layers := _element_layer_count(elements, Array(config.get("keys", [])))
		if layers > primary_layers:
			primary_layers = layers
			primary_visual_id = String(config.get("visual_id", ""))
	if primary_visual_id != "":
		show_element_tile(primary_visual_id)


func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		child.queue_free()


func _element_layer_count(elements: Dictionary, keys: Array) -> int:
	var layers := 0
	for key_value in keys:
		layers = max(layers, int(elements.get(String(key_value), 0)))
	return layers


func _element_tile_texture(variant_id: String) -> Texture2D:
	return LANDING_TILE_TEXTURES.get(variant_id) as Texture2D


func _element_tile_variant_id(element: String) -> String:
	match element.strip_edges().to_lower():
		"fire", "火", "dragon", "龙":
			return "fire"
		"water", "水", "ice", "冰":
			return "water"
		"earth", "ground", "地", "dark", "暗":
			return "earth"
		"wind", "风", "neutral", "无", "grass", "草", "electric", "雷":
			return "wind"
		_:
			return "fire"


func _make_cell_style(highlight_mode: String = "") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match highlight_mode:
		"deploy":
			style.bg_color = STYLE_DEPLOY_BG
			style.border_color = STYLE_DEPLOY_BORDER
		_:
			style.bg_color = STYLE_DEFAULT_BG
			style.border_color = STYLE_DEFAULT_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = STYLE_CORNER_RADIUS
	style.corner_radius_top_right = STYLE_CORNER_RADIUS
	style.corner_radius_bottom_right = STYLE_CORNER_RADIUS
	style.corner_radius_bottom_left = STYLE_CORNER_RADIUS
	style.shadow_color = STYLE_SHADOW_COLOR
	style.shadow_size = STYLE_SHADOW_SIZE
	style.shadow_offset = STYLE_SHADOW_OFFSET
	return style


func _sync_attack_highlight_geometry() -> void:
	if _attack_highlight == null or _attack_highlight_border == null:
		return
	var highlight_polygon := polygon.duplicate() if uses_perspective_geometry() else PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	_attack_highlight.polygon = highlight_polygon
	var outline := highlight_polygon.duplicate()
	if not outline.is_empty():
		outline.append(outline[0])
	_attack_highlight_border.points = outline


func _update_attack_highlight() -> void:
	var is_attack := _highlight_mode == "attack"
	var is_range := _highlight_mode == "range"
	if _attack_highlight != null:
		_attack_highlight.color = RANGE_HIGHLIGHT_FILL if is_range else ATTACK_HIGHLIGHT_FILL
		_attack_highlight.visible = is_attack or is_range
	if _attack_highlight_border != null:
		_attack_highlight_border.visible = is_attack


func _sync_interaction_highlight_geometry() -> void:
	if _hover_highlight == null or _hover_highlight_border == null:
		return
	var cell_polygon := polygon.duplicate() if uses_perspective_geometry() else PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	_hover_highlight.polygon = cell_polygon
	var hover_outline := cell_polygon.duplicate()
	if not hover_outline.is_empty():
		hover_outline.append(hover_outline[0])
	_hover_highlight_border.points = hover_outline


func _update_interaction_highlights() -> void:
	if _hover_highlight != null:
		_hover_highlight.visible = _is_hovered
	if _hover_highlight_border != null:
		_hover_highlight_border.visible = _is_hovered


func _has_point(point: Vector2) -> bool:
	if uses_perspective_geometry():
		return Geometry2D.is_point_in_polygon(point, polygon)
	return Rect2(Vector2.ZERO, size).has_point(point)


func _draw() -> void:
	var cell_polygon := polygon.duplicate() if uses_perspective_geometry() else PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	var colors := _perspective_colors()
	draw_colored_polygon(cell_polygon, colors[0])
	var outline := cell_polygon.duplicate()
	outline.append(cell_polygon[0])
	draw_polyline(outline, colors[1], 2.0, true)


func _perspective_colors() -> Array[Color]:
	match _highlight_mode:
		"deploy":
			return [STYLE_DEPLOY_BG, STYLE_DEPLOY_BORDER]
		_:
			return [PERSPECTIVE_DEFAULT_FILL, PERSPECTIVE_DEFAULT_BORDER]


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			cell_pressed.emit(grid_x, grid_y)
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			cell_released.emit(grid_x, grid_y)
			cell_selected.emit(grid_x, grid_y)
			accept_event()


func _on_mouse_entered() -> void:
	cell_hovered.emit(grid_x, grid_y)


func _on_mouse_exited() -> void:
	cell_unhovered.emit(grid_x, grid_y)
