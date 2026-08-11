extends SceneTree

const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")
const BattleVfxScript := preload("res://core_ui/scripts/battle/controllers/battle_vfx_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(480.0, 300.0)
	root.add_child(host)
	var unit := BattleUnitScene.instantiate() as Control
	unit.position = Vector2(120.0, 60.0)
	unit.size = Vector2(180.0, 180.0)
	host.add_child(unit)
	unit.call("set_unit_data", {
		"unitId": "damage_feedback_target",
		"hp": 15,
		"pet_id": "pal_001",
	}, "enemy", null)
	await process_frame

	var health := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health") as ProgressBar
	assert(is_equal_approx(health.max_value, 15.0))
	assert(is_equal_approx(health.value, 15.0))
	unit.call("play_damage_feedback", {
		"finalDamage": 6,
		"hpDamage": 6,
		"shieldDamage": 0,
		"hpFrom": 15,
		"hpTo": 9,
		"shieldFrom": 0,
		"shieldTo": 0,
	})
	assert(is_equal_approx(health.value, 15.0))
	await process_frame
	assert(is_equal_approx(health.max_value, 15.0))
	assert(health.value <= 15.0 and health.value >= 9.0)
	await create_timer(0.4).timeout
	assert(is_equal_approx(health.value, 9.0))
	assert(is_equal_approx(health.value / health.max_value, 0.6))

	var vfx := BattleVfxScript.new() as Control
	vfx.size = host.size
	host.add_child(vfx)
	vfx.call("_apply_damage_impact", {
		"actor": {"id": "attacker", "x": 0, "y": 0},
		"target": {"id": "damage_feedback_target", "x": 1, "y": 1},
		"payload": {
			"finalDamage": 4,
			"hpDamage": 4,
			"hpFrom": 9,
			"hpTo": 5,
		},
	}, unit)
	await process_frame
	var number: Label = null
	for child in vfx.get_children():
		if child is Label and String(child.name).begins_with("DamageNumber_"):
			number = child as Label
			break
	assert(number != null)
	assert(number.text == "-4")
	assert(int(number.get_meta("damage_amount", 0)) == 4)
	var start_y := number.position.y
	await create_timer(0.2).timeout
	assert(number.position.y < start_y)
	assert(number.modulate.a < 1.0)
	await create_timer(0.5).timeout
	assert(not is_instance_valid(number))

	print("PET_DAMAGE_FEEDBACK_SMOKE_PASS")
	quit(0)
