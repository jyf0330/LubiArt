extends PanelContainer

@onready var content: VBoxContainer = $Margin/Scroll/Content


func render_detail(detail: Dictionary, elements: Dictionary, formatter: RefCounted) -> void:
	for child in content.get_children():
		child.queue_free()
	var x := int(detail.get("x", detail.get("c", 0)))
	var y := int(detail.get("y", detail.get("r", 0)))
	_add_label("地形详情", 24, Color("#fff0c4"), true)
	_add_label("第%d行 · 第%d列" % [y + 1, x + 1], 16, Color("#e0d7bc"))
	_add_separator()
	_add_section("地形元素层", String(formatter.call("element_summary", elements)), Color("#f6ead1"))
	var threat := Dictionary(detail.get("threat", {}))
	if not threat.is_empty():
		_add_section("威胁", String(formatter.call("threat_summary", threat)))
	var preview := Dictionary(detail.get("preview", {}))
	if not preview.is_empty():
		_add_section("当前预览", String(formatter.call("preview_summary", preview)))


func get_display_text() -> String:
	var lines: Array[String] = []
	for child in content.get_children():
		if child is Label:
			lines.append(String((child as Label).text))
	return "\n".join(lines)


func _add_section(title: String, body: String, body_color: Color = Color("#d7d0bd")) -> void:
	if body.strip_edges().is_empty():
		return
	_add_label(title, 16, Color("#f3d58c"), true)
	_add_label(body, 14, body_color)


func _add_label(value: String, font_size: int, color: Color, bold: bool = false) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.62))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	content.add_child(label)


func _add_separator() -> void:
	var line := ColorRect.new()
	line.color = Color(0.86, 0.67, 0.34, 0.55)
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(line)
