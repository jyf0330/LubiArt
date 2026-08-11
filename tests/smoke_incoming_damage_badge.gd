extends SceneTree

const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for side in ["player", "enemy"]:
		var pet := BattleUnitScene.instantiate() as Control
		assert(pet != null)
		root.add_child(pet)
		await process_frame
		pet.call("set_unit_data", {
			"unitId": "incoming_damage_badge_%s_test" % side,
			"hp": 20,
			"max_hp": 20,
			"shield": 2,
			"atk": 5,
		}, side, null)
		pet.call("start_damage_preview", 20, 7, -1, 15, 2, 0, 20)
		var badge := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/IncomingDamagePreview") as Control
		var separator := badge.get_node("Background") as ColorRect
		var value := badge.get_node("Value") as Label
		var stats_root := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
		var health := stats_root.get_node("Health") as ProgressBar
		var preview := Dictionary(pet.call("get_damage_preview_snapshot"))
		assert(bool(preview.get("active", false)))
		assert(bool(preview.get("pinned", false)))
		assert(bool(preview.get("uses_badge", false)))
		assert(bool(preview.get("embedded_in_health_bar", false)))
		assert(not bool(preview.get("lethal", true)))
		assert(int(preview.get("displayed_damage", -1)) == 15)
		assert(int(preview.get("displayed_hp", -1)) == 20)
		assert(badge.visible)
		assert(value.text == "")
		assert(value.self_modulate == Color.WHITE)
		assert(stats_root.visible and health.visible)
		assert(badge.get_parent() == health)
		assert(is_equal_approx(badge.position.x, health.size.x * (7.0 / 22.0)))
		assert(is_zero_approx(badge.position.y))
		assert(is_equal_approx(badge.size.y, health.size.y))
		assert(is_equal_approx(badge.size.x, health.size.x * (15.0 / 22.0)))
		assert(badge.scale == Vector2.ONE)
		assert(is_equal_approx(separator.size.x * badge.scale.x, 2.0))
		var fill := health.get_theme_stylebox("fill") as StyleBoxFlat
		assert(fill != null)
		if side == "enemy":
			assert(fill.bg_color.r > fill.bg_color.g and fill.bg_color.g > 0.45)
		else:
			assert(fill.bg_color.g > fill.bg_color.r)
		await create_timer(1.4).timeout
		preview = Dictionary(pet.call("get_damage_preview_snapshot"))
		assert(String(preview.get("state", "")) == "visible")
		assert(is_zero_approx(float(preview.get("seconds_to_switch", -1.0))))
		assert(badge.visible and badge.modulate.a > 0.99)
		assert(stats_root.visible)
		assert(is_equal_approx(value.modulate.a, 1.0))
		pet.call("stop_damage_preview")
		pet.call("start_damage_preview", 20, 0, -1, 20, 0, 0, 20)
		preview = Dictionary(pet.call("get_damage_preview_snapshot"))
		assert(bool(preview.get("lethal", false)))
		assert(bool(preview.get("lethal_flash_active", false)))
		await create_timer(0.12).timeout
		assert(value.modulate.a < 0.95)
		pet.call("stop_damage_preview")
		assert(not badge.visible)
		assert(value.text == "")
		pet.queue_free()
	print("INCOMING_DAMAGE_BAR_SMOKE_PASS")
	quit(0)
