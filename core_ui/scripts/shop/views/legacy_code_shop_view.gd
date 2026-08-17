extends Control

## Formal shop projection. Authority remains behind the public snapshot/command
## boundary; this view only composes independently implemented presentation.

signal command_requested(command: Dictionary)

const ShopArtBackdropScript := preload("res://core_ui/scripts/shop/views/shop_art_backdrop.gd")
const ShopShelfLayoutScript := preload("res://core_ui/scripts/shop/views/shop_shelf_layout.gd")
const ShopSharedRailScript := preload("res://core_ui/scripts/shop/views/shop_shared_rail.gd")
const DEFAULT_MERCHANT_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/merchant_default.png")
const REFRESH_BELL_NORMAL := preload("res://art/images/shop/screen_shop_godot_v1/refresh_bell_normal.png")
const REFRESH_BELL_HOVER := preload("res://art/images/shop/screen_shop_godot_v1/refresh_bell_hover.png")

const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const COLOR_GOLD := Color("#f8d080")
const COLOR_TITLE := Color("#f5e5b8")
const COLOR_TEXT := Color("#dce6d4")
const COLOR_MUTED := Color("#aebcad")
const COLOR_SUCCESS := Color("#a8e3a6")
const COLOR_FAILURE := Color("#ffaaa0")
const COLOR_PENDING := Color("#f8d080")

var _snapshot: Dictionary = {}
var _texture_resolver := Callable()
var _character_texture_resolver := Callable()
var _backdrop: Control = null
var _shelf_layout: Control = null
var _shared_rail: Control = null
var _merchant_portrait: TextureRect = null
var _summary_details: VBoxContainer = null
var _details_drawer: PanelContainer = null
var _details_content: VBoxContainer = null
var _status_label: Label = null
var _feedback_label: Label = null
var _refresh_button: TextureButton = null
var _exit_button: BaseButton = null
var _first_action_button: BaseButton = null
var _feedback_text := ""
var _feedback_success := true
var _feedback_pending := false
var _refresh_reveal_in_progress := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	visible = false
	visibility_changed.connect(_on_visibility_changed)


func configure(texture_resolver: Callable, character_texture_resolver := Callable()) -> void:
	_texture_resolver = texture_resolver
	_character_texture_resolver = character_texture_resolver


func render_snapshot(snapshot: Dictionary) -> void:
	# Public Snapshots are immutable presentation inputs. Retaining the shared
	# reference avoids cloning the full payload for this read-only shop view.
	_snapshot = snapshot
	if not is_node_ready():
		return
	_render_header()
	_render_toolbar()
	_render_offers()
	_render_roster_and_events()
	_render_feedback()


func render_command_delta(snapshot: Dictionary, command_type: String) -> void:
	_snapshot = snapshot
	if not is_node_ready():
		return
	if command_type in ["CHOOSE_ROUTE", "ENTER_SHOP"]:
		_render_header()
	else:
		_status_label.text = "第 %d 天 · 节点 %d · 金币 %d · 英雄生命 %d · AP %d" % [
			int(_snapshot.get("day", 0)),
			int(_snapshot.get("node_index", _snapshot.get("nodeIndex", 0))),
			int(_snapshot.get("coins", 0)),
			int(_snapshot.get("hero_hp", _snapshot.get("heroHp", 0))),
			int(_snapshot.get("ap", 0)),
		]
		_shared_rail.call("render_coin", int(_snapshot.get("coins", 0)))
	_render_toolbar()
	_render_offers()
	if command_type in ["CHOOSE_ROUTE", "ENTER_SHOP", "BUY_OFFER"]:
		_shared_rail.call("render_party", Array(_snapshot.get("roster", [])), _texture_resolver)
	_render_feedback()


func show_command_feedback(message: String, success: bool) -> void:
	_feedback_text = message.strip_edges()
	_feedback_success = success
	_feedback_pending = false
	_render_feedback()


func show_command_pending(message: String) -> void:
	_feedback_text = message.strip_edges()
	_feedback_pending = true
	_render_feedback()


func grab_initial_focus() -> void:
	if not visible:
		return
	if _first_action_button != null and is_instance_valid(_first_action_button) and not _first_action_button.disabled:
		_first_action_button.grab_focus()
	elif _refresh_button != null and not _refresh_button.disabled:
		_refresh_button.grab_focus()
	elif _exit_button != null:
		_exit_button.grab_focus()


