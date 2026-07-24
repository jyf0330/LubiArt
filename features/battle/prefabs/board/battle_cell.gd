extends Panel

signal cell_selected(x: int, y: int)
signal cell_pressed(x: int, y: int)
signal cell_released(x: int, y: int)
signal cell_hovered(x: int, y: int)
signal cell_unhovered(x: int, y: int)

const BattleUnitScene := preload("res://shared/prefabs/pet/pet_visual.tscn")
const DefaultCellImage := preload("res://assets/battle_ui/images/cell_anchor_transparent.svg")

const STYLE_DEFAULT_BG := Color(0.48, 0.50, 0.53, 0.30)
const STYLE_DEFAULT_BORDER := Color(0.78, 0.82, 0.86, 0.45)
const STYLE_DEPLOY_BG := Color(0.14, 0.44, 1.0, 0.28)
const STYLE_DEPLOY_BORDER := Color(0.28, 0.68, 1.0, 0.66)
const STYLE_ATTACK_BG := Color(0.92, 0.1, 0.08, 0.42)
const STYLE_ATTACK_BORDER := Color(1.0, 0.2, 0.18, 0.78)
const STYLE_CORNER_RADIUS := 12
const STYLE_SHADOW_COLOR := Color(0.13, 0.08, 0.03, 0.16)
const STYLE_SHADOW_SIZE := 5
const STYLE_SHADOW_OFFSET := Vector2(0.0, 3.0)
const HOVER_FRAME_SCALE := 0.82
const HOVER_FRAME_OFFSET := Vector2.ZERO

@onready var cell_image: TextureRect = $CellImage
@onready var _prefab_anchor: Control = $PrefabAnchor

var grid_x := 0
var grid_y := 0
var cell_data: Dictionary = {}
var _unit_node: Control = null
var _missing_mappings: Dictionary = {}
var _highlight_mode := ""
var _assets: RefCounted = null
var _highlight_frame: TextureRect = null
var _attack_order_marker: TextureRect = null
var _effect_marker: TextureRect = null
var _transient_element_visual_dirty := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_cell_style())
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func setup_grid_position(x: int, y: int, cell_size: Vector2, origin: Vector2) -> void:
	grid_x = x
	grid_y = y
	name = "BattleCell_%d_%d" % [grid_x, grid_y]
	position = origin
	size = cell_size


func get_grid_position() -> Vector2i:
	return Vector2i(grid_x, grid_y)


func get_unit_node() -> Control:
	return _unit_node


func get_prefab_anchor() -> Control:
	return _prefab_anchor


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
	_clear_content()
	var side := String(cell_data.get("side", cell_data.get("unitSide", "")))
	var unit_id := String(cell_data.get("unitId", cell_data.get("unit_id", "")))
	_render_element_markers(Dictionary(cell_data.get("elements", {})))
	if unit_id == "":
		return
	_unit_node = BattleUnitScene.instantiate() as Control
	_unit_node.name = "BattleUnit"
	_unit_node.position = Vector2.ZERO
	_unit_node.size = size
	_unit_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prefab_anchor.add_child(_unit_node)
	if _unit_node.has_method("set_unit_data"):
		_unit_node.call("set_unit_data", cell_data, side, assets)
	if _unit_node.has_method("get_missing_mapping"):
		var missing := Dictionary(_unit_node.call("get_missing_mapping"))
		if not missing.is_empty():
			_missing_mappings[String(missing.get("key", ""))] = missing


func set_highlight(mode: String) -> void:
	_highlight_mode = mode
	add_theme_stylebox_override("panel", _make_cell_style(mode))
	_update_highlight_frame(mode)


func clear_highlight() -> void:
	set_highlight("")


func show_attack_order_marker(texture_resource: Texture2D) -> void:
	clear_attack_order_marker()
	if texture_resource == null:
		return
	_attack_order_marker = TextureRect.new()
	_attack_order_marker.name = "AttackOrderMarker"
	_attack_order_marker.texture = texture_resource
	_attack_order_marker.size = Vector2(34.0, 34.0)
	_attack_order_marker.position = Vector2(size.x - 40.0, 6.0)
	_attack_order_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attack_order_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_attack_order_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_order_marker.z_index = 30
	_prefab_anchor.add_child(_attack_order_marker)


func clear_attack_order_marker() -> void:
	if is_instance_valid(_attack_order_marker):
		_attack_order_marker.queue_free()
	_attack_order_marker = null


func show_effect_marker(texture_resource: Texture2D) -> void:
	clear_effect_marker()
	if texture_resource == null:
		return
	_effect_marker = TextureRect.new()
	_effect_marker.name = "EffectMarker"
	_effect_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_effect_marker.custom_minimum_size = Vector2.ZERO
	_effect_marker.texture = texture_resource
	_effect_marker.position = Vector2.ZERO
	_effect_marker.size = size
	_effect_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_effect_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_marker.z_index = 3
	_prefab_anchor.add_child(_effect_marker)
	_prefab_anchor.move_child(_effect_marker, 0)


