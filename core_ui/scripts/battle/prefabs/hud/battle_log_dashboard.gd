extends Control
class_name BattleLogDashboard

signal close_requested
signal speed_toggled(active: bool)

const BattleLogReadableProjectionScript := preload("res://core_ui/scripts/battle/controllers/battle_log_readable_projection.gd")
const BattleLogLocalWriterScript := preload("res://core_ui/scripts/battle/controllers/battle_log_local_writer.gd")
const MAX_VISIBLE_LINES := 240
const MAX_CACHED_STRUCTURED_LINES := 240
const CATEGORY_RULES := [
	{
		"label": "地形",
		"color": "#c9a7ff",
		"keywords": ["全部地形", "地形", "变化格", "铺设", "元素格子", "带有元素"],
	},
	{
		"label": "站位",
		"color": "#75d9ff",
		"keywords": ["移动", "站位", "布置", "位置", "重置宠物"],
	},
	{
		"label": "战斗",
		"color": "#ff9b86",
		"keywords": ["攻击", "伤害", "击杀", "死亡", "施放", "命中", "触发", "发动"],
	},
	{
		"label": "回合",
		"color": "#ffd66f",
		"keywords": ["回合", "行动开始", "行动结束"],
	},
	{
		"label": "状态",
		"color": "#9fe3a8",
		"keywords": ["护盾", "治疗", "生命", "回复", "AP", "元素"],
	},
]

var _log_text: RichTextLabel
var _empty_label: Label
var _title_label: Label
var _observed_round := 0
var _terrain_summary_by_round := {}
var _readable_projection := BattleLogReadableProjectionScript.new()
var _local_writer := BattleLogLocalWriterScript.new()
var _structured_lines: Array = []
var _observed_trace_count := 0
var _observed_command_count := 0


