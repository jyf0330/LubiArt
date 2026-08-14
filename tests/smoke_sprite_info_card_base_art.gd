extends SceneTree

const CARD_SCENE := preload("res://art/prefabs/pet/sprite_info_card.tscn")
const EXPECTED_BASE_SIZE := Vector2(360.0, 459.0)
const EXPECTED_ATTACK_SIZE := Vector2(303.0, 98.0)
const EXPECTED_STAT_SIZE := Vector2(259.0, 72.0)
const EXPECTED_LOCK_SIZE := Vector2(50.0, 50.0)
const EXPECTED_QUALITY_IDS := ["bronze", "silver", "gold", "crystal"]
const TRAIT_LOCK_NODE_NAMES := ["TraitLockSilver", "TraitLockGold", "TraitLockCrystal"]
const TRAIT_LOCK_FILES := ["trait_lock_silver.png", "trait_lock_gold.png", "trait_lock_crystal.png"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var card := CARD_SCENE.instantiate() as Control
	root.add_child(card)
	await process_frame
	var base_art := card.get_node("BaseArt") as TextureRect
	var attack_art := card.get_node("AttackFormatPlate") as TextureRect
	var stat_art := card.get_node("StatSlotArt") as TextureRect
	assert(card.call("get_source_canvas_size") == Vector2(360.0, 460.0))
	assert(card.call("get_base_art_size") == EXPECTED_BASE_SIZE)
	assert(base_art.texture.resource_path.get_file() == "panel_base.png")
	assert(attack_art.texture.resource_path.get_file() == "attack_grid.png")
	assert(stat_art.texture.resource_path.get_file() == "stat_icons_static.png")
	assert(base_art.size == EXPECTED_BASE_SIZE)
	assert(attack_art.size == EXPECTED_ATTACK_SIZE)
	assert(stat_art.size == EXPECTED_STAT_SIZE)
	for index in range(EXPECTED_QUALITY_IDS.size()):
		assert(bool(card.call("set_base_art_by_index", index)))
		await process_frame
		assert(int(card.call("get_base_art_index")) == index)
		assert(String(base_art.get_meta("quality_tier")) == EXPECTED_QUALITY_IDS[index])
		assert(String(attack_art.get_meta("quality_tier")) == EXPECTED_QUALITY_IDS[index])
		assert(String(stat_art.get_meta("quality_tier")) == EXPECTED_QUALITY_IDS[index])
		for lock_index in range(TRAIT_LOCK_NODE_NAMES.size()):
			var lock_art := card.get_node(TRAIT_LOCK_NODE_NAMES[lock_index]) as TextureRect
			assert(lock_art.size == EXPECTED_LOCK_SIZE)
			assert(lock_art.texture.resource_path.get_file() == TRAIT_LOCK_FILES[lock_index])
			assert(String(lock_art.get_meta("quality_tier")) == EXPECTED_QUALITY_IDS[index])
	assert(not bool(card.call("set_base_art_by_index", 4)))
	assert(not bool(card.call("set_base_art_by_name", "不存在")))
	print("SPRITE_INFO_CARD_BASE_ART_SMOKE_PASS")
	quit(0)
