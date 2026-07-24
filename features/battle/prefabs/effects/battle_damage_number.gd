extends Label


func show_damage(amount: int, color: Color = Color(1.0, 0.22, 0.14), duration: float = 0.55, damage_label: String = "") -> void:
	text = "%s-%d" % ["%s " % damage_label if damage_label != "" else "", max(0, amount)]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	add_theme_font_size_override("font_size", 28)
	pivot_offset = size * 0.5
	modulate.a = 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 38.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
