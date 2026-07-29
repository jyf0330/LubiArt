extends PanelContainer
class_name SpriteInfoCardDebugPanel

const CARD_SCENE := preload("res://art/prefabs/pet/sprite_info_card.tscn")
const ELEMENT_NAMES := ["暗", "水", "冰", "草", "电", "风", "火", "龙", "土"]
const QUALITY_NAMES := ["青铜", "白银", "黄金", "水晶"]
const TRAIT_NAMES := ["自愈", "本命爆发", "护体", "连击倍增", "收尾暴击", "元素回响", "越战越勇", "壮体"]
const PET_NAMES := ["星茸", "烬尾狐", "霜团子", "青雷貂", "月壳龟", "琉璃星狐"]

var _card: Control
var _pet_name_button: Button
var _element_selector: OptionButton
var _quality_selector: OptionButton
var _trait_selector: OptionButton
var _trait_lock_button: Button
var _apply_values_button: Button
var _status_label: Label
var _value_edits: Dictionary = {}
var _pet_name_index := 0


func _ready() -> void:
	custom_minimum_size = Vector2(1040.0, 760.0)
	_apply_panel_style()
	_build_interface()
	call_deferred("_initialize_controls")


func debug_cycle_pet_name() -> String:
	_pet_name_index = posmod(_pet_name_index + 1, PET_NAMES.size())
	_apply_pet_name()
	return PET_NAMES[_pet_name_index]


func get_debug_pet_names() -> PackedStringArray:
	return PackedStringArray(PET_NAMES)


func debug_select_element(index: int) -> bool:
	if _card == null or index < 0 or index >= ELEMENT_NAMES.size():
		_set_status("属性选择无效", false)
		return false
	_element_selector.select(index)
	if not bool(_card.call("set_element_art_by_index", index)):
		_set_status("ElementArt 切换失败", false)
		return false
	_set_status("ElementArt 已选择：%s" % ELEMENT_NAMES[index], true)
	return true


func debug_select_quality(index: int) -> bool:
	if _card == null or index < 0 or index >= QUALITY_NAMES.size():
		_set_status("品质选择无效", false)
		return false
	_quality_selector.select(index)
	if not bool(_card.call("set_quality_art_exclusive_by_index", index)):
		_set_status("品质切换失败", false)
		return false
	var record := Dictionary(_card.call("get_info_snapshot"))
	record["quality"] = QUALITY_NAMES[index]
	_card.call("set_info", record)
	_card.call("set_quality_art_exclusive_by_index", index)
	_set_status("当前只显示%s：BaseArt、AttackFormatPlate、StatSlotArt 已同步" % QUALITY_NAMES[index], true)
	return true


func debug_set_trait_lock_visible(lock_visible: bool) -> bool:
	if _card == null:
		_set_status("找不到 SpriteInfoCard", false)
		return false
	var lock_art := _card.get_node_or_null("TraitLockSilver") as CanvasItem
	if lock_art == null:
		_set_status("找不到 TraitLockSilver", false)
		return false
	lock_art.visible = lock_visible
	_trait_selector.disabled = lock_visible
	_refresh_lock_button_text(lock_visible)
	if lock_visible:
		_set_status("TraitLockSilver 已显示；TraitArt 选择已锁定", true)
	else:
		_card.call("set_silver_trait_by_index", _trait_selector.selected)
		_set_status("TraitLockSilver 已隐藏；现在可以选择 TraitArt", true)
	return true


func debug_toggle_trait_lock() -> bool:
	if _card == null:
		return false
	var lock_art := _card.get_node_or_null("TraitLockSilver") as CanvasItem
	if lock_art == null:
		return false
	debug_set_trait_lock_visible(not lock_art.visible)
	return lock_art.visible


func debug_select_trait(index: int) -> bool:
	if _card == null or index < 0 or index >= TRAIT_NAMES.size():
		_set_status("特性选择无效", false)
		return false
	var lock_art := _card.get_node_or_null("TraitLockSilver") as CanvasItem
	if lock_art == null or lock_art.visible:
		_set_status("请先隐藏 TraitLockSilver，再选择 TraitArt", false)
		return false
	_trait_selector.select(index)
	if not bool(_card.call("set_silver_trait_by_index", index)):
		_set_status("TraitArt 切换失败", false)
		return false
	_set_status("TraitArt 已选择：%s" % TRAIT_NAMES[index], true)
	return true


