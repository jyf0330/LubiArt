extends Control
class_name ShopSharedRail

## Reusable shop-bottom art composition. It projects public party records and
## currency, and emits UI intent without knowing any gameplay command type.

signal bag_requested
signal exit_requested

const BAG_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shared_bag_closed.png")
const BAG_OPEN_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shared_bag_open.png")
const BAG_INVENTORY_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shared_bag_inventory.png")
const BAG_ITEM_HIGHLIGHT_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shared_bag_item_highlight.png")
const PARTY_SHELF_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shared_party_shelf.png")
const COIN_PANEL_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shared_coin_panel.png")
const EXIT_NORMAL_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shared_exit_normal.png")
const EXIT_HOVER_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shared_exit_hover.png")
const PARTY_SHADOW_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shared_party_shadow.png")

const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const PARTY_ORIGINS := [
	Vector2(560.0, 793.0),
	Vector2(738.0, 793.0),
	Vector2(914.0, 793.0),
	Vector2(1094.0, 793.0),
]
const BAG_SLOT_RECTS := [
	Rect2(551.0, 423.0, 154.0, 146.0),
	Rect2(736.0, 423.0, 154.0, 146.0),
	Rect2(921.0, 423.0, 154.0, 146.0),
	Rect2(1106.0, 423.0, 154.0, 146.0),
	Rect2(551.0, 601.0, 154.0, 146.0),
	Rect2(736.0, 601.0, 154.0, 146.0),
	Rect2(921.0, 601.0, 154.0, 146.0),
	Rect2(1106.0, 601.0, 154.0, 146.0),
]
const PARTY_PORTRAIT_MAX_SIZE := Vector2(155.0, 126.0)
const PARTY_PORTRAIT_CENTER_OFFSET := Vector2(82.0, 74.0)
const BAG_PORTRAIT_MAX_SIZE := Vector2(121.0, 116.0)
const BAG_HIGHLIGHT_OFFSET := Vector2(-10.0, -14.0)
const BAG_HIGHLIGHT_SIZE := Vector2(183.0, 177.0)
const PARTY_SHADOW_HOVER_MODULATE := Color(13.5556, 13.1429, 12.3571, 1.4706)
const EXIT_TOOLTIP := "离开商店"
const COIN_PANEL_RECT := Rect2(1303.0, 885.0, 165.0, 124.0)
const EXIT_RECT := Rect2(1410.0, 490.0, 269.0, 472.0)
const Z_EXIT := 1
const Z_BAG_OVERLAY := 10
const Z_BAG := 11
const Z_PARTY_SHELF := 12
const Z_PARTY := 13
const Z_COIN_PANEL := 14
const Z_COIN_LABEL := 15

var _party_layer: Control = null
var _party_interaction_layer: Control = null
var _party_shadows := {}
var _bag_overlay: Control = null
var _bag_inventory_layer: Control = null
var _bag_interaction_layer: Control = null
var _bag_highlight: TextureRect = null
var _bag_button: TextureButton = null
var _coin_label: Label = null
var _exit_button: TextureButton = null
var _bag_open := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layers()


func render_coin(coins: int) -> void:
	_coin_label.text = str(maxi(0, coins))


func render_party(roster: Array, texture_resolver: Callable) -> void:
	_clear_children(_party_layer)
	_clear_children(_party_interaction_layer)
	_party_shadows.clear()
	_clear_children(_bag_inventory_layer)
	_clear_children(_bag_interaction_layer)
	_bag_highlight.visible = false
	for bag_slot_index in range(BAG_SLOT_RECTS.size()):
		_add_bag_slot_interaction(bag_slot_index)
	var slot_index := 0
	var bag_index := 0
	for value in roster:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var pet := Dictionary(value)
		if not bool(pet.get("active", true)):
			if bag_index < BAG_SLOT_RECTS.size():
				_add_bag_pet(pet, bag_index, texture_resolver)
				bag_index += 1
			continue
		if slot_index >= PARTY_ORIGINS.size():
			break
		_add_party_pet(pet, slot_index, texture_resolver)
		slot_index += 1


func exit_button() -> BaseButton:
	return _exit_button


