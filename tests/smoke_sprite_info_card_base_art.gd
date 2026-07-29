extends SceneTree

const PET_DETAIL_SCENE := preload("res://art/prefabs/pet/pet_detail.tscn")
const EXPECTED_SIZE := Vector2(472.0, 540.0)
const EXPECTED_ATTACK_SIZE := Vector2(383.0, 152.0)
const EXPECTED_STAT_SLOT_SIZE := Vector2(322.0, 174.0)
const EXPECTED_BASE_FILES := [
	"panel_base_bronze.png",
	"panel_base_silver.png",
	"panel_base_gold.png",
	"panel_base_crystal.png",
]
const EXPECTED_STAT_SLOT_FILES := [
	"stat_slots_bronze.png",
	"stat_slots_silver.png",
	"stat_slots_gold.png",
	"stat_slots_crystal.png",
]
const EXPECTED_ATTACK_FILES := [
	"attack_grid_bronze.png",
	"attack_grid_silver.png",
	"attack_grid_gold.png",
	"attack_grid_crystal.png",
]
const EXPECTED_QUALITY_IDS := ["bronze", "silver", "gold", "crystal"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var detail := PET_DETAIL_SCENE.instantiate() as Control
	root.add_child(detail)
	await process_frame
	var card := detail.get_node("Panel/SpriteInfoCard") as Control
	var base_art := card.get_node("BaseArt") as TextureRect
	var attack_format_plate := card.get_node("AttackFormatPlate") as TextureRect
	var stat_slot_art := card.get_node("StatSlotArt") as TextureRect
	assert(card.call("get_base_art_variant_names") == PackedStringArray(["青铜", "白银", "黄金", "水晶"]))
	assert(card.call("get_base_art_size") == EXPECTED_SIZE)
	card.set("base_art_selection", 1)
	await process_frame
	assert(int(card.call("get_base_art_index")) == 0)
	assert(base_art.texture.get_size() == EXPECTED_SIZE)
	assert(attack_format_plate.texture.get_size() == EXPECTED_ATTACK_SIZE)
	assert(stat_slot_art.texture.get_size() == EXPECTED_STAT_SLOT_SIZE)
	for index in range(4):
		assert(bool(card.call("set_base_art_by_index", index)))
		await process_frame
		assert(int(card.call("get_base_art_index")) == index)
		assert(base_art.texture != null)
		assert(base_art.texture.get_size() == EXPECTED_SIZE)
		assert(base_art.size == EXPECTED_SIZE)
		assert(base_art.texture.resource_path.get_file() == EXPECTED_BASE_FILES[index])
		assert(String(base_art.get_meta("quality_tier")) == EXPECTED_QUALITY_IDS[index])
		assert(attack_format_plate.texture != null)
		assert(attack_format_plate.texture.get_size() == EXPECTED_ATTACK_SIZE)
		assert(attack_format_plate.size == EXPECTED_ATTACK_SIZE)
		assert(attack_format_plate.texture.resource_path.get_file() == EXPECTED_ATTACK_FILES[index])
		assert(String(attack_format_plate.get_meta("quality_tier")) == EXPECTED_QUALITY_IDS[index])
		assert(stat_slot_art.texture != null)
		assert(stat_slot_art.texture.get_size() == EXPECTED_STAT_SLOT_SIZE)
		assert(stat_slot_art.size == EXPECTED_STAT_SLOT_SIZE)
		assert(stat_slot_art.texture.resource_path.get_file() == EXPECTED_STAT_SLOT_FILES[index])
		assert(String(stat_slot_art.get_meta("quality_tier")) == EXPECTED_QUALITY_IDS[index])
	assert(bool(card.call("set_base_art_by_name", "黄金")))
	await process_frame
	assert(int(card.call("get_base_art_index")) == 2)
	card.call("set_info", {"name": "手动卡底", "quality": "青铜"})
	assert(int(card.call("get_base_art_index")) == 2)
	card.call("follow_quality_base_art")
	await process_frame
	card.call("set_info", {"name": "自动卡底", "quality": "白银"})
	assert(int(card.call("get_base_art_index")) == 1)
	assert(not bool(card.call("set_base_art_by_index", 4)))
	assert(not bool(card.call("set_base_art_by_name", "不存在")))
	print("SPRITE_INFO_CARD_BASE_ART_SMOKE_PASS")
	quit(0)
