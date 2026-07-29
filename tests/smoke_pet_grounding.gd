extends SceneTree

const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")

const CASES := [
	{
		"path": "res://art/images/shared/pets/sheets/slices/shop_creature_001_water_tidewhisker.png",
		"expects_trim": false,
		"expected_inset": 15.0,
	},
	{
		"path": "res://art/images/shared/pets/sheets/slices/shop_creature_006_water_pondhopper.png",
		"expects_trim": false,
		"expected_inset": 7.0,
	},
	{
		"path": "res://art/images/shared/pets/sheets/slices/shop_creature_011_water_pearlcrab.png",
		"expects_trim": true,
		"expected_inset": 15.0,
	},
	{
		"path": "res://art/images/shared/pets/sheets/slices/shop_creature_042_wind_twister.png",
		"expects_trim": true,
		"expected_inset": 15.0,
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(640.0, 360.0)
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
		assert(is_equal_approx(float(pet.call("get_battle_footline_bottom_inset")), float(test_case["expected_inset"])))
		var shadow_center_y := shadow.position.y + shadow.size.y * 0.5
		var visible_rect := Rect2(pet.call("get_battle_sprite_visible_rect"))
		assert(is_equal_approx(visible_rect.end.y, footline_y))
		assert(shadow_center_y < footline_y)
		assert(shadow_center_y >= footline_y - 4.0)
		assert(shadow.visible)
		assert(shadow.z_index < creature_art.z_index)
		assert(shadow_strength.texture == shadow.texture)
		assert(shadow.position.y + shadow.size.y <= pet.size.y)
		var removed_pixels := int(pet.call("get_battle_removed_bottom_pixels"))
		assert((removed_pixels > 0) == bool(test_case["expects_trim"]))
		pet.queue_free()
		await process_frame
	print("PET_GROUNDING_SMOKE_PASS")
	quit(0)
