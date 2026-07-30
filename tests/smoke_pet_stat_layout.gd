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
	var shield := stats.get_node("Shield") as Control
	var attack := stats.get_node("Attack") as Control
	var damage_cap := stats.get_node("DamageCap") as Control
	var groups: Array[Control] = [health, shield, attack, damage_cap]
	var authored_sizes := [
		Vector2(38.0, 36.0),
		Vector2(35.0, 46.0),
		Vector2(49.0, 51.0),
		Vector2(39.0, 47.0),
	]
	var authored_icon_rects: Array[Rect2] = []
	var authored_label_rects: Array[Rect2] = []
	for index in range(groups.size()):
		_assert_vector_close(groups[index].size, authored_sizes[index])
		var icon := groups[index].get_node("Icon") as Control
		var label := groups[index].get_node("Value_Text") as Label
		authored_icon_rects.append(Rect2(icon.position, icon.size))
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
	# Every row keeps the prefab-authored icon and text rectangles, while each
	# complete badge is centered directly on its cell corner.
	for index in range(groups.size()):
		_assert_vector_close(groups[index].size, authored_sizes[index])
		assert(groups[index].scale == Vector2.ONE)
		var icon := groups[index].get_node("Icon") as Control
		var label := groups[index].get_node("Value_Text") as Label
		assert(Rect2(icon.position, icon.size).is_equal_approx(authored_icon_rects[index]))
		assert(Rect2(label.position, label.size).is_equal_approx(authored_label_rects[index]))
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
	for index in range(labels.size()):
		var label := labels[index] as Label
		assert(label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
		assert(label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER)
	_assert_badges_at_corners(health, shield, attack, damage_cap, front_corners)
	# Rebinding data triggers the pet's normal layout pass; the corner lock must
	# survive it without accumulating offsets or falling back to sprite bounds.
	pet.call("set_unit_data", {
		"unitId": "stat_layout_test_rebound",
		"hp": 16,
		"atk": 6,
		"shield": 8,
		"damageCap": 15,
	}, "player", null)
	await process_frame
	_assert_badges_at_corners(health, shield, attack, damage_cap, front_corners)

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
		assert(Rect2(icon.position, icon.size).is_equal_approx(authored_icon_rects[index]))
		assert(Rect2(label.position, label.size).is_equal_approx(authored_label_rects[index]))
	_assert_badges_at_corners(health, shield, attack, damage_cap, back_corners)

	print("PET_STAT_LAYOUT_SMOKE_PASS")
	quit(0)


func _assert_vector_close(actual: Vector2, expected: Vector2) -> void:
	assert(actual.is_equal_approx(expected), "%s != %s" % [actual, expected])


func _assert_badges_at_corners(
	health: Control,
	shield: Control,
	attack: Control,
	damage_cap: Control,
	corners: PackedVector2Array
) -> void:
	_assert_icon_inside_corner(health, 0, corners)
	_assert_icon_inside_corner(damage_cap, 1, corners)
	_assert_icon_inside_corner(shield, 2, corners)
	_assert_icon_inside_corner(attack, 3, corners)


func _assert_icon_inside_corner(
	group: Control,
	corner_index: int,
	corners: PackedVector2Array
) -> void:
	var icon := group.get_node("Icon") as Control
	var label := group.get_node("Value_Text") as Control
	var icon_bounds := Rect2(
		group.position + icon.position * group.scale,
		icon.size * group.scale
	)
	var is_top := corner_index <= 1
	var is_left := corner_index == 0 or corner_index == 3
	var side_top := corners[0] if is_left else corners[1]
	var side_bottom := corners[3] if is_left else corners[2]
	var side_x_at_top := _edge_x_at_y(side_top, side_bottom, icon_bounds.position.y)
	var side_x_at_bottom := _edge_x_at_y(side_top, side_bottom, icon_bounds.end.y)
	_assert_vector_close(
		Vector2(icon_bounds.position.y, icon_bounds.end.y),
		Vector2(corners[corner_index].y, corners[corner_index].y + icon_bounds.size.y) if is_top else \
			Vector2(corners[corner_index].y - icon_bounds.size.y, corners[corner_index].y)
	)
	var expected_side_x := maxf(side_x_at_top, side_x_at_bottom) if is_left else \
		minf(side_x_at_top, side_x_at_bottom)
	assert(is_equal_approx(
		icon_bounds.position.x if is_left else icon_bounds.end.x,
		expected_side_x
	))
	assert(is_zero_approx(group.rotation))
	assert(is_zero_approx(label.rotation))


func _edge_x_at_y(edge_start: Vector2, edge_end: Vector2, y: float) -> float:
	if is_zero_approx(edge_end.y - edge_start.y):
		return edge_start.x
	var weight := clampf((y - edge_start.y) / (edge_end.y - edge_start.y), 0.0, 1.0)
	return lerpf(edge_start.x, edge_end.x, weight)