func _build_shell() -> void:
	_backdrop = ShopArtBackdropScript.new() as Control
	_backdrop.name = "ShopArtBackdrop"
	_backdrop.connect("refresh_reveal_finished", _on_refresh_reveal_finished)
	add_child(_backdrop)

	var safe_area := Control.new()
	safe_area.name = "SafeArea"
	safe_area.mouse_filter = Control.MOUSE_FILTER_PASS
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe_area)

	var main_column := Control.new()
	main_column.name = "MainColumn"
	main_column.mouse_filter = Control.MOUSE_FILTER_PASS
	main_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_child(main_column)

	var header := Control.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_column.add_child(header)

	var title := _make_label("元素背包史 · 商店", 28, COLOR_TITLE)
	title.name = "TitleLabel"
	_apply_reference_rect(title, Rect2(36.0, 22.0, 410.0, 48.0))
	header.add_child(title)

	_status_label = _make_label("", 17, COLOR_TEXT)
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_reference_rect(_status_label, Rect2(1050.0, 22.0, 830.0, 48.0))
	header.add_child(_status_label)

	_feedback_label = _make_label("", 17, COLOR_MUTED)
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_reference_rect(_feedback_label, Rect2(1190.0, 76.0, 690.0, 36.0))
	header.add_child(_feedback_label)

	var summary := Control.new()
	summary.name = "ShopSummary"
	summary.mouse_filter = Control.MOUSE_FILTER_PASS
	summary.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_column.add_child(summary)

	_merchant_portrait = TextureRect.new()
	_merchant_portrait.name = "MerchantPortrait"
	_merchant_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_merchant_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_merchant_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_merchant_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merchant_portrait.z_index = 3
	_merchant_portrait.visible = false
	_apply_reference_rect(_merchant_portrait, Rect2(813.0, 580.0, 177.0, 202.0))
	summary.add_child(_merchant_portrait)

	_summary_details = VBoxContainer.new()
	_summary_details.name = "SummaryDetails"
	_summary_details.alignment = BoxContainer.ALIGNMENT_CENTER
	_summary_details.add_theme_constant_override("separation", 0)
	_summary_details.z_index = 6
	_apply_reference_rect(_summary_details, Rect2(710.0, 118.0, 500.0, 90.0))
	summary.add_child(_summary_details)

	_shelf_layout = ShopShelfLayoutScript.new() as Control
	_shelf_layout.name = "ShopShelfLayout"
	_shelf_layout.z_index = 5
	_shelf_layout.command_requested.connect(_emit_command)
	main_column.add_child(_shelf_layout)

	_shared_rail = ShopSharedRailScript.new() as Control
	_shared_rail.name = "ShopSharedRail"
	_shared_rail.z_index = 8
	_shared_rail.bag_requested.connect(_toggle_bag_overlay)
	_shared_rail.exit_requested.connect(_on_exit_requested)
	main_column.add_child(_shared_rail)
	_exit_button = _shared_rail.call("exit_button") as BaseButton
	_exit_button.set_meta("command", {"type": "EXIT_SHOP"})

	_refresh_button = TextureButton.new()
	_refresh_button.name = "RollShopButton"
	_refresh_button.texture_normal = REFRESH_BELL_NORMAL
	_refresh_button.texture_hover = REFRESH_BELL_HOVER
	_refresh_button.texture_pressed = REFRESH_BELL_HOVER
	_refresh_button.texture_focused = REFRESH_BELL_HOVER
	_refresh_button.ignore_texture_size = true
	_refresh_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_refresh_button.focus_mode = Control.FOCUS_ALL
	_refresh_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_refresh_button.set_meta("command", {"type": "ROLL_SHOP"})
	_apply_reference_rect(_refresh_button, Rect2(945.0, 712.0, 89.0, 86.0))
	_refresh_button.z_index = 10
	_refresh_button.pressed.connect(_on_refresh_requested)
	main_column.add_child(_refresh_button)

	var details_button := Button.new()
	details_button.name = "ShopDetailsButton"
	details_button.text = "队伍 / 事件"
	details_button.visible = false
	details_button.focus_mode = Control.FOCUS_ALL
	details_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	details_button.add_theme_font_size_override("font_size", 16)
	details_button.add_theme_color_override("font_color", COLOR_TEXT)
	details_button.add_theme_stylebox_override("normal", _panel_style(Color(0.03, 0.055, 0.055, 0.78), Color(0.42, 0.54, 0.48, 0.9), 1, 8))
	details_button.add_theme_stylebox_override("hover", _panel_style(Color(0.06, 0.10, 0.09, 0.92), COLOR_GOLD, 2, 8))
	_apply_reference_rect(details_button, Rect2(1680.0, 92.0, 174.0, 44.0))
	details_button.z_index = 20
	details_button.pressed.connect(_toggle_details_drawer)
	main_column.add_child(details_button)

	_details_drawer = PanelContainer.new()
	_details_drawer.name = "ShopDetailsDrawer"
	_details_drawer.visible = false
	_details_drawer.z_index = 19
	_details_drawer.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.045, 0.043, 0.96), Color("#a9874e"), 2, 12))
	_apply_reference_rect(_details_drawer, Rect2(1390.0, 145.0, 464.0, 650.0))
	main_column.add_child(_details_drawer)

	var drawer_margin := MarginContainer.new()
	drawer_margin.add_theme_constant_override("margin_left", 18)
	drawer_margin.add_theme_constant_override("margin_top", 16)
	drawer_margin.add_theme_constant_override("margin_right", 18)
	drawer_margin.add_theme_constant_override("margin_bottom", 16)
	_details_drawer.add_child(drawer_margin)

	var drawer_scroll := ScrollContainer.new()
	drawer_scroll.name = "ShopRosterScroll"
	drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer_margin.add_child(drawer_scroll)

	_details_content = VBoxContainer.new()
	_details_content.name = "ShopRosterSide"
	_details_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_content.add_theme_constant_override("separation", 9)
	drawer_scroll.add_child(_details_content)


