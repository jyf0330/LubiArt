extends Control

## Temporary code-built shop that preserves the original single-player shop's
## information hierarchy while the authored LubiArt shop is unfinished.
## It owns presentation only and emits public player-intent commands.

signal command_requested(command: Dictionary)

const COLOR_BACKGROUND := Color("#171713")
const COLOR_PANEL := Color("#20211d")
const COLOR_PANEL_HOVER := Color("#292b25")
const COLOR_BORDER := Color("#5e6658")
const COLOR_GOLD := Color("#f8d080")
const COLOR_TITLE := Color("#f5e5b8")
const COLOR_TEXT := Color("#dce6d4")
const COLOR_MUTED := Color("#aebcad")
const COLOR_SUCCESS := Color("#9bd29a")
const COLOR_FAILURE := Color("#ee9b8e")

var _snapshot: Dictionary = {}
var _texture_resolver := Callable()
var _main_column: VBoxContainer = null
var _offer_grid: VBoxContainer = null
var _roster_side: VBoxContainer = null
var _status_label: Label = null
var _feedback_label: Label = null
var _refresh_button: Button = null
var _exit_button: Button = null
var _first_action_button: Button = null
var _feedback_text := ""
var _feedback_success := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	visible = false


func configure(texture_resolver: Callable) -> void:
	_texture_resolver = texture_resolver


func render_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if not is_node_ready():
		return
	_render_header()
	_render_toolbar()
	_render_offers()
	_render_roster_and_events()
	_render_feedback()


func show_command_feedback(message: String, success: bool) -> void:
	_feedback_text = message.strip_edges()
	_feedback_success = success
	_render_feedback()


func grab_initial_focus() -> void:
	if not visible:
		return
	if _first_action_button != null and is_instance_valid(_first_action_button) and not _first_action_button.disabled:
		_first_action_button.grab_focus()
	elif _refresh_button != null and is_instance_valid(_refresh_button) and not _refresh_button.disabled:
		_refresh_button.grab_focus()
	elif _exit_button != null and is_instance_valid(_exit_button):
		_exit_button.grab_focus()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = COLOR_BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "SafeArea"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	_main_column = VBoxContainer.new()
	_main_column.name = "MainColumn"
	_main_column.add_theme_constant_override("separation", 16)
	margin.add_child(_main_column)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 16)
	_main_column.add_child(header)

	var title := _make_label("元素背包史 · 商店", 34, COLOR_TITLE)
	title.name = "TitleLabel"
	title.custom_minimum_size = Vector2(420, 52)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	_status_label = _make_label("", 23, COLOR_TEXT)
	_status_label.name = "StatusLabel"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_status_label)

	var toolbar := HBoxContainer.new()
	toolbar.name = "Toolbar"
	toolbar.add_theme_constant_override("separation", 12)
	_main_column.add_child(toolbar)

	_exit_button = _make_action_button("离开商店")
	_exit_button.name = "ExitShopButton"
	_exit_button.set_meta("command", {"type": "EXIT_SHOP"})
	_exit_button.pressed.connect(_emit_command.bind({"type": "EXIT_SHOP"}))
	toolbar.add_child(_exit_button)

	_refresh_button = _make_action_button("刷新商店")
	_refresh_button.name = "RollShopButton"
	_refresh_button.set_meta("command", {"type": "ROLL_SHOP"})
	_refresh_button.pressed.connect(_emit_command.bind({"type": "ROLL_SHOP"}))
	toolbar.add_child(_refresh_button)

	_feedback_label = _make_label("", 18, COLOR_MUTED)
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(_feedback_label)

	var summary_box := VBoxContainer.new()
	summary_box.name = "ShopSummary"
	summary_box.add_theme_constant_override("separation", 4)
	_main_column.add_child(summary_box)

	var body := HBoxContainer.new()
	body.name = "ShopBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	_main_column.add_child(body)

	var offer_scroll := ScrollContainer.new()
	offer_scroll.name = "ShopScroll"
	offer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	offer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(offer_scroll)

	_offer_grid = VBoxContainer.new()
	_offer_grid.name = "ShopGrid"
	_offer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_grid.add_theme_constant_override("separation", 12)
	offer_scroll.add_child(_offer_grid)

	var roster_scroll := ScrollContainer.new()
	roster_scroll.name = "ShopRosterScroll"
	roster_scroll.custom_minimum_size = Vector2(470, 0)
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(roster_scroll)

	_roster_side = VBoxContainer.new()
	_roster_side.name = "ShopRosterSide"
	_roster_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_side.add_theme_constant_override("separation", 10)
	roster_scroll.add_child(_roster_side)


