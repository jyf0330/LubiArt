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
		"unitId": "stats_hover_test",
		"hp": 24,
		"max_hp": 24,
		"shield": 0,
		"atk": 4,
	}, "player", null)
	var stats := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var health_bar := stats.get_node("Health") as ProgressBar
	var attack := stats.get_node("Attack") as Control
	var shield := stats.get_node("Shield") as Control
	var damage_cap := stats.get_node("DamageCap") as Control

	pet.call("set_battle_stats_pointer_hovered", true)
	await process_frame
	assert(stats.visible)
	assert(health_bar.visible)
	assert(not attack.visible)
	assert(not shield.visible)
	assert(not damage_cap.visible)
	assert(is_equal_approx(health_bar.value, 24.0))
	assert(is_equal_approx(health_bar.max_value, 24.0))

	pet.call("set_battle_stats_pointer_hovered", false)
	await process_frame
	assert(stats.visible)
	assert(health_bar.visible)

	pet.queue_free()
	await process_frame
	print("PET_HEALTH_BAR_VISIBILITY_SMOKE_PASS")
	quit(0)
