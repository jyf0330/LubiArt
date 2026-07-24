extends Control
class_name SpriteInfoPanel

const ART_DIR := "res://assets/artist_ui/sprite_info/art"
const UI_FONT_PATH := "res://assets/artist_ui/sprite_info/fonts/fusion_pixel_zh_hans.ttf"
const ART_NAME_ALIASES := {
	"背景": "panel_background",
	"青铜": "quality_bronze",
	"白银": "quality_silver",
	"黄金": "quality_gold",
	"钻石": "quality_diamond",
	"青铜边框": "quality_bronze_border",
	"白银边框": "quality_silver_border",
	"黄金边框": "quality_gold_border",
	"钻石边框": "quality_diamond_border",
	"风": "element_wind",
	"水": "element_water",
	"火": "element_fire",
	"土": "element_earth",
	"HP": "stat_hp",
	"AP": "stat_ap",
	"攻击": "stat_attack",
	"防御": "stat_defense",
	"护盾": "stat_shield",
	"再生": "stat_regen",
	"精灵位置": "attack_origin",
	"攻击落点": "attack_hit",
}
const CONTENT_BLOCK_WIDTH := 280
const HEADER_SIZE := Vector2(CONTENT_BLOCK_WIDTH, 54)
const ATTACK_PANEL_SIZE := Vector2(CONTENT_BLOCK_WIDTH, 150)
const STAT_TABLE_SIZE := Vector2(CONTENT_BLOCK_WIDTH, 214)
const STAT_ROW_HEIGHT := 33
const ATTACK_GRID_COLUMNS := 7
const ATTACK_GRID_ROWS := 3
const ATTACK_GRID_SPACING := 4
const ATTACK_PANEL_MARGIN_X := 14
const ATTACK_PANEL_MARGIN_Y := 6
const ATTACK_INNER_WIDTH := CONTENT_BLOCK_WIDTH - ATTACK_PANEL_MARGIN_X * 2
const ATTACK_TITLE_HEIGHT := 24
const ATTACK_LAYOUT_SPACING := 4
const STAT_ICON_COLUMN_WIDTH := 34
const STAT_NAME_COLUMN_WIDTH := 86
const STAT_VALUE_COLUMN_WIDTH := 112
const STAT_VALUE_MAX_FONT_SIZE := 24
const STAT_VALUE_MIN_FONT_SIZE := 10
const STAT_NAME_FONT_SIZE := 21
const ELEMENT_ICON_SIZE := Vector2(46, 46)
const QUALITY_BADGE_SIZE := Vector2(110, 50)
const STAT_ROWS := [
	{"key": "hp", "label": "HP", "name": "生命"},
	{"key": "ap", "label": "AP", "name": "行动"},
	{"key": "attack", "label": "攻击", "name": "攻击"},
	{"key": "defense", "label": "防御", "name": "防御"},
	{"key": "shield", "label": "护盾", "name": "护盾"},
	{"key": "regen", "label": "再生", "name": "再生"},
]

var _title_label: Label
var _quality_label: Label
var _element_label: Label
var _panel_texture_rect: TextureRect
var _border_texture_rect: TextureRect
var _quality_icon_rect: TextureRect
var _element_icon_rect: TextureRect
var _attack_cells: GridContainer
var _stats_rows: VBoxContainer
var _stat_value_labels := {}
var _stat_icon_rects := {}
var _stat_fallback_labels := {}
var _background: PanelContainer
var _quality_badge: PanelContainer
var _element_badge: PanelContainer
var _art_textures := {}
var _ui_font: Font = null
var _ui_font_load_attempted := false


func _ready() -> void:
	_load_art_textures()
	_load_ui_font()
	if _background == null:
		_build_ui()