func _render_header() -> void:
	if _status_label == null:
		return
	_status_label.text = "第 %d 天 · 节点 %d · 金币 %d · 英雄生命 %d · AP %d" % [
		int(_snapshot.get("day", 0)),
		int(_snapshot.get("node_index", _snapshot.get("nodeIndex", 0))),
		int(_snapshot.get("coins", 0)),
		int(_snapshot.get("hero_hp", _snapshot.get("heroHp", 0))),
		int(_snapshot.get("ap", 0)),
	]

	var summary := _main_column.get_node_or_null("ShopSummary") as VBoxContainer
	_clear_children(summary)
	if summary == null:
		return
	var stall := Dictionary(_snapshot.get("active_stall", {}))
	var offers := Array(_snapshot.get("shop_offers", []))
	var stall_name := String(stall.get("name", stall.get("label", "宠物商店")))
	summary.add_child(_make_label(stall_name, 30, COLOR_GOLD))
	summary.add_child(_make_label("本次可购买 %d 件商品。购买后进入背包，可带入战斗。" % offers.size(), 19, COLOR_TEXT))
	var refresh := Dictionary(_snapshot.get("shop_refresh", {}))
	summary.add_child(_make_label("刷新：免费 %d · 下次 %d 金 · 折扣 %d%%" % [
		int(refresh.get("free_rolls", 0)),
		int(refresh.get("next_refresh_cost", 0)),
		int(refresh.get("next_discount", 0)),
	], 17, COLOR_MUTED))


func _render_toolbar() -> void:
	if _refresh_button == null:
		return
	var refresh := Dictionary(_snapshot.get("shop_refresh", {}))
	var free_rolls := int(refresh.get("free_rolls", 0))
	var next_cost := int(refresh.get("next_refresh_cost", 0))
	_refresh_button.text = "刷新商店（免费）" if free_rolls > 0 else "刷新商店（%d 金币）" % next_cost
	_refresh_button.disabled = free_rolls <= 0 and int(_snapshot.get("coins", 0)) < next_cost


func _render_offers() -> void:
	_clear_children(_offer_grid)
	_first_action_button = null
	if _offer_grid == null:
		return
	var offers := Array(_snapshot.get("shop_offers", []))
	if offers.is_empty():
		_offer_grid.add_child(_make_label("本店商品已售完。", 24, COLOR_MUTED))
		return
	for value in offers:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		_offer_grid.add_child(_make_offer_card(Dictionary(value)))


