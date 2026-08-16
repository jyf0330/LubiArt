extends Control

## Shared authored route/shop chrome. Page roots own Snapshot rendering and
## commands; this prefab owns only its stable surfaces and visual state.

const BAG_SLOT_COUNT := 8
const BAG_SLOT_SIZE := Vector2(154.0, 146.0)
const BAG_SLOT_DISPLAY_SIZE := Vector2(121.0, 116.0)
const BAG_SLOT_DISPLAY_OFFSET := Vector2(24.0, 13.0)
const BAG_SLOT_DISPLAY_CENTER := Vector2(77.0, 73.0)
const PARTY_SLOT_DISPLAY_LIMIT := Vector2(155.0, 126.0)
const PARTY_SLOT_DISPLAY_CENTER := Vector2(82.0, 74.0)
const BAG_CLOSED_TEXTURE := preload("res://art/images/route/three_choice_psd/bag_closed.png")
const BAG_OPEN_TEXTURE := preload("res://art/images/route/three_choice_psd/bag_open_full.png")

const BAG_SLOT_SHADER_SOURCE := """
shader_type canvas_item;

uniform vec2 control_size = vec2(154.0, 146.0);
uniform vec2 display_size = vec2(121.0, 116.0);
uniform vec2 display_offset = vec2(24.0, 13.0);
uniform bool source_enabled = false;
uniform sampler2D source_texture : filter_nearest;
uniform vec2 source_size = vec2(1.0, 1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 pixel_position = UV * control_size;
	vec2 display_pixel_position = pixel_position - display_offset;
	bool outside = display_pixel_position.x < 0.0 || display_pixel_position.y < 0.0 || display_pixel_position.x >= display_size.x || display_pixel_position.y >= display_size.y;
	COLOR = vec4(0.0);
	if (!outside && source_enabled) {
		vec2 display_uv = display_pixel_position / display_size;
		float source_aspect = source_size.x / source_size.y;
		float target_aspect = display_size.x / display_size.y;
		vec2 source_uv = display_uv;
		if (source_aspect > target_aspect) {
			source_uv.x = 0.5 + (display_uv.x - 0.5) * target_aspect / source_aspect;
		} else {
			source_uv.y = 0.5 + (display_uv.y - 0.5) * source_aspect / target_aspect;
		}
		source_uv.x -= 0.000001;
		COLOR = texture(source_texture, source_uv) * tint;
	}
}
"""

@export var item_slot_highlight_offset := Vector2(-10.0, -14.0)

var _slot_draw_texture: ImageTexture = null
var _bag_slot_shader: Shader = null
var _bag_buttons: Array[TextureButton] = []


func _ready() -> void:
	ensure_bag_buttons()
	_configure_exit_click_mask()


func _configure_exit_click_mask() -> void:
	var button := exit_button()
	var coin_panel := $Top/Hud/CoinIcon as Control
	var normal_texture := button.texture_normal
	if normal_texture == null:
		return
	var click_mask := BitMap.new()
	click_mask.create_from_image_alpha(normal_texture.get_image(), 0.1)
	var covered_global_rect := button.get_global_rect().intersection(coin_panel.get_global_rect())
	if covered_global_rect.has_area():
		click_mask.set_bit_rect(
			Rect2i(
				Vector2i(covered_global_rect.position - button.global_position),
				Vector2i(covered_global_rect.size)
			),
			false
		)
	button.texture_click_mask = click_mask


func party_container() -> Control:
	return $Party/Party_Container


func party_buttons() -> Array[TextureButton]:
	var result: Array[TextureButton] = []
	var container := party_container()
	for index in range(4):
		var node_name := "Party_Slot" if index == 0 else "Party_Slot%d" % (index + 1)
		var button := container.get_node_or_null(node_name) as TextureButton
		if button != null:
			result.append(button)
	return result


func bag_slots() -> GridContainer:
	return $Middle_Bag/Slots