func display_info(info: SpriteInfoData) -> void:
	if _background == null:
		_load_art_textures()
		_load_ui_font()
		_build_ui()

	if info == null:
		visible = false
		return

	var rank := info.get_current_rank()
	_title_label.text = info.get_display_name()
	_quality_label.text = rank.quality_name
	_element_label.text = info.element_name
	_set_quality_art(rank)
	_set_element_art(info)

	_set_panel_art(rank)
	_set_panel_style(_quality_badge, Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, 0)
	_set_panel_style(_element_badge, Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, 0)
	_build_attack_pattern(info)
	_update_stats(rank)


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	_panel_texture_rect = _make_full_rect_texture("PanelTexture")
	add_child(_panel_texture_rect)

	_border_texture_rect = _make_full_rect_texture("QualityBorderTexture")
	add_child(_border_texture_rect)

	_background = PanelContainer.new()
	_background.name = "PanelBackground"
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.clip_contents = true
	add_child(_background)

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 3)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.clip_contents = true
	_background.add_child(margin)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 6)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.clip_contents = true
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = HEADER_SIZE
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(header)

	_element_badge = _make_badge("ElementBadge", ELEMENT_ICON_SIZE)
	var element_content := _make_badge_content()
	_element_icon_rect = _make_badge_icon(ELEMENT_ICON_SIZE)
	_element_label = _make_badge_label("风属性")
	_element_label.visible = false
	element_content.add_child(_element_icon_rect)
	element_content.add_child(_element_label)
	_element_badge.add_child(element_content)
	header.add_child(_element_badge)

	_title_label = Label.new()
	_title_label.name = "NameLabel"
	_title_label.custom_minimum_size = Vector2(84, HEADER_SIZE.y)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.add_theme_font_size_override("font_size", 29)
	_apply_label_font(_title_label)
	_title_label.add_theme_color_override("font_color", Color(0.18, 0.16, 0.12, 1.0))
	header.add_child(_title_label)

	_quality_badge = _make_badge("QualityBadge", QUALITY_BADGE_SIZE)
	var quality_content := _make_badge_content()
	_quality_icon_rect = _make_badge_icon(QUALITY_BADGE_SIZE)
	_quality_label = _make_badge_label("青铜")
	_quality_label.visible = false
	quality_content.add_child(_quality_icon_rect)
	quality_content.add_child(_quality_label)
	_quality_badge.add_child(quality_content)
	header.add_child(_quality_badge)

	layout.add_child(_make_divider())

	layout.add_child(_make_attack_panel())

	var stats_table := _make_stat_table()
	layout.add_child(stats_table)

	for index in STAT_ROWS.size():
		var stat = STAT_ROWS[index]
		var row := _make_stat_row(String(stat["label"]), String(stat["name"]))
		_stats_rows.add_child(row)
		if index < STAT_ROWS.size() - 1:
			_stats_rows.add_child(_make_stat_separator())

	_refresh_stat_icons()
	_set_panel_style(_background, Color(0.96, 0.87, 0.68, 0.96), Color(0.55, 0.32, 0.18, 1.0), 4, 14)


func _make_full_rect_texture(node_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	return rect


func _make_divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.name = "HeaderDivider"
	divider.custom_minimum_size = Vector2(CONTENT_BLOCK_WIDTH, 2)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	divider.color = Color(0.50, 0.31, 0.13, 0.38)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _make_attack_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "AttackPanel"
	panel.custom_minimum_size = ATTACK_PANEL_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	_set_panel_style(panel, Color(0.82, 0.67, 0.42, 0.14), Color(0.55, 0.35, 0.16, 0.36), 2, 7)

	var margin := MarginContainer.new()
	margin.name = "AttackMargin"
	margin.add_theme_constant_override("margin_left", ATTACK_PANEL_MARGIN_X)
	margin.add_theme_constant_override("margin_top", ATTACK_PANEL_MARGIN_Y)
	margin.add_theme_constant_override("margin_right", ATTACK_PANEL_MARGIN_X)
	margin.add_theme_constant_override("margin_bottom", ATTACK_PANEL_MARGIN_Y)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.clip_contents = true
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "AttackLayout"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", ATTACK_LAYOUT_SPACING)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.clip_contents = true
	margin.add_child(column)

	var attack_title := Label.new()
	attack_title.name = "AttackTitle"
	attack_title.text = "攻击格式"
	attack_title.custom_minimum_size = Vector2(ATTACK_INNER_WIDTH, ATTACK_TITLE_HEIGHT)
	attack_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	attack_title.add_theme_font_size_override("font_size", 20)
	_apply_label_font(attack_title)
	attack_title.add_theme_color_override("font_color", Color(0.20, 0.15, 0.08, 1.0))
	column.add_child(attack_title)

	_attack_cells = GridContainer.new()
	_attack_cells.name = "AttackCells"
	_attack_cells.columns = ATTACK_GRID_COLUMNS
	_attack_cells.custom_minimum_size = _get_attack_grid_size()
	_attack_cells.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_attack_cells.add_theme_constant_override("h_separation", ATTACK_GRID_SPACING)
	_attack_cells.add_theme_constant_override("v_separation", ATTACK_GRID_SPACING)
	_attack_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_attack_cells)
	return panel


