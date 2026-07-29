extends SceneTree

const CARD_SCENE := preload("res://art/prefabs/pet/sprite_info_card.tscn")
const VARIANT_NAMES := ["青铜", "白银", "黄金", "水晶"]


func _initialize() -> void:
	root.title = "SpriteInfoCard BaseArt QA"
	root.size = Vector2i(1120, 650)
	root.min_size = Vector2i(1120, 650)
	root.position = Vector2i(80, 80)
	call_deferred("_build_preview")


func _build_preview() -> void:
	var background := ColorRect.new()
	background.color = Color("18222d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var title := Label.new()
	title.position = Vector2(36.0, 20.0)
	title.size = Vector2(1048.0, 42.0)
	title.text = "SpriteInfoCard / 三层品质美术联动检查"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	background.add_child(title)

	for index in range(VARIANT_NAMES.size()):
		var caption := Label.new()
		caption.position = Vector2(35.0 + index * 270.0, 70.0)
		caption.size = Vector2(238.0, 34.0)
		caption.text = "%d  %s" % [index, VARIANT_NAMES[index]]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 22)
		background.add_child(caption)

		var card := CARD_SCENE.instantiate() as Control
		card.position = Vector2(35.0 + index * 270.0, 108.0)
		card.scale = Vector2(0.5, 0.5)
		background.add_child(card)
		card.call("set_info", {
			"name": "%s卡底" % VARIANT_NAMES[index],
			"quality": "水晶",
			"element": "水",
			"hp": 24,
			"max_hp": 24,
			"attack": 4,
			"ap": 3,
			"max_ap": 5,
			"defense": 2,
			"shield": 3,
			"regen": 1,
		})
		card.call("set_base_art_by_index", index)

	var note := Label.new()
	note.position = Vector2(36.0, 596.0)
	note.size = Vector2(1048.0, 30.0)
	note.text = "卡底、攻击棋盘、数值格由同一个品质选项同步切换。"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 17)
	background.add_child(note)

	await create_timer(30.0).timeout
	quit(0)