func debug_apply_values() -> Dictionary:
	if _card == null:
		_set_status("找不到 SpriteInfoCard", false)
		return {}
	var record := Dictionary(_card.call("get_info_snapshot"))
	var hp_pair := _parse_pair(_edit_text("hp"), int(record.get("hp", 0)), int(record.get("max_hp", 0)))
	var ap_pair := _parse_pair(_edit_text("ap"), int(record.get("ap", 0)), int(record.get("max_ap", 0)))
	record["hp"] = hp_pair.x
	record["max_hp"] = hp_pair.y
	record["attack"] = _parse_non_negative_int(_edit_text("attack"), int(record.get("attack", 0)))
	record["ap"] = ap_pair.x
	record["max_ap"] = ap_pair.y
	record["defense"] = _parse_non_negative_int(_edit_text("defense"), int(record.get("defense", 0)))
	record["shield"] = _parse_non_negative_int(_edit_text("shield"), int(record.get("shield", 0)))
	record["regen"] = _parse_non_negative_int(_edit_text("regen"), int(record.get("regen", 0)))
	var result := Dictionary(_card.call("set_info", record))
	_sync_value_fields(result)
	_set_status("六项 Value 已写入 SpriteInfoCard", true)
	return result


func debug_set_values(values: Dictionary) -> Dictionary:
	if values.has("hp"):
		_set_edit_text("hp", _pair_text(values.get("hp"), values.get("max_hp", values.get("hp"))))
	if values.has("attack"):
		_set_edit_text("attack", str(values["attack"]))
	if values.has("ap"):
		_set_edit_text("ap", _pair_text(values.get("ap"), values.get("max_ap", values.get("ap"))))
	for key in ["defense", "shield", "regen"]:
		if values.has(key):
			_set_edit_text(key, str(values[key]))
	return debug_apply_values()


func debug_card() -> Control:
	return _card


