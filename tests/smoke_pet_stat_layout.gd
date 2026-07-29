extends SceneTree

const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(640.0, 360.0)
	root.add_child(host)
	var pet := BattleUnitScene.instantiate() as Control
	pet.custom_minimum_size = Vector2.ZERO
	host.add_child(pet)
	pet.size = Vector2(150.0, 132.0)
	await process_frame
	pet.call("set_unit_data", {
		"unitId": "stat_layout_test",
		"hp": 17,
		"atk": 5,
		"shield": 9,
		"damageCap": 16,
	}, "player", null)
	await process_frame

	var stats := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var health := stats.get_node("Health") as Control
	var shield := stats.get_node("Shield") as Control
	var attack := stats.get_node("Attack") as Control
	var damage_cap := stats.get_node("DamageCap") as Control
	var stat_scale := minf(pet.size.x / 171.0, pet.size.y / 144.0)
	var edge_inset := 10.0 * stat_scale
	_assert_vector_close(health.position, Vector2(edge_inset, edge_inset))
	_assert_vector_close(health.size, Vector2(38.0, 36.0) * stat_scale)
	_assert_vector_close(shield.position, Vector2(
		pet.size.x - 35.0 * stat_scale - edge_inset,
		edge_inset
	))
	_assert_vector_close(shield.size, Vector2(35.0, 46.0) * stat_scale)
	_assert_vector_close(attack.position, Vector2(
		edge_inset,
		pet.size.y - 51.0 * stat_scale - edge_inset
	))
	_assert_vector_close(attack.size, Vector2(49.0, 51.0) * stat_scale)
	_assert_vector_close(damage_cap.position, Vector2(
		pet.size.x - 39.0 * stat_scale - edge_inset,
		pet.size.y - 47.0 * stat_scale - edge_inset
	))
	_assert_vector_close(damage_cap.size, Vector2(39.0, 47.0) * stat_scale)
	for group in [health, shield, attack, damage_cap]:
		assert(group.scale == Vector2.ONE)
	var labels := [
		health.get_node("Value_Text") as Label,
		shield.get_node("Value_Text") as Label,
		attack.get_node("Value_Text") as Label,
		damage_cap.get_node("Value_Text") as Label,
	]
	assert(labels[0].text == "17")
	assert(labels[1].text == "9")
	assert(labels[2].text == "5")
	assert(labels[3].text == "16")
	var expected_font_size := maxi(9, int(round(20.0 * stat_scale)))
	for index in range(labels.size()):
		var label := labels[index] as Label
		var group := [health, shield, attack, damage_cap][index] as Control
		assert(label.position == Vector2.ZERO)
		_assert_vector_close(label.size, group.size)
		assert(label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
		assert(label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER)
		var label_font_size := maxi(9, int(round(20.0 * stat_scale * 0.83))) if index == 0 else expected_font_size
		assert(label.get_theme_font_size("font_size") == label_font_size)
	assert(health.position.x >= 0.0 and health.position.y >= 0.0)
	assert(shield.position.x + shield.size.x <= pet.size.x)
	assert(attack.position.x >= 0.0 and attack.position.y + attack.size.y <= pet.size.y)
	assert(damage_cap.position.x + damage_cap.size.x <= pet.size.x)
	assert(damage_cap.position.y + damage_cap.size.y <= pet.size.y)

	var back_row_health_size := health.size
	pet.size = Vector2(190.0, 170.0)
	await process_frame
	assert(health.size.x > back_row_health_size.x)
	_assert_vector_close((health.get_node("Value_Text") as Label).size, health.size)

	print("PET_STAT_LAYOUT_SMOKE_PASS")
	quit(0)


func _assert_vector_close(actual: Vector2, expected: Vector2) -> void:
	assert(actual.is_equal_approx(expected), "%s != %s" % [actual, expected])
