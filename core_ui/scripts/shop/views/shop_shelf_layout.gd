extends Control
class_name ShopShelfLayout

## Presentation-only projection of public shop offers onto the authored shelf.
## This module never owns currency, inventory, refresh rules, or shop state.

signal command_requested(command: Dictionary)

const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const PAGE_SIZE := 5
const SLOT_RECTS := [
	Rect2(498.0, 360.0, 160.0, 190.0),
	Rect2(823.0, 360.0, 160.0, 190.0),
	Rect2(1148.0, 375.0, 160.0, 190.0),
	Rect2(498.0, 610.0, 160.0, 190.0),
	Rect2(1148.0, 610.0, 160.0, 190.0),
]
const PRICE_OFFSETS := [
	Vector2(5.0, 1.0),
	Vector2(1.0, 1.0),
	Vector2(0.0, -14.0),
	Vector2(5.0, 1.0),
	Vector2(-1.0, 1.0),
]

const COLOR_TEXT := Color("#f7e2a2")
const COLOR_MUTED := Color("#b8aa82")
const COLOR_HOVER := Color("#ffe69a")
const OFFER_PRICE_COLOR := Color(0.99, 0.84, 0.36, 1.0)
const OFFER_ICON_SIZE := 152
const OFFER_HOLD_FEEDBACK_SIZE := Vector2(126.0, 124.0)
const OFFER_HOLD_FEEDBACK_ALPHA := 0.82
const SLOPED_SLOT_INDEX := 2
const SLOPED_SLOT_ICON_THEME_OFFSET := 1.0

var _offers: Array = []
var _texture_resolver := Callable()
var _page := 0
var _offer_layer: Control = null
var _page_controls: Control = null
var _page_label: Label = null
var _previous_page_button: Button = null
var _next_page_button: Button = null
var _first_action_button: BaseButton = null
var _hold_feedback: TextureRect = null
var _hold_source_button: Button = null
var _hold_source_texture: Texture2D = null
var _hold_source_tooltip := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()


func render_offers(offers: Array, texture_resolver: Callable) -> void:
	_offers = offers.duplicate(true)
	_texture_resolver = texture_resolver
	var page_count := _page_count()
	_page = clampi(_page, 0, max(0, page_count - 1))
	_rebuild_offer_buttons()
	_render_page_controls()


func first_action_button() -> BaseButton:
	return _first_action_button


func current_page() -> int:
	return _page


func page_count() -> int:
	return _page_count()


func _build_shell() -> void:
	_offer_layer = Control.new()
	_offer_layer.name = "OfferLayer"
	_offer_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_offer_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_offer_layer)

	_page_controls = Control.new()
	_page_controls.name = "ShelfPageControls"
	_page_controls.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_reference_rect(_page_controls, Rect2(835.0, 815.0, 280.0, 44.0))
	add_child(_page_controls)

	_previous_page_button = _make_page_button("‹")
	_previous_page_button.name = "PreviousShelfPageButton"
	_previous_page_button.position = Vector2.ZERO
	_previous_page_button.size = Vector2(60.0, 44.0)
	_previous_page_button.pressed.connect(_change_page.bind(-1))
	_page_controls.add_child(_previous_page_button)

	_page_label = Label.new()
	_page_label.name = "ShelfPageLabel"
	_page_label.position = Vector2(65.0, 0.0)
	_page_label.size = Vector2(150.0, 44.0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 18)
	_page_label.add_theme_color_override("font_color", COLOR_TEXT)
	_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_controls.add_child(_page_label)

	_next_page_button = _make_page_button("›")
	_next_page_button.name = "NextShelfPageButton"
	_next_page_button.position = Vector2(220.0, 0.0)
	_next_page_button.size = Vector2(60.0, 44.0)
	_next_page_button.pressed.connect(_change_page.bind(1))
	_page_controls.add_child(_next_page_button)


