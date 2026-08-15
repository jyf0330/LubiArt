extends SceneTree

const DrawerScene := preload("res://art/prefabs/battle/enemy_info/enemy_info_drawer.tscn")
const MockAssetProvider := preload("res://session/mock_asset_provider.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var drawer := DrawerScene.instantiate() as Control
	root.add_child(drawer)
	await process_frame
	drawer.call("configure", MockAssetProvider.new())
	drawer.call("render_snapshot", _snapshot(Vector2i(1, 1)))
	await process_frame
	if not _assert_card(drawer, 100, 40, 0, "battle start"):
		return
	drawer.call("render_snapshot", _snapshot(Vector2i(2, 1)))
	await process_frame
	if not _assert_card(drawer, 100, 40, 0, "moved out of range"):
		return
	drawer.call("render_snapshot", _snapshot(Vector2i(3, 1)))
	await process_frame
	if not _assert_card(drawer, 72, 10, 1, "moved into range"):
		return
	print("ENEMY_INFO_PROJECTION_PASS")
	quit(0)


func _snapshot(actor_grid: Vector2i) -> Dictionary:
	return {
		"phase": "battle",
		"action_preview_by_unit": {
			"pal_001": {
				"origin": {"x": 1, "y": 1},
				"cells": [{"x": 2, "y": 1}],
			}
		},
		"board": {"cells": [
			{
				"unitId": "pal_001",
				"pet_id": "pal_001",
				"side": "player",
				"name": "我方精灵",
				"x": actor_grid.x,
				"y": actor_grid.y,
			},
			{
				"unitId": "pal_002",
				"pet_id": "pal_002",
				"side": "enemy",
				"name": "敌方精灵",
				"x": 4,
				"y": 1,
				"hp": 100,
				"max_hp": 100,
				"shield": 40,
				"max_shield": 40,
				"previews": [{
					"actorId": "pal_001",
					"hitEnemy": true,
					"preview_type": "enemy",
					"predictedHpFrom": 100,
					"predictedHpTo": 72,
					"predictedShieldFrom": 40,
					"predictedShieldTo": 10,
				}],
			},
		]},
	}


func _assert_card(drawer: Control, hp: int, shield: int, attackers: int, label: String) -> bool:
	var card := drawer.get_node("CardList/Card1") as Control
	var health_fill := card.get_node("HealthBar/Fill") as TextureProgressBar
	var shield_fill := card.get_node("ShieldBar/Fill") as TextureProgressBar
	var visible_attackers := 0
	for index in range(1, 5):
		if (card.get_node("Attackers/AttackerPortrait%d" % index) as TextureRect).visible:
			visible_attackers += 1
	if int(health_fill.value) != hp or int(shield_fill.value) != shield \
			or visible_attackers != attackers:
		push_error("%s mismatch: hp=%d shield=%d attackers=%d" % [
			label,
			int(health_fill.value),
			int(shield_fill.value),
			visible_attackers,
		])
		quit(1)
		return false
	return true