func toggle_bag() -> void:
	set_bag_open(not _bag_open)


func set_bag_open(open: bool) -> void:
	_bag_open = open
	_bag_overlay.visible = open
	if not open:
		_bag_highlight.visible = false
	var texture := BAG_OPEN_TEXTURE if open else BAG_TEXTURE
	_bag_button.texture_normal = texture
	_bag_button.texture_pressed = texture
	_bag_button.texture_hover = texture
	_bag_button.texture_focused = texture


func is_bag_open() -> bool:
	return _bag_open


func _build_layers() -> void:
	_bag_overlay = Control.new()
	_bag_overlay.name = "ShopBagOverlay"
	_bag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_overlay.z_index = Z_BAG_OVERLAY
	_bag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bag_overlay.visible = false
	add_child(_bag_overlay)

	var overlay_mask := ColorRect.new()
	overlay_mask.name = "BagOverlayMask"
	overlay_mask.color = Color(0.12, 0.12, 0.12, 0.38)
	overlay_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_reference_rect(overlay_mask, Rect2(0.0, 0.0, 1920.0, 1060.0))
	_bag_overlay.add_child(overlay_mask)

	var inventory_art := TextureRect.new()
	inventory_art.name = "BagInventoryArt"
	inventory_art.texture = BAG_INVENTORY_TEXTURE
	inventory_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inventory_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inventory_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inventory_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_reference_rect(inventory_art, Rect2(502.0, 379.0, 818.0, 439.0))
	_bag_overlay.add_child(inventory_art)

	_bag_inventory_layer = Control.new()
	_bag_inventory_layer.name = "BagPetLayer"
	_bag_inventory_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_inventory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bag_overlay.add_child(_bag_inventory_layer)

	_bag_highlight = TextureRect.new()
	_bag_highlight.name = "BagSlotHoverHighlight"
	_bag_highlight.texture = BAG_ITEM_HIGHLIGHT_TEXTURE
	_bag_highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bag_highlight.stretch_mode = TextureRect.STRETCH_SCALE
	_bag_highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bag_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_highlight.z_index = 1
	_bag_highlight.visible = false
	_bag_overlay.add_child(_bag_highlight)

	_bag_interaction_layer = Control.new()
	_bag_interaction_layer.name = "BagInteractionLayer"
	_bag_interaction_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_interaction_layer.z_index = 2
	_bag_interaction_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bag_overlay.add_child(_bag_interaction_layer)

	var shelf := TextureRect.new()
	shelf.name = "PartyShelfArt"
	shelf.texture = PARTY_SHELF_TEXTURE
	shelf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shelf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shelf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf.z_index = Z_PARTY_SHELF
	_apply_reference_rect(shelf, Rect2(519.0, 587.0, 882.0, 419.0))
	add_child(shelf)

	_bag_button = TextureButton.new()
	_bag_button.name = "ShopBagButton"
	_bag_button.texture_normal = BAG_TEXTURE
	_bag_button.ignore_texture_size = true
	_bag_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_bag_button.focus_mode = Control.FOCUS_ALL
	_bag_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bag_button.tooltip_text = "查看背包"
	_bag_button.accessibility_name = _bag_button.tooltip_text
	_bag_button.z_index = Z_BAG
	_apply_reference_rect(_bag_button, Rect2(313.0, 776.0, 236.0, 233.0))
	_bag_button.pressed.connect(_emit_bag_requested)
	add_child(_bag_button)

	var coin_panel := TextureRect.new()
	coin_panel.name = "CoinPanelArt"
	coin_panel.texture = COIN_PANEL_TEXTURE
	coin_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_panel.z_index = Z_COIN_PANEL
	_apply_reference_rect(coin_panel, COIN_PANEL_RECT)
	add_child(coin_panel)

	_coin_label = Label.new()
	_coin_label.name = "CoinLabel"
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 24)
	_coin_label.add_theme_color_override("font_color", Color(0.99, 0.84, 0.36, 1.0))
	_coin_label.z_index = Z_COIN_LABEL
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_reference_rect(_coin_label, Rect2(1373.0, 917.0, 63.0, 28.0))
	add_child(_coin_label)

	_exit_button = TextureButton.new()
	_exit_button.name = "ExitShopButton"
	_exit_button.texture_normal = EXIT_NORMAL_TEXTURE
	_exit_button.texture_hover = EXIT_HOVER_TEXTURE
	_exit_button.texture_pressed = EXIT_HOVER_TEXTURE
	_exit_button.texture_focused = EXIT_HOVER_TEXTURE
	_exit_button.ignore_texture_size = true
	_exit_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_exit_button.focus_mode = Control.FOCUS_ALL
	_exit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_exit_button.tooltip_text = EXIT_TOOLTIP
	_exit_button.accessibility_name = EXIT_TOOLTIP
	_exit_button.z_index = Z_EXIT
	_apply_reference_rect(_exit_button, EXIT_RECT)
	_exit_button.texture_click_mask = _build_exit_click_mask()
	_exit_button.button_down.connect(_on_exit_button_down)
	_exit_button.button_up.connect(_on_exit_button_up)
	_exit_button.pressed.connect(_emit_exit_requested)
	add_child(_exit_button)

	_party_layer = Control.new()
	_party_layer.name = "PartyPetLayer"
	_party_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_layer.z_index = Z_PARTY
	_party_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_party_layer)

	_party_interaction_layer = Control.new()
	_party_interaction_layer.name = "PartyInteractionLayer"
	_party_interaction_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_interaction_layer.z_index = Z_COIN_LABEL + 1
	_party_interaction_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_party_interaction_layer)