func _rebuild_offer_buttons() -> void:
	_clear_offer_hold_feedback()
	_clear_children(_offer_layer)
	_first_action_button = null
	for offer_index in range(_offers.size()):
		var value = _offers[offer_index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var page_index := offer_index / PAGE_SIZE
		var slot_index := offer_index % PAGE_SIZE
		var offer := Dictionary(value)
		var slot := _make_offer_slot(offer, offer_index)
		slot.visible = page_index == _page
		_apply_reference_rect(slot, SLOT_RECTS[slot_index])
		_offer_layer.add_child(slot)


func _make_offer_slot(offer: Dictionary, offer_index: int) -> Control:
	var root := Control.new()
	root.name = "ShelfOffer_%02d" % offer_index
	root.mouse_filter = Control.MOUSE_FILTER_PASS

	var sold := bool(offer.get("sold", false))
	var frozen := bool(offer.get("frozen", false))
	var offer_id := String(offer.get("id", ""))
	var buy := Button.new()
	buy.name = "BuyOfferButton_%02d" % offer_index
	buy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buy.focus_mode = Control.FOCUS_ALL
	buy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy.expand_icon = true
	buy.add_theme_constant_override("icon_max_width", OFFER_ICON_SIZE)
	buy.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy.vertical_icon_alignment = (
		VERTICAL_ALIGNMENT_CENTER
		if offer_index % PAGE_SIZE == SLOPED_SLOT_INDEX
		else VERTICAL_ALIGNMENT_TOP
	)
	buy.flat = false
	buy.disabled = sold or offer_id == ""
	buy.modulate = Color.WHITE
	var offer_tooltip := _offer_tooltip(offer)
	buy.tooltip_text = offer_tooltip
	buy.accessibility_name = offer_tooltip
	var icon_vertical_offset := (
		SLOPED_SLOT_ICON_THEME_OFFSET
		if offer_index % PAGE_SIZE == SLOPED_SLOT_INDEX
		else 0.0
	)
	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	buy.add_theme_stylebox_override(
		"normal", _offer_style(transparent, transparent, 0, icon_vertical_offset)
	)
	buy.add_theme_stylebox_override(
		"hover", _offer_style(transparent, transparent, 0, icon_vertical_offset)
	)
	buy.add_theme_stylebox_override(
		"focus",
		_offer_style(Color(1.0, 0.88, 0.45, 0.08), COLOR_HOVER, 3, icon_vertical_offset)
	)
	buy.add_theme_stylebox_override(
		"pressed",
		_offer_style(transparent, transparent, 0, icon_vertical_offset)
	)
	buy.add_theme_stylebox_override(
		"disabled",
		_offer_style(transparent, transparent, 0, icon_vertical_offset)
	)
	if not sold and _texture_resolver.is_valid():
		buy.icon = _texture_resolver.call(offer) as Texture2D
	var buy_command := {"type": "BUY_OFFER", "offer_id": offer_id}
	buy.set_meta("command", buy_command)
	buy.set_meta("offer", offer.duplicate(true))
	buy.button_down.connect(_show_offer_hold_feedback.bind(buy))
	buy.button_up.connect(_clear_offer_hold_feedback)
	buy.pressed.connect(_emit_command.bind(buy_command))
	buy.mouse_entered.connect(_set_slot_mouse_highlight.bind(root, true))
	buy.mouse_exited.connect(_set_slot_mouse_highlight.bind(root, false))
	buy.focus_entered.connect(_set_slot_focus_highlight.bind(root, true))
	buy.focus_exited.connect(_set_slot_focus_highlight.bind(root, false))
	root.add_child(buy)
	if _first_action_button == null and not buy.disabled:
		_first_action_button = buy

	var price := Label.new()
	price.name = "PriceLabel"
	price.anchor_left = 0.18
	price.anchor_top = 0.90
	price.anchor_right = 0.82
	price.anchor_bottom = 1.0
	var price_offset: Vector2 = PRICE_OFFSETS[offer_index % PAGE_SIZE]
	price.offset_left = price_offset.x
	price.offset_top = price_offset.y
	price.offset_right = price_offset.x
	price.offset_bottom = price_offset.y
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.text = "" if sold else str(max(0, int(offer.get("price", 0))))
	price.add_theme_font_size_override("font_size", 18)
	price.add_theme_color_override("font_color", COLOR_MUTED if sold else OFFER_PRICE_COLOR)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(price)

	var freeze_command := {
		"type": "UNFREEZE_OFFER" if frozen else "FREEZE_OFFER",
		"offer_id": offer_id,
	}
	var freeze := Button.new()
	freeze.name = "FreezeOfferButton_%02d" % offer_index
	freeze.position = Vector2(126.0, 4.0)
	freeze.size = Vector2(30.0, 30.0)
	freeze.text = "解" if frozen else "锁"
	freeze.tooltip_text = "解锁商品" if frozen else "锁定商品"
	freeze.focus_mode = Control.FOCUS_ALL
	freeze.disabled = sold or offer_id == ""
	freeze.visible = frozen and not sold
	freeze.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	freeze.add_theme_font_size_override("font_size", 13)
	freeze.add_theme_color_override("font_color", COLOR_TEXT)
	freeze.add_theme_stylebox_override("normal", _slot_style(Color(0.08, 0.06, 0.03, 0.74), Color(0.42, 0.34, 0.18, 0.9), 1))
	freeze.add_theme_stylebox_override("hover", _slot_style(Color(0.24, 0.16, 0.05, 0.92), COLOR_HOVER, 2))
	freeze.set_meta("command", freeze_command)
	freeze.pressed.connect(_emit_command.bind(freeze_command))
	root.add_child(freeze)
	return root


func _process(_delta: float) -> void:
	if _hold_feedback == null or not is_instance_valid(_hold_feedback):
		return
	_position_offer_hold_feedback()


func _show_offer_hold_feedback(button: Button) -> void:
	_clear_offer_hold_feedback()
	if button == null or button.disabled or button.icon == null or _offer_layer == null:
		return
	_hold_source_button = button
	_hold_source_texture = button.icon
	_hold_source_tooltip = button.tooltip_text
	button.tooltip_text = ""
	button.icon = null
	_hold_feedback = TextureRect.new()
	_hold_feedback.name = "OfferHoldFeedback"
	_hold_feedback.texture = _hold_source_texture
	_hold_feedback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hold_feedback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hold_feedback.custom_minimum_size = OFFER_HOLD_FEEDBACK_SIZE
	_hold_feedback.size = OFFER_HOLD_FEEDBACK_SIZE
	_hold_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_feedback.self_modulate = Color(1.0, 1.0, 1.0, OFFER_HOLD_FEEDBACK_ALPHA)
	_hold_feedback.z_index = 100
	_offer_layer.add_child(_hold_feedback)
	_refresh_slot_highlight(button.get_parent_control())
	_position_offer_hold_feedback()


func _position_offer_hold_feedback() -> void:
	if _hold_feedback == null or not is_instance_valid(_hold_feedback) or _offer_layer == null:
		return
	_hold_feedback.position = _offer_layer.get_local_mouse_position() - OFFER_HOLD_FEEDBACK_SIZE * 0.5


func _clear_offer_hold_feedback() -> void:
	var source_button := _hold_source_button
	if _hold_source_button != null and is_instance_valid(_hold_source_button):
		_hold_source_button.icon = _hold_source_texture
		if _hold_source_button.is_hovered():
			_hold_source_button.tooltip_text = _hold_source_tooltip
		elif _hold_source_tooltip != "":
			_hold_source_button.mouse_entered.connect(
				_restore_offer_tooltip.bind(_hold_source_button, _hold_source_tooltip),
				CONNECT_ONE_SHOT
			)
	if _hold_feedback != null and is_instance_valid(_hold_feedback):
		_hold_feedback.queue_free()
	_hold_feedback = null
	_hold_source_button = null
	_hold_source_texture = null
	_hold_source_tooltip = ""
	if source_button != null and is_instance_valid(source_button):
		_refresh_slot_highlight(source_button.get_parent_control())


func _restore_offer_tooltip(button: Button, tooltip: String) -> void:
	if button != null and is_instance_valid(button):
		button.tooltip_text = tooltip


func _offer_tooltip(offer: Dictionary) -> String:
	var item_type := String(offer.get("item_type", "宠物" if String(offer.get("pet_id", "")) != "" else "商品"))
	var lines := PackedStringArray([
		String(offer.get("name", offer.get("id", "商品"))),
		"%s · %s · %s" % [String(offer.get("quality", "")), item_type, String(offer.get("role", ""))],
	])
	if item_type == "宠物":
		lines.append("HP %d · 攻 %d · 盾 %d" % [
			int(offer.get("max_hp", offer.get("hp", 0))),
			int(offer.get("atk", 0)),
			int(offer.get("shield", 0)),
		])
		lines.append("%s · %s" % [String(offer.get("shape", "")), String(offer.get("range", ""))])
	else:
		lines.append(String(offer.get("description", offer.get("effect_text", "购买后立即生效"))))
	return "\n".join(lines)


func _render_page_controls() -> void:
	var count := _page_count()
	_page_controls.visible = count > 1
	if count <= 1:
		return
	_page_label.text = "第 %d / %d 页" % [_page + 1, count]
	_previous_page_button.disabled = _page <= 0
	_next_page_button.disabled = _page >= count - 1


func _change_page(delta: int) -> void:
	var next_page := clampi(_page + delta, 0, max(0, _page_count() - 1))
	if next_page == _page:
		return
	_page = next_page
	_rebuild_offer_buttons()
	_render_page_controls()
	if _first_action_button != null:
		_first_action_button.grab_focus()


func _page_count() -> int:
	return maxi(1, ceili(float(_offers.size()) / float(PAGE_SIZE)))


func _emit_command(command: Dictionary) -> void:
	if not command.is_empty():
		command_requested.emit(command.duplicate(true))


func _set_slot_mouse_highlight(slot: Control, highlighted: bool) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	slot.set_meta("mouse_highlighted", highlighted)
	_refresh_slot_highlight(slot)


func _set_slot_focus_highlight(slot: Control, highlighted: bool) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	slot.set_meta("focus_highlighted", highlighted)
	_refresh_slot_highlight(slot)


func _refresh_slot_highlight(slot: Control) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	var highlighted := bool(slot.get_meta("mouse_highlighted", false)) or bool(slot.get_meta("focus_highlighted", false))
	slot.scale = Vector2.ONE
	slot.z_index = 4 if highlighted else 0
	var freeze := slot.find_child("FreezeOfferButton_*", true, false) as Button
	if freeze != null:
		var command := Dictionary(freeze.get_meta("command", {}))
		var stays_visible := String(command.get("type", "")) == "UNFREEZE_OFFER"
		var buy := slot.find_child("BuyOfferButton_*", true, false) as Button
		var offer_hold_active := buy != null and buy == _hold_source_button
		freeze.visible = not freeze.disabled and (highlighted or stays_visible) and not offer_hold_active


func _make_page_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _slot_style(Color(0.08, 0.06, 0.03, 0.82), Color(0.42, 0.34, 0.18, 0.9), 1))
	button.add_theme_stylebox_override("hover", _slot_style(Color(0.24, 0.16, 0.05, 0.94), COLOR_HOVER, 2))
	button.add_theme_stylebox_override("disabled", _slot_style(Color(0.06, 0.05, 0.04, 0.55), Color(0.2, 0.18, 0.14, 0.6), 1))
	return button


func _slot_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style


func _offer_style(
	fill: Color,
	border: Color,
	width: int,
	icon_vertical_offset := 0.0
) -> StyleBoxFlat:
	var style := _slot_style(fill, border, width)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0 + icon_vertical_offset
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0 - icon_vertical_offset
	return style


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
