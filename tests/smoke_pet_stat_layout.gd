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
	pet.size = Vector2(171.0, 168.0)
	await process_frame
	var stats := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var health := stats.get_node("Health") as Control
	var incoming_damage_preview := pet.get_node(
		"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/IncomingDamagePreview"
	) as Control
	assert(not stats.z_as_relative)
	assert(stats.z_index == 203)
	assert(incoming_damage_preview.get_parent() == health)
	assert(incoming_damage_preview.z_as_relative)
	assert(incoming_damage_preview.z_index == 0)
	var shield := stats.get_node("Shield") as Control
	var attack := stats.get_node("Attack") as Control
	var damage_cap := stats.get_node("DamageCap") as Control
	var groups: Array[Control] = [health, attack, shield, damage_cap]
	var authored_sizes := [
		# The Control is 10px high so Godot's last fill row is masked by the
		# frame; the authored visible slot remains exactly 96x9 pixels.
		Vector2(96.0, 10.0),
		Vector2(88.0, 24.0),
		Vector2(96.0, 3.0),
		Vector2(88.0, 24.0),
	]
	var authored_label_rects: Array[Rect2] = []
	for index in range(groups.size()):
		_assert_vector_close(groups[index].size, authored_sizes[index])
		var icon := groups[index].get_node("Icon") as Control
		var label := groups[index].get_node("Value_Text") as Label
		assert(icon.visible == (index == 0))
		authored_label_rects.append(Rect2(label.position, label.size))
	pet.call("set_unit_data", {
		"unitId": "stat_layout_test",
		"hp": 17,
		"atk": 5,
		"shield": 9,
		"damageCap": 16,
	}, "player", null)
	await process_frame

	var front_corners := PackedVector2Array([
		Vector2.ZERO,
		Vector2(pet.size.x, 0.0),
		pet.size,
		Vector2(0.0, pet.size.y),
	])
	pet.call("set_battle_stat_layout_scale", 1.0, front_corners)
	# Every row keeps its prefab-authored text rectangle and is placed in the
	# same vertical column along the cell's right edge.
	for index in range(groups.size()):
		_assert_vector_close(groups[index].size, authored_sizes[index])
		assert(groups[index].scale == Vector2.ONE)
		var icon := groups[index].get_node("Icon") as Control
		var label := groups[index].get_node("Value_Text") as Label
		assert(icon.visible == (index == 0))
		assert(Rect2(label.position, label.size).is_equal_approx(authored_label_rects[index]))
	var labels := [
		health.get_node("Value_Text") as Label,
		attack.get_node("Value_Text") as Label,
		shield.get_node("Value_Text") as Label,
		damage_cap.get_node("Value_Text") as Label,
	]
	assert(labels[0].text == "HP:17")
	assert(labels[1].text == "ATK:5")
	assert(labels[2].text == "SHLD:9")
	assert(labels[3].text == "CAP:16")
	assert(labels[0].self_modulate.is_equal_approx(Color("ffffff")))
	assert(labels[1].self_modulate.is_equal_approx(Color("ffffff")))
	assert(labels[2].self_modulate.is_equal_approx(Color("ffffff")))
	assert(labels[3].self_modulate.is_equal_approx(Color("ffffff")))
	assert(labels[0].horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	for index in range(1, labels.size()):
		assert(labels[index].horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	for label in labels:
		assert(label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER)
	_assert_health_bar_tracks_sprite_top(pet, health, front_corners)
	# Rebinding data triggers the pet's normal layout pass; the right-side column
	# must survive it without accumulating offsets or falling back to sprite bounds.
	pet.call("set_unit_data", {
		"unitId": "stat_layout_test_rebound",
		"hp": 16,
		"atk": 6,
		"shield": 8,
		"damageCap": 15,
	}, "player", null)
	await process_frame
	_assert_health_bar_tracks_sprite_top(pet, health, front_corners)

	# Exercise a narrower, trapezoidal back row as well as the front-row rectangle.
	pet.size = Vector2(135.0, 110.0)
	var back_row_scale := 0.65
	var back_corners := PackedVector2Array([
		Vector2(15.0, 0.0),
		Vector2(135.0, 0.0),
		Vector2(124.0, 110.0),
		Vector2(0.0, 110.0),
	])
	pet.call("set_battle_stat_layout_scale", back_row_scale, back_corners)
	await process_frame
	for index in range(groups.size()):
		_assert_vector_close(groups[index].size, authored_sizes[index])
		_assert_vector_close(groups[index].scale, Vector2.ONE * back_row_scale)
		var icon := groups[index].get_node("Icon") as Control
		var label := groups[index].get_node("Value_Text") as Label
		assert(icon.visible == (index == 0))
		assert(Rect2(label.position, label.size).is_equal_approx(authored_label_rects[index]))
	_assert_health_bar_tracks_sprite_top(pet, health, back_corners)
	assert(stats.visible)
	assert(health.visible)
	assert(not attack.visible)
	assert(shield.visible)
	assert(is_equal_approx(shield.position.x, health.position.x))
	assert(is_equal_approx(shield.position.y - health.position.y, 12.0 * health.scale.y))
	assert(not damage_cap.visible)
	assert(health is ProgressBar)
	assert(is_equal_approx((health as ProgressBar).value, 16.0))
	assert(is_equal_approx((health as ProgressBar).max_value, 16.0))
	pet.call("set_dragging", true)
	assert(not pet.visible)
	assert(stats.visible)
	pet.call("set_dragging", false)
	assert(pet.visible)
	assert(stats.visible)
	pet.name = "BattleUnitDragPreview"
	pet.call("set_dragging", false)
	assert(stats.visible)

	print("PET_STAT_LAYOUT_SMOKE_PASS")
	quit(0)


func _assert_vector_close(actual: Vector2, expected: Vector2) -> void:
	assert(actual.is_equal_approx(expected), "%s != %s" % [actual, expected])


func _assert_health_bar_tracks_sprite_top(
	pet: Control,
	health: Control,
	corners: PackedVector2Array
) -> void:
	var bounds := Rect2(health.position, health.size * health.scale)
	var center_y := bounds.get_center().y
	var left_x := _edge_x_at_y(corners[0], corners[3], center_y)
	var right_x := _edge_x_at_y(corners[1], corners[2], center_y)
	assert(
		absf(bounds.get_center().x - (left_x + right_x) * 0.5) <= 0.5,
		"health center %s != cell center %s" % [
			bounds.get_center().x,
			(left_x + right_x) * 0.5,
		]
	)
	var sprite_top := float(pet.call("get_battle_sprite_actual_top_y"))
	var health_bottom := health.position.y + 11.0 * health.scale.y
	assert(absf(
		sprite_top - health_bottom - 14.0 * health.scale.y
	) <= 0.5001)


func _assert_rows_in_right_column(
	groups: Array[Control],
	corners: PackedVector2Array
) -> void:
	var previous_bottom := -INF
	var aligned_right := -INF
	for group in groups:
		var icon := group.get_node("Icon") as Control
		var label := group.get_node("Value_Text") as Control
		assert(not icon.visible)
		var row_bounds := Rect2(group.position, group.size * group.scale)
		assert(row_bounds.position.y > previous_bottom)
		var row_center_y := row_bounds.get_center().y
		var left_at_center := _edge_x_at_y(corners[0], corners[3], row_center_y)
		var right_at_center := _edge_x_at_y(corners[1], corners[2], row_center_y)
		assert(row_bounds.get_center().x > (left_at_center + right_at_center) * 0.5)
		if is_inf(aligned_right):
			aligned_right = row_bounds.end.x
		else:
			assert(is_equal_approx(row_bounds.end.x, aligned_right))
		assert(is_zero_approx(group.rotation))
		assert(is_zero_approx(label.rotation))
		previous_bottom = row_bounds.end.y
	var column_top := groups[0].position.y
	assert(is_equal_approx(column_top, minf(corners[0].y, corners[1].y)))
	var last_group := groups[groups.size() - 1]
	var column_bottom := last_group.position.y + last_group.size.y * last_group.scale.y
	var shared_right_edge := minf(
		_edge_x_at_y(corners[1], corners[2], column_top),
		_edge_x_at_y(corners[1], corners[2], column_bottom)
	)
	assert(is_equal_approx(shared_right_edge - aligned_right, 4.0 * groups[0].scale.x))


func _edge_x_at_y(edge_start: Vector2, edge_end: Vector2, y: float) -> float:
	if is_zero_approx(edge_end.y - edge_start.y):
		return edge_start.x
	var weight := clampf((y - edge_start.y) / (edge_end.y - edge_start.y), 0.0, 1.0)
	return lerpf(edge_start.x, edge_end.x, weight)
