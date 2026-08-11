extends SceneTree

const PetScene := preload("res://art/prefabs/pet/pet.tscn")
const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const SOURCE_PATH := "res://art/images/shared/pets/sheets/slices/pet_style_001_gold_mascot.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_texture := load(SOURCE_PATH) as Texture2D
	if source_texture == null:
		_fail("missing source texture")
		return

	var pet := PetScene.instantiate() as Control
	pet.size = Vector2(150.0, 132.0)
	root.add_child(pet)
	await process_frame
	var assets := BattleAssetRegistryScript.new()
	pet.call("set_unit_data", {
		"unitId": "pal_002_identity_test",
		"pet_id": "pal_002",
		"name": "Mischief Cat",
		"hp": 10,
		"atk": 2,
		"shield": 0,
	}, "player", assets)
	await process_frame
	await process_frame

	var sprite := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
	var animation := pet.get_node("CompleteBattleCreaturePrefab/03_AttackActions")
	var snapshot := Dictionary(animation.call("get_frame_animation_snapshot"))
	var actions := Dictionary(snapshot.get("actions", {}))
	if actions.has("idle"):
		_fail("gold mascot must not use the mismatched wolf idle frames")
		return
	if String(snapshot.get("active_action", "")) != "idle" \
			or not bool(snapshot.get("uses_transform_idle", false)):
		_fail("the identity-safe transform idle did not start")
		return
	if sprite.texture != source_texture or sprite.texture.resource_path != SOURCE_PATH:
		_fail("gold mascot source texture was replaced")
		return
	var first_scale := sprite.scale
	var first_position := sprite.position
	await create_timer(0.55).timeout
	if sprite.scale.is_equal_approx(first_scale):
		_fail("the transform idle did not visibly advance")
		return
	if not sprite.position.is_equal_approx(first_position):
		_fail("the transform idle moved the authored foot position")
		return
	if sprite.texture != source_texture or sprite.texture.resource_path != SOURCE_PATH:
		_fail("the transform idle replaced the gold mascot identity")
		return
	print("SMOKE_GOLD_MASCOT_IDENTITY_SAFE_IDLE_PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error("SMOKE_GOLD_MASCOT_IDLE_ANIMATION_FAIL: %s" % message)
	quit(1)