func _build_exit_click_mask() -> BitMap:
	var click_mask := BitMap.new()
	click_mask.create_from_image_alpha(EXIT_NORMAL_TEXTURE.get_image(), 0.1)
	var covered_rect := EXIT_RECT.intersection(COIN_PANEL_RECT)
	if covered_rect.has_area():
		click_mask.set_bit_rect(
			Rect2i(
				Vector2i(covered_rect.position - EXIT_RECT.position),
				Vector2i(covered_rect.size)
			),
			false
		)
	return click_mask


func _add_party_pet(pet: Dictionary, slot_index: int, texture_resolver: Callable) -> void:
	var origin: Vector2 = PARTY_ORIGINS[slot_index]
	var shadow := TextureRect.new()
	shadow.name = "PartyShadow_%d" % slot_index
	shadow.texture = PARTY_SHADOW_TEXTURE
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_reference_rect(shadow, Rect2(origin + Vector2(42.5, 110.0), Vector2(79.0, 19.0)))
	_party_layer.add_child(shadow)
	_party_shadows[slot_index] = shadow

	var portrait := TextureRect.new()
	portrait.name = "PartyPet_%d" % slot_index
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture_resolver.is_valid():
		portrait.texture = texture_resolver.call(pet) as Texture2D
	_apply_reference_rect(portrait, _party_portrait_rect(origin, portrait.texture))
	_party_layer.add_child(portrait)

	var interaction := TextureButton.new()
	interaction.name = "PartySlotButton_%d" % slot_index
	interaction.focus_mode = Control.FOCUS_ALL
	interaction.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	interaction.tooltip_text = String(pet.get("name", pet.get("id", "队伍宠物")))
	interaction.accessibility_name = interaction.tooltip_text
	interaction.set_meta("party_record", pet.duplicate(true))
	_apply_reference_rect(interaction, Rect2(origin, Vector2(164.0, 170.0)))
	interaction.mouse_entered.connect(_set_party_hovered.bind(slot_index, true))
	interaction.mouse_exited.connect(_set_party_hovered.bind(slot_index, false))
	_party_interaction_layer.add_child(interaction)


func _add_bag_pet(pet: Dictionary, slot_index: int, texture_resolver: Callable) -> void:
	var portrait := TextureRect.new()
	portrait.name = "BagPet_%d" % slot_index
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture_resolver.is_valid():
		portrait.texture = texture_resolver.call(pet) as Texture2D
	_apply_reference_rect(portrait, _fitted_texture_rect(BAG_SLOT_RECTS[slot_index], BAG_PORTRAIT_MAX_SIZE, portrait.texture))
	_bag_inventory_layer.add_child(portrait)

	var interaction := _bag_interaction_layer.get_node_or_null("BagSlotButton_%d" % slot_index) as TextureButton
	if interaction == null:
		return
	interaction.focus_mode = Control.FOCUS_ALL
	interaction.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	interaction.tooltip_text = String(pet.get("name", pet.get("id", "背包宠物")))
	interaction.accessibility_name = interaction.tooltip_text
	interaction.set_meta("bag_record", pet.duplicate(true))


