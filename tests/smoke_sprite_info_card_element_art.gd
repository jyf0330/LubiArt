extends SceneTree

const PET_DETAIL_SCENE := preload("res://art/prefabs/pet/pet_detail.tscn")
const EXPECTED_SIZE := Vector2(93.0, 115.0)
const EXPECTED_NAMES := ["暗", "水", "冰", "草", "电", "风", "火", "龙", "土"]
const EXPECTED_FILES := [
	"element_dark.png",
	"element_water.png",
	"element_ice.png",
	"element_grass.png",
	"element_electric.png",
	"element_wind.png",
	"element_fire.png",
	"element_dragon.png",
	"element_earth.png",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var detail := PET_DETAIL_SCENE.instantiate() as Control
	root.add_child(detail)
	await process_frame
	var card := detail.get_node("Panel/SpriteInfoCard") as Control
	var element_art := card.get_node("ElementArt") as TextureRect
	assert(card.call("get_element_art_variant_names") == PackedStringArray(EXPECTED_NAMES))
	assert(card.call("get_element_art_size") == EXPECTED_SIZE)
	card.set("element_art_selection", 1)
	await process_frame
	assert(int(card.call("get_element_art_index")) == 0)
	for index in range(EXPECTED_FILES.size()):
		assert(bool(card.call("set_element_art_by_index", index)))
		await process_frame
		assert(int(card.call("get_element_art_index")) == index)
		assert(element_art.visible)
		assert(element_art.texture != null)
		assert(element_art.texture.get_size() == EXPECTED_SIZE)
		assert(element_art.size == EXPECTED_SIZE)
		assert(element_art.texture.resource_path.get_file() == EXPECTED_FILES[index])
	assert(bool(card.call("set_element_art_by_name", "电")))
	await process_frame
	assert(int(card.call("get_element_art_index")) == 4)
	card.call("set_info", {"name": "手动属性", "element": "水"})
	assert(int(card.call("get_element_art_index")) == 4)
	card.call("follow_pet_element_art")
	await process_frame
	card.call("set_info", {"name": "自动属性", "element": "龙"})
	assert(int(card.call("get_element_art_index")) == 7)
	assert(not bool(card.call("set_element_art_by_index", 9)))
	assert(not bool(card.call("set_element_art_by_name", "不存在")))
	print("SPRITE_INFO_CARD_ELEMENT_ART_SMOKE_PASS")
	quit(0)
