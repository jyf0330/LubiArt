extends SceneTree

const PetScene := preload("res://art/prefabs/pet/pet.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pet := PetScene.instantiate() as Control
	root.add_child(pet)
	pet.size = Vector2(171.0, 144.0)
	await process_frame
	pet.call("set_unit_data", {
		"unitId": "hit_reaction_test",
		"unitName": "受击测试",
		"hp": 20,
		"shield": 0,
		"atk": 5,
	}, "enemy", null)
	await process_frame

	var reaction := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/HitReactionPlayer")
	var shield_effect := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/ShieldHitEffectPlayer")
	var sprite := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
	var shadow := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Shadow") as Control
	var stats := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var sprite_origin := sprite.position
	var sprite_scale_origin := sprite.scale
	var sprite_pivot_origin := sprite.pivot_offset
	var pet_origin := pet.position
	var shadow_origin := shadow.position
	var stats_origin := stats.position
	pet.call("play_damage_feedback", {
		"finalDamage": 5,
		"shieldDamage": 0,
		"hpDamage": 5,
		"shieldFrom": 0,
		"shieldTo": 0,
		"hpTo": 15,
	}, Vector2(1.0, -1.0))

	var first := Dictionary(reaction.call("snapshot"))
	assert(bool(first.get("active", false)))
	assert(int(first.get("frame_index", -1)) == 0)
	assert(bool(first.get("effect_visible", false)))
	assert(Vector2(first.get("effect_size", Vector2.ZERO)) == Vector2(145.0, 290.0))
	assert(not bool(Dictionary(shield_effect.call("snapshot")).get("active", true)))
	await create_timer(0.075, true, false, true).timeout
	var impact := Dictionary(reaction.call("snapshot"))
	assert(int(impact.get("frame_index", -1)) >= 1)
	assert(sprite.position.is_equal_approx(sprite_origin))
	assert(sprite.scale.is_equal_approx(sprite_scale_origin))
	assert(sprite.pivot_offset.is_equal_approx(sprite_pivot_origin))
	assert(pet.position.is_equal_approx(pet_origin))
	assert(shadow.position == shadow_origin)
	assert(stats.position == stats_origin)
	await create_timer(0.5, true, false, true).timeout
	var restored := Dictionary(reaction.call("snapshot"))
	assert(not bool(restored.get("active", true)))
	assert(not bool(restored.get("effect_visible", true)))
	assert(sprite.position.is_equal_approx(sprite_origin))
	assert(sprite.scale.is_equal_approx(sprite_scale_origin))

	pet.call("set_unit_data", {
		"unitId": "shielded_hit_test",
		"unitName": "护盾测试",
		"hp": 20,
		"shield": 3,
		"atk": 5,
	}, "enemy", null)
	pet.call("play_damage_feedback", {
		"finalDamage": 2,
		"shieldDamage": 0,
		"hpDamage": 2,
		"shieldFrom": 3,
		"shieldTo": 3,
		"hpTo": 18,
	}, Vector2.RIGHT)
	assert(not bool(Dictionary(reaction.call("snapshot")).get("active", true)))
	var shield_first := Dictionary(shield_effect.call("snapshot"))
	assert(bool(shield_first.get("active", false)))
	assert(int(shield_first.get("frame_index", -1)) == 0)
	assert(bool(shield_first.get("effect_visible", false)))
	assert(Vector2(shield_first.get("effect_size", Vector2.ZERO)) == Vector2(180.0, 180.0))
	await create_timer(0.075, true, false, true).timeout
	assert(pet.position.is_equal_approx(pet_origin))
	assert(sprite.position.is_equal_approx(sprite_origin))
	assert(sprite.scale.is_equal_approx(sprite_scale_origin))
	await create_timer(0.45, true, false, true).timeout
	var shield_restored := Dictionary(shield_effect.call("snapshot"))
	assert(not bool(shield_restored.get("active", true)))
	assert(not bool(shield_restored.get("effect_visible", true)))
	print("PET_HIT_REACTION_SMOKE_PASS")
	quit(0)