func _add_bag_slot_interaction(slot_index: int) -> void:
	var interaction := TextureButton.new()
	interaction.name = "BagSlotButton_%d" % slot_index
	interaction.ignore_texture_size = true
	interaction.focus_mode = Control.FOCUS_NONE
	interaction.mouse_filter = Control.MOUSE_FILTER_STOP
	interaction.tooltip_text = "空背包槽 %d" % (slot_index + 1)
	interaction.accessibility_name = interaction.tooltip_text
	interaction.set_meta("bag_slot_index", slot_index)
	_apply_reference_rect(interaction, BAG_SLOT_RECTS[slot_index])
	interaction.mouse_entered.connect(_set_bag_slot_hovered.bind(slot_index, true))
	interaction.mouse_exited.connect(_set_bag_slot_hovered.bind(slot_index, false))
	_bag_interaction_layer.add_child(interaction)


func _party_portrait_rect(origin: Vector2, texture: Texture2D) -> Rect2:
	var slot_rect := Rect2(origin, PARTY_PORTRAIT_CENTER_OFFSET * 2.0)
	return _fitted_texture_rect(slot_rect, PARTY_PORTRAIT_MAX_SIZE, texture)


func _fitted_texture_rect(slot_rect: Rect2, maximum_size: Vector2, texture: Texture2D) -> Rect2:
	var fitted_size := maximum_size
	if texture != null:
		var source_size := texture.get_size()
		if source_size.x > 0.0 and source_size.y > 0.0:
			var fit_scale := minf(
				maximum_size.x / source_size.x,
				maximum_size.y / source_size.y
			)
			fitted_size = Vector2(
				_even_pixel_extent(source_size.x * fit_scale),
				_even_pixel_extent(source_size.y * fit_scale)
			)
	var center := slot_rect.get_center()
	var fitted_position := center - fitted_size * 0.5
	fitted_position = Vector2(floorf(fitted_position.x), floorf(fitted_position.y))
	return Rect2(fitted_position, fitted_size)


func _even_pixel_extent(value: float) -> float:
	var extent := maxi(2, int(roundf(value)))
	if extent % 2 != 0:
		extent -= 1
	return float(extent)


func _set_party_hovered(slot_index: int, hovered: bool) -> void:
	var shadow := _party_shadows.get(slot_index) as TextureRect
	if shadow == null or not is_instance_valid(shadow):
		return
	shadow.self_modulate = PARTY_SHADOW_HOVER_MODULATE if hovered else Color.WHITE


func _set_bag_slot_hovered(slot_index: int, hovered: bool) -> void:
	if not hovered:
		_bag_highlight.visible = false
		return
	if slot_index < 0 or slot_index >= BAG_SLOT_RECTS.size():
		return
	var slot_rect: Rect2 = BAG_SLOT_RECTS[slot_index]
	_apply_reference_rect(_bag_highlight, Rect2(
		slot_rect.position + BAG_HIGHLIGHT_OFFSET,
		BAG_HIGHLIGHT_SIZE
	))
	_bag_highlight.visible = true


func _emit_bag_requested() -> void:
	bag_requested.emit()


func _emit_exit_requested() -> void:
	exit_requested.emit()


func _on_exit_button_down() -> void:
	_exit_button.tooltip_text = ""


func _on_exit_button_up() -> void:
	_exit_button.tooltip_text = EXIT_TOOLTIP


func _apply_reference_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x / REFERENCE_SIZE.x
	control.anchor_top = rect.position.y / REFERENCE_SIZE.y
	control.anchor_right = rect.end.x / REFERENCE_SIZE.x
	control.anchor_bottom = rect.end.y / REFERENCE_SIZE.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