func _make_badge(node_name: String, minimum_size: Vector2) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = node_name
	badge.custom_minimum_size = minimum_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_panel_style(badge, Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, 0)
	return badge


func _make_badge_content() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _make_badge_icon(minimum_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	return icon


func _make_badge_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	_apply_label_font(label)
	label.add_theme_color_override("font_color", Color(0.18, 0.16, 0.12, 1.0))
	return label


func _set_optional_texture(texture_rect: TextureRect, texture: Texture2D) -> void:
	texture_rect.texture = texture
	texture_rect.visible = texture != null


func _load_art_textures() -> void:
	_art_textures.clear()

	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext := file_name.get_extension().to_lower()
			if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp":
				var texture := _load_art_texture("%s/%s" % [ART_DIR, file_name])
				if texture != null:
					_art_textures[file_name.get_basename()] = texture
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_art_texture(resource_path: String) -> Texture2D:
	if ResourceLoader.exists(resource_path):
		var imported_texture := ResourceLoader.load(resource_path) as Texture2D
		if imported_texture != null:
			return imported_texture

	var image := Image.new()
	var file_path: String = ProjectSettings.globalize_path(resource_path)
	var load_error: int = image.load(file_path)
	if load_error != OK:
		return null

	return ImageTexture.create_from_image(image)


func _load_ui_font() -> void:
	if _ui_font != null:
		return
	if _ui_font_load_attempted:
		return

	_ui_font_load_attempted = true
	if ResourceLoader.exists(UI_FONT_PATH):
		var font_resource: Resource = ResourceLoader.load(UI_FONT_PATH)
		_ui_font = font_resource as Font

	if _ui_font != null:
		return

	var font_file := FontFile.new()
	var load_error: int = font_file.load_dynamic_font(UI_FONT_PATH)
	if load_error != OK:
		load_error = font_file.load_dynamic_font(ProjectSettings.globalize_path(UI_FONT_PATH))

	if load_error == OK:
		_ui_font = font_file
	else:
		push_warning("Sprite info UI font could not be loaded: %s" % UI_FONT_PATH)


func _apply_label_font(label: Label) -> void:
	if _ui_font == null:
		_load_ui_font()
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)


func _get_art_texture(texture_name: String) -> Texture2D:
	if _art_textures.is_empty():
		_load_art_textures()

	var mapped_name := String(ART_NAME_ALIASES.get(texture_name, texture_name))
	if _art_textures.has(mapped_name):
		return _art_textures[mapped_name] as Texture2D

	return null


func _set_panel_art(rank: SpriteRankStats) -> void:
	var background_texture := _get_art_texture("背景")
	var border_texture := _get_art_texture("%s边框" % _get_quality_key(rank.quality_name))
	_set_optional_texture(_panel_texture_rect, background_texture)
	_set_optional_texture(_border_texture_rect, border_texture)

	if background_texture != null or border_texture != null:
		_set_panel_style(_background, Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, 0)
	else:
		_set_panel_style(_background, Color(0.96, 0.87, 0.68, 0.96), rank.quality_color, 4, 14)


func _set_quality_art(rank: SpriteRankStats) -> void:
	var quality_texture := rank.quality_icon
	if quality_texture == null:
		quality_texture = _get_art_texture(_get_quality_key(rank.quality_name))

	_set_optional_texture(_quality_icon_rect, quality_texture)
	_quality_label.visible = quality_texture == null


