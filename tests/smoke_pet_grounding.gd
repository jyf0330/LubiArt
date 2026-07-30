extends SceneTree

const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")

const CASES := [
	{"path": "res://art/images/shared/pets/sheets/slices/pet_style_001_gold_mascot.png"},
	{"path": "res://art/images/shared/pets/sheets/slices/pet_style_002_gold_shell.png"},
	{"path": "res://art/images/shared/pets/sheets/slices/pet_style_003_blue_electric_shell.png"},
	{"path": "res://art/images/shared/pets/sheets/slices/pet_style_004_pink_electric_wave.png"},
	{"path": "res://art/images/shared/pets/sheets/slices/pet_style_005_earth_slime.png"},
	{"path": "res://art/images/shared/pets/sheets/slices/pet_style_006_shadow_rock_wolf.png"},
	{"path": "res://art/images/shared/pets/sheets/slices/pet_style_007_rock_claw.png"},
	{"path": "res://art/images/shared/pets/sheets/slices/pet_style_008_volcanic_dijiang.png"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1440.0, 360.0)
	root.add_child(host)
	for test_case in CASES:
		var pet := BattleUnitScene.instantiate() as Control
		pet.size = Vector2(150.0, 132.0)
		host.add_child(pet)
		await process_frame
		pet.call("set_unit_data", {"unitId": "grounding_test", "hp": 10, "atk": 2}, "player", null)
		var creature_art := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
		creature_art.texture = load(String(test_case["path"])) as Texture2D
		pet.call("_layout_children")
		await process_frame
		pet.call("_layout_children")
		var shadow := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Shadow") as TextureRect
		var shadow_strength := shadow.get_node("ShadowStrength") as TextureRect
		var footline_y := pet.size.y - float(pet.call("get_battle_footline_bottom_inset"))
		var shadow_center_y := shadow.position.y + shadow.size.y * 0.5
		var visible_rect := Rect2(pet.call("get_battle_sprite_visible_rect"))
		assert(is_equal_approx(float(pet.call("get_battle_footline_bottom_inset")), 15.0))
		assert(is_equal_approx(visible_rect.end.y, footline_y))
		assert(visible_rect.position.x >= -0.01)
		assert(visible_rect.end.x <= pet.size.x + 0.01)
		assert(shadow_center_y < footline_y)
		assert(shadow_center_y >= footline_y - 4.0)
		assert(shadow.visible)
		assert(shadow.z_index < creature_art.z_index)
		assert(shadow_strength.texture == shadow.texture)
		assert(shadow.position.y + shadow.size.y <= pet.size.y)
		assert(int(pet.call("get_battle_removed_bottom_pixels")) == 0)
		pet.queue_free()
		await process_frame
	print("PET_GROUNDING_SMOKE_PASS sprites=%d" % CASES.size())
	quit(0)
