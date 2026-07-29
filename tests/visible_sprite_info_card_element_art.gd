extends SceneTree

const PET_DETAIL_SCENE := preload("res://art/prefabs/pet/pet_detail.tscn")
const ELEMENT_NAMES := ["暗", "水", "冰", "草", "电", "风", "火", "龙", "土"]


func _initialize() -> void:
	root.title = "SpriteInfoCard ElementArt QA"
	root.size = Vector2i(1040, 520)
	root.min_size = Vector2i(1040, 520)
	root.position = Vector2i(80, 80)
	call_deferred("_build_preview")


func _build_preview() -> void:
	var background := ColorRect.new()
	background.color = Color("18222d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var title := Label.new()
	title.position = Vector2(30.0, 18.0)
	title.size = Vector2(980.0, 42.0)
	title.text = "SpriteInfoCard / ElementArt 九属性手动切换检查"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	background.add_child(title)

	var detail := PET_DETAIL_SCENE.instantiate() as Control
	var card := detail.get_node("Panel/SpriteInfoCard").duplicate() as Control
	card.position = Vector2(-1000.0, -1000.0)
	background.add_child(card)
	for index in range(ELEMENT_NAMES.size()):
		card.call("set_element_art_by_index", index)
		await process_frame
		var source := card.get_node("ElementArt") as TextureRect
		var column := index % 5
		var row := index / 5
		var origin := Vector2(52.0 + column * 195.0, 82.0 + row * 190.0)

		var caption := Label.new()
		caption.position = origin
		caption.size = Vector2(93.0, 30.0)
		caption.text = "%d  %s" % [index, ELEMENT_NAMES[index]]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 20)
		background.add_child(caption)

		var art := TextureRect.new()
		art.position = origin + Vector2(0.0, 34.0)
		art.size = Vector2(93.0, 115.0)
		art.texture = source.texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		background.add_child(art)

	var note := Label.new()
	note.position = Vector2(30.0, 465.0)
	note.size = Vector2(980.0, 28.0)
	note.text = "九张纹理均为 93×115；Inspector 的 Element Art Selection 可独立手动切换。"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 17)
	background.add_child(note)

	await create_timer(30.0).timeout
	quit(0)
