extends SceneTree

const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pet := BattleUnitScene.instantiate() as Control
	assert(pet != null)
	root.add_child(pet)
	await process_frame
	pet.call("set_unit_data", {
		"unitId": "incoming_damage_badge_test",
		"hp": 20,
		"max_hp": 20,
		"shield": 2,
		"atk": 5,
	}, "player", null)
	pet.call("start_damage_preview", 20, 7, -1, 15, 2, 0, 20, true)
	var badge := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/IncomingDamagePreview") as Control
	var value := badge.get_node("Value") as Label
	var stats_root := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var preview := Dictionary(pet.call("get_damage_preview_snapshot"))
	assert(bool(preview.get("active", false)))
	assert(bool(preview.get("uses_badge", false)))
	assert(int(preview.get("displayed_damage", -1)) == 15)
	assert(int(preview.get("displayed_hp", -1)) == 20)
	assert(badge.visible)
	assert(value.text == "15")
	assert(value.self_modulate == Color.WHITE)
	assert(stats_root.visible)
	assert(is_equal_approx(badge.position.x, pet.size.x - badge.size.x * 0.75))
	assert(is_equal_approx(badge.position.y + badge.size.y, 4.0))
	assert(badge.position.y < 0.0)
	pet.call("stop_damage_preview")
	assert(not badge.visible)
	assert(value.text == "")
	print("INCOMING_DAMAGE_BADGE_SMOKE_PASS")
	quit(0)
