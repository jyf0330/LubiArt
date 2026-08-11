extends SceneTree

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const DEBUG_SCENE := preload("res://art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BATTLE_SCENE.instantiate() as Control
	assert(battle.get_node_or_null("SpriteInfoCardDebugPanel") == null)
	battle.free()

	var debug_scene := DEBUG_SCENE.instantiate() as Control
	root.add_child(debug_scene)
	var panel := debug_scene.get_node("SpriteInfoCardDebugPanel") as PanelContainer
	assert(debug_scene.scene_file_path == "res://art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn")
	await process_frame
	await process_frame
	assert(panel.find_children("*", "OptionButton", true, false).size() == 3)
	var value_edits := panel.find_children("*Edit", "LineEdit", true, false)
	assert(value_edits.size() == 6)
	assert(panel.find_children("PetNameButton", "Button", true, false).size() == 1)
	var card := panel.call("debug_card") as Control
	assert(card != null)
	var pet_names := PackedStringArray(panel.call("get_debug_pet_names"))
	assert(pet_names == PackedStringArray(["星茸", "烬尾狐", "霜团子", "青雷貂", "月壳龟", "琉璃星狐"]))
	var unique_names: Dictionary = {}
	for pet_name in pet_names:
		assert(pet_name.length() >= 2 and pet_name.length() <= 4)
		assert(not unique_names.has(pet_name))
		unique_names[pet_name] = true
	assert((card.get_node("PetName") as Label).text == pet_names[0])
	for name_index in range(1, pet_names.size()):
		assert(String(panel.call("debug_cycle_pet_name")) == pet_names[name_index])
		assert((card.get_node("PetName") as Label).text == pet_names[name_index])
	assert(String(panel.call("debug_cycle_pet_name")) == pet_names[0])
	assert((card.get_node("PetName") as Label).text == pet_names[0])

	assert(bool(panel.call("debug_select_element", 6)))
	await process_frame
	assert((card.get_node("ElementArt") as TextureRect).texture.resource_path.get_file() == "element_dark_visible.png")

	var quality_ids := ["bronze", "silver", "gold", "crystal"]
	var quality_names := ["青铜", "白银", "黄金", "水晶"]
	assert(card.find_children("BaseArt", "", true, false).size() == 1)
	assert(card.find_children("AttackFormatPlate", "", true, false).size() == 1)
	assert(card.find_children("StatSlotArt", "", true, false).size() == 1)
	for quality_index in range(quality_ids.size()):
		assert(bool(panel.call("debug_select_quality", quality_index)))
		await process_frame
		var quality_id: String = quality_ids[quality_index]
		var base_art := card.get_node("BaseArt") as TextureRect
		var attack_art := card.get_node("AttackFormatPlate") as TextureRect
		var stat_art := card.get_node("StatSlotArt") as TextureRect
		assert(base_art.texture.resource_path.get_file() == "panel_base.png")
		assert(attack_art.texture.resource_path.get_file() == "attack_grid.png")
		assert(stat_art.texture.resource_path.get_file() == "stat_icons_static.png")
		assert(String(base_art.get_meta("quality_tier")) == quality_id)
		assert(String(attack_art.get_meta("quality_tier")) == quality_id)
		assert(String(stat_art.get_meta("quality_tier")) == quality_id)
		assert(String(Dictionary(card.call("get_info_snapshot")).get("quality")) == quality_names[quality_index])

	var lock_art := card.get_node("TraitLockSilver") as TextureRect
	var trait_selector := panel.find_child("TraitSelector", true, false) as OptionButton
	assert(lock_art.visible)
	assert(trait_selector.disabled)
	assert(not bool(panel.call("debug_select_trait", 5)))
	assert(bool(panel.call("debug_set_trait_lock_visible", false)))
	assert(not lock_art.visible)
	assert(not trait_selector.disabled)
	assert(bool(panel.call("debug_select_trait", 5)))
	await process_frame
	assert((card.get_node("TraitArt") as TextureRect).texture.resource_path.get_file() == "trait_silver_element_echo.png")
	assert(bool(panel.call("debug_set_trait_lock_visible", true)))
	assert(lock_art.visible)
	assert(trait_selector.disabled)

	var result := Dictionary(panel.call("debug_set_values", {
		"hp": 31,
		"max_hp": 40,
		"attack": 9,
		"ap": 6,
		"max_ap": 8,
		"defense": 7,
		"shield": 5,
		"regen": 4,
	}))
	assert(int(result.get("hp", -1)) == 31)
	assert((card.get_node("StatsUI/HpValue") as Label).text == "31/40")
	assert((card.get_node("StatsUI/AttackValue") as Label).text == "9")
	assert((card.get_node("StatsUI/ApValue") as Label).text == "6/8")
	assert((card.get_node("StatsUI/DefenseValue") as Label).text == "7")
	assert((card.get_node("StatsUI/ShieldValue") as Label).text == "5")
	assert((card.get_node("StatsUI/RegenValue") as Label).text == "4")
	print("SPRITE_INFO_CARD_STANDALONE_DEBUG_SMOKE_PASS")
	quit(0)
