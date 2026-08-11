extends SceneTree

const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")
const MockAssets := preload("res://session/mock_asset_provider.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(480.0, 240.0)
	root.add_child(host)
	var assets := MockAssets.new()
	var ally := _make_unit(
		host, Vector2(20.0, 20.0), "ally", 20, 5, 20, "青铜", "pal_002", assets
	)
	var enemy := _make_unit(
		host, Vector2(220.0, 20.0), "enemy", 8, 6, 20, "黄金", "pal_006", assets
	)
	await process_frame

	var ally_bar := _health_bar(ally)
	var enemy_bar := _health_bar(enemy)
	var ally_shield := _shield_bar(ally)
	var enemy_shield := _shield_bar(enemy)
	assert(ally_bar.visible)
	assert(enemy_bar.visible)
	assert(is_equal_approx(ally_bar.size.x * ally_bar.scale.x, 96.0))
	assert(is_equal_approx(ally_bar.size.y * ally_bar.scale.y, 11.0))
	assert(is_equal_approx(ally_bar.value, 20.0))
	assert(is_equal_approx(ally_bar.max_value, 25.0))
	assert(is_equal_approx(enemy_bar.value, 8.0))
	assert(is_equal_approx(enemy_bar.max_value, 26.0))
	assert(ally_shield.visible)
	assert(enemy_shield.visible)
	assert(not _shield_label(ally).visible)
	assert(not _shield_label(enemy).visible)
	assert(is_equal_approx(ally_shield.value, 1.0))
	assert(is_equal_approx(enemy_shield.value, 1.0))
	assert(is_equal_approx(ally_shield.max_value, 1.0))
	assert(is_equal_approx(ally_shield.position.x - ally_bar.position.x, 76.8))
	assert(is_equal_approx(ally_shield.position.y, ally_bar.position.y))
	assert(is_equal_approx(ally_shield.size.x, 19.2))
	assert(is_equal_approx(
		ally_shield.position.x + ally_shield.size.x,
		ally_bar.position.x + ally_bar.size.x
	))
	var ally_fill := ally_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var enemy_fill := enemy_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var ally_shield_fill := ally_shield.get_theme_stylebox("fill") as StyleBoxFlat
	var enemy_shield_fill := enemy_shield.get_theme_stylebox("fill") as StyleBoxFlat
	assert(ally_fill != null and ally_fill.bg_color.g > ally_fill.bg_color.r)
	assert(enemy_fill != null and enemy_fill.bg_color.r > enemy_fill.bg_color.g)
	assert(enemy_fill.bg_color.g > 0.45)
	assert(ally_shield_fill != null and enemy_shield_fill != null)
	assert(ally_shield_fill.bg_color.is_equal_approx(enemy_shield_fill.bg_color))
	assert(absf(ally_shield_fill.bg_color.r - ally_shield_fill.bg_color.g) < 0.04)
	var ally_sprite_top := float(ally.call("get_battle_sprite_actual_top_y"))
	var enemy_sprite_top := float(enemy.call("get_battle_sprite_actual_top_y"))
	assert(not is_equal_approx(ally_sprite_top, enemy_sprite_top))
	_assert_bar_above_sprite(ally, ally_bar)
	_assert_bar_above_sprite(enemy, enemy_bar)
	assert(String(ally.call("get_health_bar_tier")) == "bronze")
	assert(String(enemy.call("get_health_bar_tier")) == "gold")
	var tier_regions := {}
	for tier in ["bronze", "silver", "gold", "diamond"]:
		ally.call("set_health_bar_tier", tier)
		assert(is_equal_approx(ally_bar.size.x * ally_bar.scale.x, 96.0))
		assert(is_equal_approx(ally_bar.size.y * ally_bar.scale.y, 11.0))
		var frame := ally_bar.get_node("Icon") as TextureRect
		assert(frame.visible)
		assert(frame.texture is AtlasTexture)
		assert(frame.position.is_equal_approx(Vector2(-72.0, -30.0)))
		assert(frame.size.is_equal_approx(Vector2(192.0, 72.0)))
		var slot_from_frame := Rect2(
			frame.position + Vector2(24.0, 10.0) * 3.0,
			Vector2(32.0, 3.0) * 3.0
		)
		assert(slot_from_frame.position.is_equal_approx(Vector2.ZERO))
		assert(is_equal_approx(slot_from_frame.size.x, ally_bar.size.x))
		assert(is_equal_approx(slot_from_frame.size.y + 2.0, ally_bar.size.y))
		tier_regions[tier] = (frame.texture as AtlasTexture).region
	assert(tier_regions.values().duplicate().size() == 4)
	assert(tier_regions["bronze"] != tier_regions["silver"])
	assert(tier_regions["silver"] != tier_regions["gold"])
	assert(tier_regions["gold"] != tier_regions["diamond"])

	ally.call("update_hp", 5)
	await process_frame
	assert(is_equal_approx(ally_bar.value, 5.0))
	assert(is_equal_approx(ally_shield.position.x - ally_bar.position.x, 19.2))
	assert(is_equal_approx(ally_shield.size.x, 19.2))
	assert(is_equal_approx(ally_bar.max_value, 25.0))
	assert((_health_label(ally) as Label).text == "HP:5")
	ally.call("update_shield", 40)
	await process_frame
	assert(is_equal_approx(ally_bar.max_value, 60.0))
	assert(is_equal_approx(ally_shield.size.x, 64.0))
	assert(not _shield_label(ally).visible)

	print("PET_HEALTH_BAR_SMOKE_PASS")
	quit(0)


func _make_unit(
	host: Control,
	unit_position: Vector2,
	unit_side: String,
	hp: int,
	shield: int,
	max_hp: int,
	rank: String,
	pet_id: String,
	assets: RefCounted
) -> Control:
	var unit := BattleUnitScene.instantiate() as Control
	unit.custom_minimum_size = Vector2.ZERO
	unit.position = unit_position
	unit.size = Vector2(180.0, 180.0)
	host.add_child(unit)
	unit.call("set_unit_data", {
		"unitId": "%s_health_bar_test" % unit_side,
		"hp": hp,
		"shield": shield,
		"max_hp": max_hp,
		"rank": rank,
		"pet_id": pet_id,
	}, unit_side, assets)
	return unit


func _health_bar(unit: Control) -> ProgressBar:
	return unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health") as ProgressBar


func _health_label(unit: Control) -> Label:
	return unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/Value_Text") as Label


func _shield_bar(unit: Control) -> ProgressBar:
	return unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield") as ProgressBar


func _shield_label(unit: Control) -> Label:
	return unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield/Value_Text") as Label


func _assert_bar_above_sprite(unit: Control, health: ProgressBar) -> void:
	var sprite_top := float(unit.call("get_battle_sprite_actual_top_y"))
	var health_bottom := health.position.y + health.size.y * health.scale.y
	assert(is_equal_approx(sprite_top - health_bottom, 14.0))
