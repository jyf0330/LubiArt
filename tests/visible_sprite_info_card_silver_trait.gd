extends SceneTree

const CARD_SCENE := preload("res://art/prefabs/pet/sprite_info_card.tscn")
const TRAIT_NAMES := ["自愈", "本命爆发", "护体", "连击倍增", "收尾暴击", "元素回响", "越战越勇", "壮体"]


func _initialize() -> void:
	root.title = "SpriteInfoCard Silver Trait QA"
	root.size = Vector2i(1060, 590)
	root.min_size = Vector2i(1060, 590)
	root.position = Vector2i(80, 80)
	call_deferred("_build_preview")


func _build_preview() -> void:
	var background := ColorRect.new()
	background.color = Color("18222d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var title := Label.new()
	title.position = Vector2(30.0, 18.0)
	title.size = Vector2(1000.0, 42.0)
	title.text = "SpriteInfoCard / 白银 TraitArt 手动切换检查"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	background.add_child(title)

	var card := CARD_SCENE.instantiate() as Control
	card.position = Vector2(-1000.0, -1000.0)
	background.add_child(card)
	for index in range(TRAIT_NAMES.size()):
		card.call("set_silver_trait_by_index", index)
		await process_frame
		var source := card.get_node("TraitArt") as TextureRect
		var column := index % 4
		var row := index / 4
		var origin := Vector2(78.0 + column * 245.0, 82.0 + row * 225.0)

		var caption := Label.new()
		caption.position = origin
		caption.size = Vector2(144.0, 30.0)
		caption.text = "%d  %s" % [index, TRAIT_NAMES[index]]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 19)
		background.add_child(caption)

		var art := TextureRect.new()
		art.position = origin + Vector2(0.0, 36.0)
		art.size = Vector2(144.0, 144.0)
		art.texture = source.texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		background.add_child(art)

	var note := Label.new()
	note.position = Vector2(30.0, 535.0)
	note.size = Vector2(1000.0, 28.0)
	note.text = "实际资源均为 48×48；Inspector 的 Silver Trait Selection 可独立切换。锁仍由 TraitLockSilver 控制。"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 17)
	background.add_child(note)

	for frame in range(4):
		await process_frame
	var output_dir := ProjectSettings.globalize_path("res://output/validation")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("sprite_info_card_silver_trait_variants.png")
	var save_error := root.get_texture().get_image().save_png(output_path)
	assert(save_error == OK)
	print("SPRITE_INFO_CARD_SILVER_TRAIT_VISIBLE_PASS: %s" % output_path)
	quit(0)