func clear_effect_marker() -> void:
	if is_instance_valid(_effect_marker):
		_effect_marker.queue_free()
	_effect_marker = null


func clear_element_visuals() -> void:
	clear_effect_marker()
	for child in _prefab_anchor.get_children():
		if String(child.name).begins_with("Element_"):
			child.queue_free()


func show_transient_element_marker(texture_resource: Texture2D) -> void:
	show_effect_marker(texture_resource)
	_transient_element_visual_dirty = texture_resource != null


func consume_transient_element_visual_dirty() -> bool:
	var was_dirty := _transient_element_visual_dirty
	_transient_element_visual_dirty = false
	return was_dirty


func has_player_unit() -> bool:
	if _unit_node == null or not is_instance_valid(_unit_node):
		return false
	return String(_unit_node.get("side")) == "player" or String(_unit_node.get("side")) == "hero_leader"


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
	for child in _prefab_anchor.get_children():
		child.queue_free()
	_unit_node = null
	_highlight_frame = null
	_attack_order_marker = null
	_effect_marker = null


func _render_element_markers(elements: Dictionary) -> void:
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
	if primary_visual_id != "" and _assets != null and _assets.has_method("buff_ring_texture"):
		show_effect_marker(_assets.call("buff_ring_texture", primary_visual_id) as Texture2D)
		if is_instance_valid(_effect_marker):
			_effect_marker.modulate.a = 0.82

	var visible_index := 0
	for element_config in element_configs:
		var config := Dictionary(element_config)
		var visual_id := String(config.get("visual_id", ""))
		var layer_count := _element_layer_count(elements, Array(config.get("keys", [])))
		if layer_count <= 0:
			continue
		for layer_index in range(layer_count):
			var marker := ColorRect.new()
			marker.name = "Element_%s" % visual_id if layer_index == 0 else "Element_%s_%d" % [visual_id, layer_index + 1]
			marker.color = _element_color(visual_id)
			marker.position = _element_marker_position(visible_index)
			marker.size = Vector2(12.0, 12.0)
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.z_index = 5
			_prefab_anchor.add_child(marker)
			visible_index += 1


func _element_marker_position(visible_index: int) -> Vector2:
	var columns: int = max(1, int(floor(max(12.0, size.x - 16.0) / 18.0)))
	var column := visible_index % columns
	var row := int(visible_index / columns)
	return Vector2(8.0 + column * 18.0, size.y - 20.0 - row * 18.0)


func _element_layer_count(elements: Dictionary, keys: Array) -> int:
	var layers := 0
	for key_value in keys:
		layers = max(layers, int(elements.get(String(key_value), 0)))
	return layers


func _make_cell_style(highlight_mode: String = "") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match highlight_mode:
		"deploy", "selected":
			style.bg_color = STYLE_DEPLOY_BG
			style.border_color = STYLE_DEPLOY_BORDER
		"attack":
			style.bg_color = STYLE_ATTACK_BG
			style.border_color = STYLE_ATTACK_BORDER
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


func _update_highlight_frame(highlight_mode: String) -> void:
	if is_instance_valid(_highlight_frame):
		_highlight_frame.queue_free()
	_highlight_frame = null
	if highlight_mode != "selected":
		return
	if _assets == null or not _assets.has_method("hover_frame_texture"):
		return
	var texture_resource := _assets.call("hover_frame_texture") as Texture2D
	if texture_resource == null:
		return
	_highlight_frame = TextureRect.new()
	_highlight_frame.name = "HoverFrame"
	_highlight_frame.custom_minimum_size = Vector2.ZERO
	_highlight_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_highlight_frame.texture = texture_resource
	var frame_size := size * HOVER_FRAME_SCALE
	_highlight_frame.position = (size - frame_size) * 0.5 + HOVER_FRAME_OFFSET
	_highlight_frame.size = frame_size
	_highlight_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_highlight_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_frame.z_index = 18
	_prefab_anchor.add_child(_highlight_frame)


func _element_color(element: String) -> Color:
	match element:
		"neutral":
			return Color(0.82, 0.82, 0.78, 0.9)
		"fire":
			return Color(1.0, 0.24, 0.12, 0.9)
		"water":
			return Color(0.1, 0.48, 1.0, 0.9)
		"grass":
			return Color(0.28, 0.78, 0.24, 0.9)
		"electric":
			return Color(1.0, 0.82, 0.08, 0.9)
		"ice":
			return Color(0.52, 0.9, 1.0, 0.9)
		"ground":
			return Color(0.62, 0.42, 0.18, 0.9)
		"dark":
			return Color(0.48, 0.24, 0.68, 0.9)
		"dragon":
			return Color(0.86, 0.28, 0.58, 0.9)
		_:
			return Color.WHITE


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