func _set_element_art(info: SpriteInfoData) -> void:
	var element_texture := info.element_icon
	if element_texture == null:
		element_texture = _get_art_texture(_get_element_key(info.element_name))

	_set_optional_texture(_element_icon_rect, element_texture)
	_element_label.visible = element_texture == null


func _get_quality_key(quality_name: String) -> String:
	for key in ["青铜", "白银", "黄金", "钻石"]:
		if quality_name.find(key) != -1:
			return key

	return quality_name.strip_edges()


func _get_element_key(element_name: String) -> String:
	for key in ["风", "水", "火", "土"]:
		if element_name.find(key) != -1:
			return key

	return element_name.strip_edges()


func _refresh_stat_icons() -> void:
	for stat_label in _stat_icon_rects.keys():
		var texture := _get_art_texture(stat_label)
		var icon_rect := _stat_icon_rects[stat_label] as TextureRect
		var fallback_icon := _stat_fallback_labels[stat_label] as Label
		_set_optional_texture(icon_rect, texture)
		fallback_icon.visible = texture == null


func _make_stat_table() -> PanelContainer:
	var table := PanelContainer.new()
	table.name = "StatsTable"
	table.custom_minimum_size = STAT_TABLE_SIZE
	table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.clip_contents = true
	_set_panel_style(table, Color(0.82, 0.67, 0.42, 0.18), Color(0.55, 0.35, 0.16, 0.36), 2, 6)

	var margin := MarginContainer.new()
	margin.name = "StatsMargin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 3)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.clip_contents = true
	table.add_child(margin)

	var rows := VBoxContainer.new()
	rows.name = "StatsRows"
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.clip_contents = true
	margin.add_child(rows)
	_stats_rows = rows
	return table


func _make_stat_row(stat_label: String, display_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "%sRow" % stat_label
	row.custom_minimum_size = Vector2(STAT_TABLE_SIZE.x - 32, STAT_ROW_HEIGHT)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_rect := TextureRect.new()
	icon_rect.name = "%sIcon" % stat_label
	icon_rect.custom_minimum_size = Vector2(STAT_ICON_COLUMN_WIDTH, STAT_ROW_HEIGHT)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)

	var fallback_icon := Label.new()
	fallback_icon.text = stat_label
	fallback_icon.custom_minimum_size = Vector2(STAT_ICON_COLUMN_WIDTH, STAT_ROW_HEIGHT)
	fallback_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fallback_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_icon.add_theme_font_size_override("font_size", 14)
	_apply_label_font(fallback_icon)
	fallback_icon.add_theme_color_override("font_color", Color(0.26, 0.22, 0.15, 1.0))
	row.add_child(fallback_icon)

	var name_label := Label.new()
	name_label.name = "%sName" % stat_label
	name_label.text = display_name
	name_label.custom_minimum_size = Vector2(STAT_NAME_COLUMN_WIDTH, STAT_ROW_HEIGHT)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", STAT_NAME_FONT_SIZE)
	_apply_label_font(name_label)
	name_label.add_theme_color_override("font_color", Color(0.14, 0.11, 0.07, 1.0))
	row.add_child(name_label)

	var value := Label.new()
	value.name = "%sValue" % stat_label
	value.custom_minimum_size = Vector2(STAT_VALUE_COLUMN_WIDTH, STAT_ROW_HEIGHT)
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	value.clip_text = true
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", STAT_VALUE_MAX_FONT_SIZE)
	_apply_label_font(value)
	value.add_theme_color_override("font_color", Color(0.11, 0.08, 0.04, 1.0))
	row.add_child(value)

	_stat_icon_rects[stat_label] = icon_rect
	_stat_fallback_labels[stat_label] = fallback_icon
	_stat_value_labels[stat_label] = value
	return row


func _make_stat_separator() -> ColorRect:
	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.color = Color(0.48, 0.29, 0.12, 0.30)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return separator


