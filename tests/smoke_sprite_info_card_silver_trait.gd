extends SceneTree

const CARD_SCENE := preload("res://art/prefabs/pet/sprite_info_card.tscn")
const EXPECTED_ART_SIZE := Vector2(48.0, 48.0)
const EXPECTED_LOCK_SIZE := Vector2(50.0, 50.0)
const EXPECTED_NAMES := ["自愈", "本命爆发", "护体", "连击倍增", "收尾暴击", "元素回响", "越战越勇", "壮体"]
const EXPECTED_FILES := [
	"trait_silver_self_heal.png",
	"trait_silver_signature_burst.png",
	"trait_silver.png",
	"trait_silver_combo_multiplier.png",
	"trait_silver_finisher_crit.png",
	"trait_silver_element_echo.png",
	"trait_silver_battle_growth.png",
	"trait_silver_vitality.png",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var card := CARD_SCENE.instantiate() as Control
	root.add_child(card)
	await process_frame
	var trait_art := card.get_node("TraitArt") as TextureRect
	var lock_art := card.get_node("TraitLockSilver") as TextureRect
	assert(card.call("get_silver_trait_variant_names") == PackedStringArray(EXPECTED_NAMES))
	assert(card.call("get_silver_trait_art_size") == EXPECTED_ART_SIZE)
	assert(int(card.call("get_silver_trait_index")) == 0)
	for index in range(EXPECTED_FILES.size()):
		assert(bool(card.call("set_silver_trait_by_index", index)))
		await process_frame
		assert(int(card.call("get_silver_trait_index")) == index)
		assert(trait_art.texture != null)
		assert(trait_art.texture.get_size() == EXPECTED_ART_SIZE)
		assert(trait_art.size == EXPECTED_ART_SIZE)
		assert(trait_art.texture.resource_path.get_file() == EXPECTED_FILES[index])
	assert(bool(card.call("set_silver_trait_by_name", "元素回响")))
	await process_frame
	assert(int(card.call("get_silver_trait_index")) == 5)
	assert(not bool(card.call("set_silver_trait_by_index", EXPECTED_FILES.size())))
	assert(not bool(card.call("set_silver_trait_by_name", "不存在")))
	assert(lock_art.texture != null)
	assert(lock_art.texture.get_size() == EXPECTED_LOCK_SIZE)
	assert(lock_art.size == EXPECTED_LOCK_SIZE)
	assert(lock_art.texture.resource_path.get_file() == "trait_lock_silver.png")
	print("SPRITE_INFO_CARD_SILVER_TRAIT_SMOKE_PASS")
	quit(0)