func _make_offer_card(offer: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Offer_%s" % _node_suffix(String(offer.get("id", "offer")))
	panel.custom_minimum_size = Vector2(0, 158)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 2, 10))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(118, 118)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _texture_resolver.is_valid():
		portrait.texture = _texture_resolver.call(offer) as Texture2D
	row.add_child(portrait)

	var details := VBoxContainer.new()
	details.name = "Details"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 5)
	row.add_child(details)

	var item_type := String(offer.get("item_type", "宠物" if String(offer.get("pet_id", "")) != "" else "商品"))
	var element := String(offer.get("element", ""))
	details.add_child(_make_label("%s  %s" % [String(offer.get("name", offer.get("id", "商品"))), element], 24, COLOR_TITLE))
	details.add_child(_make_label("%s · %s · %s" % [String(offer.get("quality", "")), item_type, String(offer.get("role", ""))], 17, COLOR_TEXT))
	if item_type == "宠物":
		details.add_child(_make_label("HP %d · 攻 %d · 盾 %d · %s · %s" % [
			int(offer.get("max_hp", offer.get("hp", 0))),
			int(offer.get("atk", 0)),
			int(offer.get("shield", 0)),
			String(offer.get("shape", "")),
			String(offer.get("range", "")),
		], 16, COLOR_MUTED))
	else:
		details.add_child(_make_label(String(offer.get("description", offer.get("effect_text", "购买后立即生效"))), 16, COLOR_MUTED))

	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.custom_minimum_size = Vector2(190, 0)
	actions.add_theme_constant_override("separation", 8)
	row.add_child(actions)

	var sold := bool(offer.get("sold", false))
	var price: int = max(0, int(offer.get("price", 0)))
	var buy := _make_action_button("已售罄" if sold else "购买 · %d 金币" % price)
	buy.name = "BuyOfferButton_%s" % _node_suffix(String(offer.get("id", "offer")))
	buy.disabled = sold
	var buy_command := {"type": "BUY_OFFER", "offer_id": String(offer.get("id", ""))}
	buy.set_meta("command", buy_command)
	buy.set_meta("offer", offer.duplicate(true))
	buy.pressed.connect(_emit_command.bind(buy_command))
	actions.add_child(buy)
	if _first_action_button == null and not buy.disabled:
		_first_action_button = buy

	var frozen := bool(offer.get("frozen", false))
	var freeze_command := {
		"type": "UNFREEZE_OFFER" if frozen else "FREEZE_OFFER",
		"offer_id": String(offer.get("id", "")),
	}
	var freeze := _make_secondary_button("解锁商品" if frozen else "锁定商品")
	freeze.name = "FreezeOfferButton_%s" % _node_suffix(String(offer.get("id", "offer")))
	freeze.disabled = sold
	freeze.set_meta("command", freeze_command)
	freeze.pressed.connect(_emit_command.bind(freeze_command))
	actions.add_child(freeze)
	return panel


func _render_roster_and_events() -> void:
	_clear_children(_roster_side)
	if _roster_side == null:
		return
	var inventory := Dictionary(_snapshot.get("inventory", {}))
	_roster_side.add_child(_make_label("当前队伍", 24, COLOR_GOLD))
	_roster_side.add_child(_make_label("上阵 %d/%d · 背包 %d/%d" % [
		int(inventory.get("active_count", _active_roster_count())),
		int(inventory.get("max_active", 4)),
		int(inventory.get("bench_count", _bench_roster_count())),
		int(inventory.get("max_bench", 24)),
	], 17, COLOR_TEXT))

	var roster := Array(_snapshot.get("roster", []))
	if roster.is_empty():
		_roster_side.add_child(_make_label("队伍为空", 16, COLOR_MUTED))
	else:
		for value in roster:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var pet := Dictionary(value)
			var location := "上阵" if bool(pet.get("active", true)) else "背包"
			_roster_side.add_child(_make_label("%s · %s · %s" % [
				location,
				String(pet.get("name", pet.get("pet_id", pet.get("id", "宠物")))),
				String(pet.get("quality", "")),
			], 16, COLOR_TEXT))

	var events := Array(_snapshot.get("shop_events", []))
	if events.is_empty():
		return
	_roster_side.add_child(_make_label("商店事件", 22, COLOR_GOLD))
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
		_roster_side.add_child(button)


func _render_feedback() -> void:
	if _feedback_label == null:
		return
	_feedback_label.text = _feedback_text
	_feedback_label.add_theme_color_override("font_color", COLOR_SUCCESS if _feedback_success else COLOR_FAILURE)


func _emit_command(command: Dictionary) -> void:
	if command.is_empty():
		return
	command_requested.emit(command.duplicate(true))


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 50)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#2d3028"), Color("#7f8c70"), 2, 8))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#3a4033"), Color("#abc18f"), 2, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#20251d"), COLOR_GOLD, 2, 8))
	button.add_theme_stylebox_override("focus", _panel_style(Color("#343a2d"), COLOR_GOLD, 3, 8))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#24241f"), Color("#44463f"), 1, 8))
	return button


func _make_secondary_button(text: String) -> Button:
	var button := _make_action_button(text)
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#253134"), Color("#597c86"), 2, 8))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#31464b"), Color("#79aeb8"), 2, 8))
	return button


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
