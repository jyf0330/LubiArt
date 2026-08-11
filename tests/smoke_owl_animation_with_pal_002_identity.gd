extends SceneTree

const PetScene := preload("res://art/prefabs/pet/pet.tscn")
const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const OWL_FRAME := "res://art/images/shared/pets/animations/spr_009_azure_thunder_owl/anim_001_idle/frames/frame_001.png"
const OWL_STATIC := "res://art/images/shared/pets/sheets/slices/pet_style_003_blue_electric_shell.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _verify_real_battle_mapping():
		return
	if not await _verify_explicit_image_override():
		return
	print("SMOKE_OWL_ANIMATION_WITH_PAL_002_IDENTITY_PASS")
	quit(0)


func _verify_real_battle_mapping() -> bool:
	var pet := PetScene.instantiate() as Control
	pet.size = Vector2(150.0, 132.0)
	root.add_child(pet)
	await process_frame
	var assets := BattleAssetRegistryScript.new()
	pet.call("set_unit_data", {
		"unitId": "shop_004",
		"pet_id": "pal_028",
		"name": "波娜兔",
		"hp": 10,
		"atk": 2,
		"shield": 0,
	}, "player", assets)
	await process_frame

	var animation := pet.get_node("CompleteBattleCreaturePrefab/03_AttackActions")
	var snapshot := Dictionary(animation.call("get_frame_animation_snapshot"))
	var actions := Dictionary(snapshot.get("actions", {}))
	if String(snapshot.get("source_texture_path", "")) != OWL_STATIC:
		pet.queue_free()
		_fail("pal_028 did not resolve through the real battle static texture")
		return false
	if int(actions.get("idle", 0)) != 16 or String(snapshot.get("active_action", "")) != "idle":
		pet.queue_free()
		_fail("pal_028 static texture alias did not start the owl idle animation")
		return false
	var sprite := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
	await create_timer(0.35).timeout
	if sprite.texture == null or sprite.texture.resource_path == OWL_FRAME:
		pet.queue_free()
		_fail("pal_028 owl texture did not advance beyond the first frame")
		return false
	pet.queue_free()
	await process_frame
	return true


func _verify_explicit_image_override() -> bool:
	var pet := PetScene.instantiate() as Control
	pet.size = Vector2(150.0, 132.0)
	root.add_child(pet)
	await process_frame
	var assets := BattleAssetRegistryScript.new()
	pet.call("set_unit_data", {
		"unitId": "owl_with_legacy_pet_identity",
		"pet_id": "pal_002",
		"image": OWL_FRAME,
		"name": "Azure Thunder Owl",
		"hp": 10,
		"atk": 2,
		"shield": 0,
	}, "player", assets)
	await process_frame

	var animation := pet.get_node("CompleteBattleCreaturePrefab/03_AttackActions")
	var snapshot := Dictionary(animation.call("get_frame_animation_snapshot"))
	var actions := Dictionary(snapshot.get("actions", {}))
	if int(actions.get("idle", 0)) != 16:
		pet.queue_free()
		_fail("owl idle frames were suppressed by the unrelated pet id")
		return false
	if String(snapshot.get("active_action", "")) != "idle":
		pet.queue_free()
		_fail("owl idle animation did not start")
		return false
	var sprite := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
	await create_timer(0.35).timeout
	if sprite.texture == null or sprite.texture.resource_path == OWL_FRAME:
		pet.queue_free()
		_fail("owl texture did not advance beyond the first frame")
		return false
	pet.queue_free()
	await process_frame
	return true


func _fail(message: String) -> void:
	push_error("SMOKE_OWL_ANIMATION_WITH_PAL_002_IDENTITY_FAIL: %s" % message)
	quit(1)