func _get_attack_grid_cell_size() -> Vector2:
	var available_width: float = ATTACK_INNER_WIDTH
	var available_height: float = ATTACK_PANEL_SIZE.y - float(ATTACK_PANEL_MARGIN_Y * 2) - ATTACK_TITLE_HEIGHT - ATTACK_LAYOUT_SPACING
	var spacing_width: float = float(ATTACK_GRID_SPACING * (ATTACK_GRID_COLUMNS - 1))
	var spacing_height: float = float(ATTACK_GRID_SPACING * (ATTACK_GRID_ROWS - 1))
	var cell_width: int = int(floor((available_width - spacing_width) / float(ATTACK_GRID_COLUMNS)))
	var cell_height: int = int(floor((available_height - spacing_height) / float(ATTACK_GRID_ROWS)))

	if cell_width < 8:
		cell_width = 8
	if cell_height < 8:
		cell_height = 8

	return Vector2(cell_width, cell_height)


func _get_attack_grid_size() -> Vector2:
	var cell_size: Vector2 = _get_attack_grid_cell_size()
	return Vector2(
		ATTACK_GRID_COLUMNS * cell_size.x + (ATTACK_GRID_COLUMNS - 1) * ATTACK_GRID_SPACING,
		ATTACK_GRID_ROWS * cell_size.y + (ATTACK_GRID_ROWS - 1) * ATTACK_GRID_SPACING
	)


func _build_attack_pattern(info: SpriteInfoData) -> void:
	for child in _attack_cells.get_children():
		child.queue_free()

	var cell_count: int = ATTACK_GRID_COLUMNS * ATTACK_GRID_ROWS
	var cell_size: Vector2 = _get_attack_grid_cell_size()

	var origin_index: int = info.origin_cell_index
	if origin_index < 0:
		origin_index = 0
	elif origin_index >= cell_count:
		origin_index = cell_count - 1

	var hit_lookup: Dictionary = {}
	for hit_index in info.hit_cell_indices:
		if hit_index >= 0 and hit_index < cell_count:
			hit_lookup[hit_index] = true

	for index in cell_count:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = cell_size
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_panel_style(cell, Color(0.96, 0.83, 0.58, 0.86), Color(0.74, 0.44, 0.42, 0.62), 2, 4)

		if index == origin_index:
			cell.add_child(_make_attack_icon("精灵位置", "●", Color(0.05, 0.42, 0.82, 1.0)))
		elif hit_lookup.has(index):
			cell.add_child(_make_attack_icon("攻击落点", "■", Color(0.86, 0.16, 0.12, 1.0)))

		_attack_cells.add_child(cell)


func _make_attack_icon(texture_name: String, fallback_text: String, fallback_color: Color) -> Control:
	var texture := _get_art_texture(texture_name)
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return icon

	var label := Label.new()
	label.text = fallback_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	_apply_label_font(label)
	label.add_theme_color_override("font_color", fallback_color)
	return label


func _update_stats(rank: SpriteRankStats) -> void:
	_set_stat("HP", "%d/%d" % [rank.hp_current, rank.hp_max])
	_set_stat("AP", "%d/%d" % [rank.ap_current, rank.ap_max])
	_set_stat("攻击", str(rank.attack))
	_set_stat("防御", str(rank.defense))
	_set_stat("护盾", str(rank.shield))
	_set_stat("再生", str(rank.regen))


func _set_stat(stat_label: String, value: String) -> void:
	if _stat_value_labels.has(stat_label):
		var label := _stat_value_labels[stat_label] as Label
		label.text = value
		label.add_theme_font_size_override("font_size", _get_stat_value_font_size(value))


func _get_stat_value_font_size(value: String) -> int:
	var char_count: int = value.length()
	if char_count < 1:
		char_count = 1

	if char_count <= 5:
		return STAT_VALUE_MAX_FONT_SIZE

	var estimated_width_per_char: float = 15.0
	var fit_size: int = int(floor(STAT_VALUE_COLUMN_WIDTH / (char_count * estimated_width_per_char) * STAT_VALUE_MAX_FONT_SIZE))
	if fit_size > STAT_VALUE_MAX_FONT_SIZE:
		return STAT_VALUE_MAX_FONT_SIZE
	if fit_size < STAT_VALUE_MIN_FONT_SIZE:
		return STAT_VALUE_MIN_FONT_SIZE

	return fit_size


func _set_panel_style(panel: PanelContainer, bg_color: Color, border_color: Color, border_width: int, corner_radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	panel.add_theme_stylebox_override("panel", style)