func ensure_bag_buttons() -> Array[TextureButton]:
	if _bag_buttons.size() == BAG_SLOT_COUNT:
		return _bag_buttons
	_bag_buttons.clear()
	_ensure_slot_draw_texture()
	var slots := bag_slots()
	for index in range(BAG_SLOT_COUNT):
		var node_name := "Bag_Slot" if index == 0 else "Bag_Slot%d" % (index + 1)
		var button := slots.get_node_or_null(node_name) as TextureButton
		if button == null:
			button = TextureButton.new()
			button.name = node_name
			slots.add_child(button)
		_configure_bag_button(button)
		_bag_buttons.append(button)
	return _bag_buttons


func bag_buttons() -> Array[TextureButton]:
	return ensure_bag_buttons()


func bag_button() -> TextureButton:
	return $Bags/Bag_Button


func exit_button() -> TextureButton:
	return $ExitButton


func coin_label() -> Label:
	return $Top/Hud/CoinLabel


func set_coin_amount(amount: int) -> void:
	coin_label().text = str(amount)


func set_bag_open(open: bool) -> void:
	if not open:
		hide_bag_slot_highlight()
	$BagOverlayMask.visible = open
	$Middle_Bag.visible = open
	var state_texture := BAG_OPEN_TEXTURE if open else BAG_CLOSED_TEXTURE
	var button := bag_button()
	button.texture_normal = state_texture
	button.texture_pressed = state_texture
	button.texture_hover = state_texture
	button.texture_focused = state_texture


func set_party_texture(button: TextureButton, texture: Texture2D) -> void:
	if button == null:
		return
	button.set_meta("pet_texture", texture)
	button.self_modulate.a = 1.0
	var portrait := _ensure_party_portrait(button)
	var display_rect := _party_texture_rect(texture)
	portrait.position = display_rect.position
	portrait.size = display_rect.size
	portrait.texture = texture
	portrait.visible = texture != null
	var shader_material := button.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("source_enabled", false)
	shader_material.set_shader_parameter("shadow_enabled", texture != null)
	shader_material.set_shader_parameter("shadow_highlight", 0.0)
	button.visible = true


func _ensure_party_portrait(button: TextureButton) -> TextureRect:
	var portrait := button.get_node_or_null("PartyPortrait") as TextureRect
	if portrait != null:
		return portrait
	portrait = TextureRect.new()
	portrait.name = "PartyPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(portrait)
	return portrait


func _party_texture_rect(texture: Texture2D) -> Rect2:
	var display_size := PARTY_SLOT_DISPLAY_LIMIT
	if texture != null:
		var source_size := texture.get_size()
		if source_size.x > 0.0 and source_size.y > 0.0:
			var scale := minf(
				PARTY_SLOT_DISPLAY_LIMIT.x / source_size.x,
				PARTY_SLOT_DISPLAY_LIMIT.y / source_size.y
			)
			display_size = Vector2(
				floorf(source_size.x * scale * 0.5) * 2.0,
				floorf(source_size.y * scale * 0.5) * 2.0
			)
	return Rect2(PARTY_SLOT_DISPLAY_CENTER - display_size * 0.5, display_size)


func set_bag_texture(button: TextureButton, texture: Texture2D) -> void:
	if button == null:
		return
	button.set_meta("pet_texture", texture)
	var portrait := _ensure_bag_portrait(button)
	var display_rect := _bag_texture_rect(texture)
	portrait.position = display_rect.position
	portrait.size = display_rect.size
	portrait.texture = texture
	portrait.visible = texture != null
	var shader_material := button.material as ShaderMaterial
	if shader_material == null:
		return
	button.texture_normal = _slot_draw_texture
	button.texture_pressed = _slot_draw_texture
	button.texture_hover = _slot_draw_texture
	button.texture_focused = _slot_draw_texture
	shader_material.set_shader_parameter("source_enabled", false)
	shader_material.set_shader_parameter("source_texture", texture)
	shader_material.set_shader_parameter("source_size", texture.get_size() if texture != null else Vector2.ONE)