func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var title := _make_label("SpriteInfoCard 独立调试面板", 25, Color("dbefff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var help := _make_label("属性、品质和 TraitArt 均为直接选择；品质不会叠加显示。", 14, Color("adcadb"))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(help)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	content.add_child(body)

	var preview := Control.new()
	preview.name = "Preview"
	preview.custom_minimum_size = Vector2(500.0, 565.0)
	body.add_child(preview)
	_card = CARD_SCENE.instantiate() as Control
	_card.name = "SpriteInfoCard"
	_card.position = Vector2(12.0, 10.0)
	preview.add_child(_card)

	var controls := VBoxContainer.new()
	controls.name = "Controls"
	controls.custom_minimum_size = Vector2(445.0, 0.0)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 8)
	body.add_child(controls)

	_status_label = _make_label("正在连接 SpriteInfoCard…", 15, Color("8ce6ac"))
	_status_label.name = "Status"
	_status_label.custom_minimum_size = Vector2(0.0, 42.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(_status_label)

	_pet_name_button = Button.new()
	_pet_name_button.name = "PetNameButton"
	_pet_name_button.custom_minimum_size = Vector2(0.0, 46.0)
	_pet_name_button.add_theme_font_size_override("font_size", 17)
	_pet_name_button.pressed.connect(_on_pet_name_pressed)
	controls.add_child(_pet_name_button)

	controls.add_child(_make_label("1  ElementArt / 属性选择", 16, Color("d6e9f7")))
	_element_selector = _make_selector("ElementSelector", ELEMENT_NAMES)
	_element_selector.item_selected.connect(_on_element_selected)
	controls.add_child(_element_selector)

	controls.add_child(_make_label("2  品质选择（当前品质三层联动）", 16, Color("d6e9f7")))
	_quality_selector = _make_selector("QualitySelector", QUALITY_NAMES)
	_quality_selector.item_selected.connect(_on_quality_selected)
	controls.add_child(_quality_selector)

	var trait_row := HBoxContainer.new()
	trait_row.add_theme_constant_override("separation", 10)
	controls.add_child(trait_row)
	_trait_lock_button = Button.new()
	_trait_lock_button.name = "TraitLockButton"
	_trait_lock_button.custom_minimum_size = Vector2(220.0, 46.0)
	_trait_lock_button.pressed.connect(_on_trait_lock_pressed)
	trait_row.add_child(_trait_lock_button)
	var lock_hint := _make_label("隐藏锁后可选择特性", 14, Color("adcadb"))
	lock_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trait_row.add_child(lock_hint)

	controls.add_child(_make_label("TraitArt / 白银特性选择", 16, Color("d6e9f7")))
	_trait_selector = _make_selector("TraitSelector", TRAIT_NAMES)
	_trait_selector.item_selected.connect(_on_trait_selected)
	controls.add_child(_trait_selector)

	controls.add_child(_make_label("3  六项 Value（HP、AP 支持 当前/最大）", 16, Color("d6e9f7")))
	var value_grid := GridContainer.new()
	value_grid.name = "ValueGrid"
	value_grid.columns = 2
	value_grid.add_theme_constant_override("h_separation", 12)
	value_grid.add_theme_constant_override("v_separation", 6)
	controls.add_child(value_grid)
	_add_value_row(value_grid, "HP", "hp", "24/24")
	_add_value_row(value_grid, "攻击", "attack", "4")
	_add_value_row(value_grid, "AP", "ap", "3/5")
	_add_value_row(value_grid, "防御", "defense", "2")
	_add_value_row(value_grid, "护盾", "shield", "3")
	_add_value_row(value_grid, "再生", "regen", "1")

	_apply_values_button = Button.new()
	_apply_values_button.name = "ApplyValuesButton"
	_apply_values_button.custom_minimum_size = Vector2(0.0, 48.0)
	_apply_values_button.text = "应用六项数值"
	_apply_values_button.add_theme_font_size_override("font_size", 17)
	_apply_values_button.pressed.connect(_on_apply_values_pressed)
	controls.add_child(_apply_values_button)


func _initialize_controls() -> void:
	var element_index := maxi(0, int(_card.call("get_element_art_index")))
	var quality_index := maxi(0, int(_card.call("get_base_art_index")))
	var trait_index := maxi(0, int(_card.call("get_silver_trait_index")))
	_pet_name_index = 0
	_apply_pet_name()
	_element_selector.select(element_index)
	_quality_selector.select(quality_index)
	_trait_selector.select(trait_index)
	var lock_art := _card.get_node("TraitLockSilver") as CanvasItem
	_trait_selector.disabled = lock_art.visible
	_refresh_lock_button_text(lock_art.visible)
	_sync_value_fields(Dictionary(_card.call("get_info_snapshot")))
	_set_status("独立调试面板已连接 SpriteInfoCard", true)


func _apply_pet_name() -> void:
	if _card == null:
		return
	var pet_name := String(PET_NAMES[_pet_name_index])
	var record := Dictionary(_card.call("get_info_snapshot"))
	record["name"] = pet_name
	_card.call("set_info", record)
	_pet_name_button.text = "宠物名字：%s（点击切换）" % pet_name


func _make_selector(selector_name: String, names: Array) -> OptionButton:
	var selector := OptionButton.new()
	selector.name = selector_name
	selector.custom_minimum_size = Vector2(0.0, 46.0)
	selector.add_theme_font_size_override("font_size", 17)
	for display_name in names:
		selector.add_item(String(display_name))
	return selector


func _add_value_row(grid: GridContainer, label_text: String, key: String, default_text: String) -> void:
	var label := _make_label(label_text, 15, Color("e0ebf3"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	var edit := LineEdit.new()
	edit.name = "%sEdit" % key.capitalize()
	edit.custom_minimum_size = Vector2(250.0, 36.0)
	edit.text = default_text
	grid.add_child(edit)
	_value_edits[key] = edit


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _sync_value_fields(record: Dictionary) -> void:
	_set_edit_text("hp", _pair_text(record.get("hp", 0), record.get("max_hp", 0)))
	_set_edit_text("attack", str(int(record.get("attack", 0))))
	_set_edit_text("ap", _pair_text(record.get("ap", 0), record.get("max_ap", 0)))
	_set_edit_text("defense", str(int(record.get("defense", 0))))
	_set_edit_text("shield", str(int(record.get("shield", 0))))
	_set_edit_text("regen", str(int(record.get("regen", 0))))


func _edit_text(key: String) -> String:
	return (_value_edits[key] as LineEdit).text


func _set_edit_text(key: String, value: String) -> void:
	(_value_edits[key] as LineEdit).text = value


func _pair_text(current_value: Variant, max_value: Variant) -> String:
	return "%d/%d" % [maxi(0, int(current_value)), maxi(0, int(max_value))]


func _parse_pair(text: String, fallback_current: int, fallback_max: int) -> Vector2i:
	var parts := text.strip_edges().split("/", false, 1)
	var current_value := _parse_non_negative_int(parts[0] if not parts.is_empty() else "", fallback_current)
	var max_value := maxi(current_value, fallback_max)
	if parts.size() > 1:
		max_value = maxi(current_value, _parse_non_negative_int(parts[1], fallback_max))
	return Vector2i(current_value, max_value)


func _parse_non_negative_int(text: String, fallback: int) -> int:
	var normalized := text.strip_edges()
	return maxi(0, int(normalized)) if normalized.is_valid_int() else maxi(0, fallback)


func _refresh_lock_button_text(lock_visible: bool) -> void:
	_trait_lock_button.text = "TraitLockSilver：显示（点击隐藏）" if lock_visible else "TraitLockSilver：隐藏（点击显示）"


func _on_element_selected(index: int) -> void:
	debug_select_element(index)


func _on_pet_name_pressed() -> void:
	var pet_name := debug_cycle_pet_name()
	_set_status("PetName 已切换为：%s" % pet_name, true)


func _on_quality_selected(index: int) -> void:
	debug_select_quality(index)


func _on_trait_selected(index: int) -> void:
	debug_select_trait(index)


func _on_trait_lock_pressed() -> void:
	debug_toggle_trait_lock()


func _on_apply_values_pressed() -> void:
	debug_apply_values()


func _set_status(message: String, success: bool) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("8ce6ac") if success else Color("ff8b8b"))


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("132335f2")
	style.border_color = Color("70a7cf")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", style)