func _ready() -> void:
	# OverlayHost intentionally keeps no authored rectangle of its own, so a
	# full-rect child would also resolve to a zero-sized rect. Size this modal
	# against the actual viewport while keeping it owned by OverlayHost.
	z_as_relative = false
	z_index = 1100
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_sync_to_viewport()
	get_viewport().size_changed.connect(_sync_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func render_snapshot(snapshot: Dictionary) -> void:
	_ingest_structured_history(snapshot)
	_update_round_terrain_summary(snapshot)
	var lines := Array(snapshot.get("log_lines", snapshot.get("logLines", [])))
	var visible_lines := _structured_lines.duplicate()
	visible_lines.reverse()
	if _structured_lines.is_empty():
		for line_value in lines:
			var line := String(line_value)
			if line != "" and not _history_contains_text(visible_lines, line):
				visible_lines.append(line)
	visible_lines = _terrain_summary_lines() + visible_lines
	if visible_lines.size() > MAX_VISIBLE_LINES:
		visible_lines.resize(MAX_VISIBLE_LINES)
	_title_label.text = "战斗过程 · 最新发生的在上面 · %d条" % visible_lines.size()
	_render_lines(visible_lines)
	_empty_label.visible = visible_lines.is_empty()
	_log_text.visible = not visible_lines.is_empty()


func _ingest_structured_history(snapshot: Dictionary) -> void:
	var trace := Array(snapshot.get("battleTrace", snapshot.get("battle_trace", [])))
	var command_log := Array(snapshot.get("command_log", snapshot.get("commandLog", [])))
	if trace.size() < _observed_trace_count or command_log.size() < _observed_command_count:
		_structured_lines.clear()
		_observed_trace_count = 0
		_observed_command_count = 0
	if command_log.size() > _observed_command_count:
		_append_structured_lines(_readable_projection.auto_position_lines(snapshot))
	if trace.size() > _observed_trace_count:
		_append_structured_lines(_readable_projection.trace_lines(
			trace.slice(_observed_trace_count, trace.size())
		))
	_observed_trace_count = trace.size()
	_observed_command_count = command_log.size()
	_local_writer.write_lines(_structured_lines)


func configure_local_file_for_test(path: String, enabled: bool) -> void:
	_local_writer.configure_for_test(path, enabled)


func _append_structured_lines(lines: Array) -> void:
	for line_value in lines:
		var line := String(line_value).strip_edges()
		if line != "":
			_structured_lines.append(line)
	if _structured_lines.size() > MAX_CACHED_STRUCTURED_LINES:
		_structured_lines = _structured_lines.slice(
			_structured_lines.size() - MAX_CACHED_STRUCTURED_LINES,
			_structured_lines.size()
		)


func _history_contains_text(history: Array, text: String) -> bool:
	for history_value in history:
		if String(history_value).contains(text):
			return true
	return false


func toggle() -> void:
	visible = not visible


func close() -> void:
	hide()


func is_open() -> bool:
	return visible


func _sync_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _update_round_terrain_summary(snapshot: Dictionary) -> void:
	if String(snapshot.get("phase", "")) != "battle":
		return
	var current_round := int(snapshot.get("battleRound", snapshot.get("battle_round", 0)))
	if current_round < _observed_round:
		for round_value in _terrain_summary_by_round.keys():
			if int(round_value) >= current_round:
				_terrain_summary_by_round.erase(round_value)
	if current_round > _observed_round and current_round > 1:
		var completed_round := current_round - 1
		_terrain_summary_by_round[completed_round] = _build_terrain_summary(
			snapshot,
			completed_round
		)
	_observed_round = current_round


func _build_terrain_summary(snapshot: Dictionary, completed_round: int) -> Array:
	var board := Dictionary(snapshot.get("board", {}))
	var width := int(board.get("width", Dictionary(board.get("dimensions", {})).get("width", 0)))
	var height := int(board.get("height", Dictionary(board.get("dimensions", {})).get("height", 0)))
	var cells_by_key := {}
	for cell_value in Array(board.get("cells", [])):
		var cell := Dictionary(cell_value)
		var key := "%d,%d" % [
			int(cell.get("x", cell.get("c", -1))),
			int(cell.get("y", cell.get("r", -1))),
		]
		cells_by_key[key] = cell
	var terrain_cells: Array[String] = []
	for y in range(height):
		for x in range(width):
			var cell := Dictionary(cells_by_key.get("%d,%d" % [x, y], {}))
			var terrain_text := _terrain_cell_text(cell)
			if terrain_text != "":
				terrain_cells.append("第%d行第%d列（%s）" % [y + 1, x + 1, terrain_text])
	if terrain_cells.is_empty():
		return []
	var summary: Array = ["第%d回合结束 · %d个格子带有元素" % [completed_round, terrain_cells.size()]]
	for start_index in range(0, terrain_cells.size(), 4):
		var end_index := mini(start_index + 4, terrain_cells.size())
		summary.append("第%d回合的元素格子：%s" % [
			completed_round,
			"  |  ".join(terrain_cells.slice(start_index, end_index)),
		])
	return summary


func _terrain_cell_text(cell: Dictionary) -> String:
	var elements := Dictionary(cell.get("elements", {}))
	var element_names: Array[String] = []
	for element_value in elements.keys():
		var element := String(element_value)
		if int(elements[element_value]) > 0:
			element_names.append(element)
	element_names.sort()
	var parts: Array[String] = []
	for element in element_names:
		parts.append("%s%d层" % [element, int(elements[element])])
	return "、".join(parts)


func _terrain_summary_lines() -> Array:
	var rounds: Array = _terrain_summary_by_round.keys()
	rounds.sort()
	rounds.reverse()
	var lines: Array = []
	for round_value in rounds:
		lines.append_array(Array(_terrain_summary_by_round[round_value]))
	return lines


func _render_lines(lines: Array) -> void:
	_log_text.clear()
	for index in range(lines.size()):
		if index > 0:
			_log_text.append_text("\n")
		var line := String(lines[index])
		var category := _category_for_line(line)
		_log_text.push_color(Color(String(category["color"])))
		_log_text.push_bold()
		_log_text.append_text("【%s】" % String(category["label"]))
		_log_text.pop()
		_log_text.pop()
		_log_text.append_text("  %s" % line)


func _category_for_line(line: String) -> Dictionary:
	for rule_value in CATEGORY_RULES:
		var rule := Dictionary(rule_value)
		for keyword_value in Array(rule["keywords"]):
			if line.contains(String(keyword_value)):
				return rule
	return {"label": "系统", "color": "#b8c2d1"}


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.02, 0.025, 0.035, 0.62)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-540.0, -350.0)
	panel.size = Vector2(1080.0, 700.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.07, 0.09, 0.97)
	panel_style.border_color = Color(0.72, 0.56, 0.25, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 30.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_right = 30.0
	panel_style.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)

	var header := HBoxContainer.new()
	header.name = "Header"
	content.add_child(header)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "战斗过程 · 最新发生的在上面 · 0条"
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55, 1.0))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_button := Button.new()
	var speed_button := Button.new()
	speed_button.name = "SpeedButton"
	speed_button.text = "2倍演出"
	speed_button.toggle_mode = true
	speed_button.custom_minimum_size = Vector2(132.0, 46.0)
	speed_button.add_theme_font_size_override("font_size", 22)
	speed_button.toggled.connect(func(active: bool) -> void: speed_toggled.emit(active))
	header.add_child(speed_button)

	close_button.name = "CloseButton"
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(112.0, 46.0)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	var divider := HSeparator.new()
	content.add_child(divider)

	_log_text = RichTextLabel.new()
	_log_text.name = "LogText"
	_log_text.bbcode_enabled = false
	_log_text.fit_content = false
	_log_text.scroll_active = true
	_log_text.scroll_following = false
	_log_text.selection_enabled = true
	_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.add_theme_font_size_override("normal_font_size", 26)
	_log_text.add_theme_color_override("default_color", Color(0.9, 0.93, 0.96, 1.0))
	_log_text.add_theme_constant_override("line_separation", 10)
	content.add_child(_log_text)

	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.text = "当前还没有战斗日志"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_label.add_theme_font_size_override("font_size", 24)
	_empty_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72, 1.0))
	content.add_child(_empty_label)


func _on_close_pressed() -> void:
	close_requested.emit()