func _ensure_bag_portrait(button: TextureButton) -> TextureRect:
	var portrait := button.get_node_or_null("BagPortrait") as TextureRect
	if portrait != null:
		return portrait
	portrait = TextureRect.new()
	portrait.name = "BagPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(portrait)
	return portrait


func _bag_texture_rect(texture: Texture2D) -> Rect2:
	var display_size := BAG_SLOT_DISPLAY_SIZE
	if texture != null:
		var source_size := texture.get_size()
		if source_size.x > 0.0 and source_size.y > 0.0:
			var scale := minf(
				BAG_SLOT_DISPLAY_SIZE.x / source_size.x,
				BAG_SLOT_DISPLAY_SIZE.y / source_size.y
			)
			display_size = Vector2(
				floorf(source_size.x * scale * 0.5) * 2.0,
				floorf(source_size.y * scale * 0.5) * 2.0
			)
	return Rect2(BAG_SLOT_DISPLAY_CENTER - display_size * 0.5, display_size)


func set_party_hovered(button: TextureButton, hovered: bool) -> void:
	if button == null:
		return
	button.set_meta("party_mouse_hovered", hovered)
	var shader_material := button.material as ShaderMaterial
	if shader_material == null:
		return
	var occupied := button.has_meta("pet_texture") and button.get_meta("pet_texture") != null
	shader_material.set_shader_parameter("shadow_highlight", 1.0 if occupied and hovered else 0.0)


func set_drag_source_visible(button: BaseButton, source: StringName, source_visible: bool) -> void:
	if button is TextureButton and source == &"party":
		button.self_modulate.a = 1.0 if source_visible else 0.0
	elif button is TextureButton and source == &"bag":
		var portrait := _ensure_bag_portrait(button as TextureButton)
		portrait.visible = source_visible and portrait.texture != null


func set_snapshot_input_enabled(enabled: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_bag_slot_highlight(slot: Control, texture: Texture2D) -> void:
	var highlight := $ItemSlotHoverHighlight as TextureRect
	if slot == null or texture == null:
		highlight.visible = false
		return
	var slot_canvas_origin := slot.get_global_transform_with_canvas().origin
	var slot_position_in_shared := get_global_transform_with_canvas().affine_inverse() * slot_canvas_origin
	highlight.texture = texture
	highlight.position = slot_position_in_shared + item_slot_highlight_offset
	highlight.visible = true
	highlight.move_to_front()


func hide_bag_slot_highlight() -> void:
	$ItemSlotHoverHighlight.visible = false


func _configure_bag_button(button: TextureButton) -> void:
	button.custom_minimum_size = BAG_SLOT_SIZE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("slot_surface_self", true)
	button.set_meta("drag_preview_size", BAG_SLOT_DISPLAY_SIZE)
	if not (button.material is ShaderMaterial):
		var slot_material := ShaderMaterial.new()
		slot_material.shader = _ensure_bag_slot_shader()
		slot_material.set_shader_parameter("control_size", BAG_SLOT_SIZE)
		slot_material.set_shader_parameter("display_size", BAG_SLOT_DISPLAY_SIZE)
		slot_material.set_shader_parameter("display_offset", BAG_SLOT_DISPLAY_OFFSET)
		button.material = slot_material
	set_bag_texture(button, button.get_meta("pet_texture") as Texture2D if button.has_meta("pet_texture") else null)


func _ensure_slot_draw_texture() -> void:
	if _slot_draw_texture != null:
		return
	var draw_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	draw_image.fill(Color.WHITE)
	_slot_draw_texture = ImageTexture.create_from_image(draw_image)


func _ensure_bag_slot_shader() -> Shader:
	if _bag_slot_shader == null:
		_bag_slot_shader = Shader.new()
		_bag_slot_shader.code = BAG_SLOT_SHADER_SOURCE
	return _bag_slot_shader