func _render_header() -> void:
	_status_label.text = "第 %d 天 · 节点 %d · 金币 %d · 英雄生命 %d · AP %d" % [
		int(_snapshot.get("day", 0)),
		int(_snapshot.get("node_index", _snapshot.get("nodeIndex", 0))),
		int(_snapshot.get("coins", 0)),
		int(_snapshot.get("hero_hp", _snapshot.get("heroHp", 0))),
		int(_snapshot.get("ap", 0)),
	]
	_shared_rail.call("render_coin", int(_snapshot.get("coins", 0)))

	_clear_children(_summary_details)
	var stall := Dictionary(_snapshot.get("active_stall", {}))
	var merchant_texture := _character_texture_resolver.call(stall) as Texture2D if _character_texture_resolver.is_valid() else null
	if merchant_texture == null:
		merchant_texture = DEFAULT_MERCHANT_TEXTURE
	_merchant_portrait.texture = merchant_texture
	_merchant_portrait.visible = merchant_texture != null
	var offers := Array(_snapshot.get("shop_offers", []))
	var stall_name := String(stall.get("name", stall.get("label", "宠物商店")))
	var name_label := _make_label(stall_name, 25, COLOR_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_details.add_child(name_label)
	var offer_label := _make_label("本次可购买 %d 件商品" % offers.size(), 16, COLOR_TEXT)
	offer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_details.add_child(offer_label)


func _render_toolbar() -> void:
	var refresh := Dictionary(_snapshot.get("shop_refresh", {}))
	var free_rolls := int(refresh.get("free_rolls", 0))
	var next_cost := int(refresh.get("next_refresh_cost", 0))
	_refresh_button.tooltip_text = "刷新商店（免费）" if free_rolls > 0 else "刷新商店（%d 金币）" % next_cost
	_refresh_button.accessibility_name = _refresh_button.tooltip_text
	_refresh_button.disabled = _refresh_reveal_in_progress or (free_rolls <= 0 and int(_snapshot.get("coins", 0)) < next_cost)


func _render_offers() -> void:
	_shelf_layout.call("render_offers", Array(_snapshot.get("shop_offers", [])), _texture_resolver)
	_first_action_button = _shelf_layout.call("first_action_button") as BaseButton


func _render_roster_and_events() -> void:
	_clear_children(_details_content)
	var inventory := Dictionary(_snapshot.get("inventory", {}))
	_details_content.add_child(_make_label("当前队伍", 24, COLOR_GOLD))
	_details_content.add_child(_make_label("上阵 %d/%d · 背包 %d/%d" % [
		int(inventory.get("active_count", _active_roster_count())),
		int(inventory.get("max_active", 4)),
		int(inventory.get("bench_count", _bench_roster_count())),
		int(inventory.get("max_bench", 24)),
	], 17, COLOR_TEXT))

	var roster := Array(_snapshot.get("roster", []))
	_shared_rail.call("render_party", roster, _texture_resolver)
	for value in roster:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var pet := Dictionary(value)
		var active := bool(pet.get("active", true))
		var location := "上阵" if active else "背包"
		_details_content.add_child(_make_label("%s · %s · %s" % [
			location,
			String(pet.get("name", pet.get("pet_id", pet.get("id", "宠物")))),
			String(pet.get("quality", "")),
		], 16, COLOR_TEXT))
	if roster.is_empty():
		_details_content.add_child(_make_label("队伍为空", 16, COLOR_MUTED))

	var events := Array(_snapshot.get("shop_events", []))
	if events.is_empty():
		return
	_details_content.add_child(_make_label("商店事件", 22, COLOR_GOLD))
	for value in events:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var event := Dictionary(value)
		var event_id := String(event.get("id", ""))
		var button := _make_secondary_button("%s · %s" % [
			String(event.get("name", event_id)),
			String(event.get("cost", "无消耗")),
		])
		button.name = "ShopEventButton_%s" % _node_suffix(event_id)
		button.tooltip_text = String(event.get("gain", event.get("option_text", "已结算")))
		var command := {"type": "APPLY_SHOP_EVENT", "eventId": event_id}
		button.set_meta("command", command)
		button.pressed.connect(_emit_command.bind(command))
		_details_content.add_child(button)


func _render_feedback() -> void:
	_feedback_label.text = _feedback_text
	var color := COLOR_PENDING if _feedback_pending else (COLOR_SUCCESS if _feedback_success else COLOR_FAILURE)
	_feedback_label.add_theme_color_override("font_color", color)


func _emit_command(command: Dictionary) -> void:
	if not command.is_empty():
		command_requested.emit(command.duplicate(true))


func _on_refresh_requested() -> void:
	if _refresh_reveal_in_progress:
		return
	_refresh_reveal_in_progress = true
	_render_toolbar()
	if _backdrop != null:
		_backdrop.call("play_refresh_reveal")
	_emit_command({"type": "ROLL_SHOP"})


func _on_refresh_reveal_finished() -> void:
	_refresh_reveal_in_progress = false
	_render_toolbar()


func _on_exit_requested() -> void:
	_emit_command({"type": "EXIT_SHOP"})


func _toggle_details_drawer() -> void:
	_details_drawer.visible = not _details_drawer.visible


func _toggle_bag_overlay() -> void:
	_shared_rail.call("toggle_bag")


func _on_visibility_changed() -> void:
	# The view instance is intentionally reused between route visits. Bag state is
	# presentation-only, so every new visible shop visit starts from its closed
	# state instead of leaking the previous visit's overlay.
	if visible and _shared_rail != null:
		_shared_rail.call("set_bag_open", false)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.025, 0.02, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_secondary_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#253134"), Color("#597c86"), 2, 8))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#31464b"), Color("#79aeb8"), 2, 8))
	return button


func _apply_transparent_button_styles(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 10))
	button.add_theme_stylebox_override("hover", _panel_style(Color(1.0, 0.9, 0.42, 0.08), COLOR_GOLD, 2, 10))
	button.add_theme_stylebox_override("focus", _panel_style(Color(1.0, 0.9, 0.42, 0.06), COLOR_GOLD, 3, 10))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.2, 0.12, 0.03, 0.16), COLOR_GOLD, 2, 10))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.05, 0.05, 0.05, 0.12), Color(0.0, 0.0, 0.0, 0.0), 0, 10))


func _panel_style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
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
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _active_roster_count() -> int:
	var count := 0
	for value in Array(_snapshot.get("roster", [])):
		if typeof(value) == TYPE_DICTIONARY and bool(Dictionary(value).get("active", true)):
			count += 1
	return count


func _bench_roster_count() -> int:
	var count := 0
	for value in Array(_snapshot.get("roster", [])):
		if typeof(value) == TYPE_DICTIONARY and not bool(Dictionary(value).get("active", true)):
			count += 1
	return count


func _node_suffix(value: String) -> String:
	var result := value.strip_edges()
	for character in ["/", "\\", ":", ".", " ", "@", "#"]:
		result = result.replace(character, "_")
	return result if result != "" else "item"
