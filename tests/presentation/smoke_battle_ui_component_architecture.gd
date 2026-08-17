extends SceneTree

const BattlePetViewModelScript := preload("res://core_ui/scripts/battle/presenters/battle_pet_view_model.gd")
const ValueBarScene := preload("res://art/prefabs/shared/ui_value_bar.tscn")
const AttackGridScene := preload("res://art/prefabs/battle/battle_attack_shape_grid.tscn")
const StatusBarScene := preload("res://art/prefabs/pet/battle_unit_status_bar.tscn")
const InfoCardScene := preload("res://art/prefabs/battle/battle_compact_info_card.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := {
		"unitId": "enemy_architecture",
		"unitName": "架构测试宠物",
		"side": "monster",
		"currentHp": 18,
		"maxHp": 30,
		"armor": 4,
		"atk": 7,
		"def": 3,
		"availableAp": 2,
		"maxAp": 4,
		"threat": {"totalDamage": 12},
		"element_types": ["水", "风"],
		"attackShape": {"offsets": [{"dr": -1, "dc": 0}, {"dr": 0, "dc": 1}]},
	}
	var untouched := source.duplicate(true)
	var model := BattlePetViewModelScript.from_record(source)
	_expect(source == untouched, "view-model projection must not mutate public input")
	_expect(String(model.id) == "enemy_architecture", "view model resolves unit aliases")
	_expect(String(model.name) == "架构测试宠物", "view model resolves display-name aliases")
	_expect(bool(model.is_enemy), "view model normalizes monster to enemy presentation")
	_expect(int(model.hp) == 18 and int(model.max_hp) == 30, "view model normalizes health")
	_expect(int(model.ap) == 2 and int(model.max_ap) == 4, "view model normalizes action points")
	_expect(int(model.damage_cap) == 0, "view model safely ignores structured threat data")
	_expect(String(model.element) == "水 / 风", "view model preserves multi-element presentation")

	var value_bar := ValueBarScene.instantiate() as UiValueBar
	root.add_child(value_bar)
	await process_frame
	value_bar.size = Vector2(200, 20)
	value_bar.present(18, 30)
	value_bar.show_loss_preview(9)
	var value_snapshot := value_bar.get_value_snapshot()
	_expect(int(value_snapshot.get("current", -1)) == 18 and int(value_snapshot.get("maximum", -1)) == 30, "value bar renders explicit input")
	_expect(bool(value_snapshot.get("preview_visible", false)), "value bar exposes damage preview without battle dependencies")

	var attack_grid := AttackGridScene.instantiate() as BattleAttackShapeGrid
	root.add_child(attack_grid)
	await process_frame
	attack_grid.present(Dictionary(model.attack_shape))
	_expect(attack_grid.get_cell_count() == 21, "attack grid keeps the authored 7x3 contract")
	_expect(attack_grid.get_target_cell_indices() == [3, 11], "attack grid projects relative offsets")

	var status_bar := StatusBarScene.instantiate() as BattleUnitStatusBar
	root.add_child(status_bar)
	await process_frame
	status_bar.present(source, "monster")
	var status_snapshot := status_bar.get_view_snapshot()
	_expect(bool(status_snapshot.is_enemy), "status bar consumes the shared visual model")
	_expect(status_bar.get_node_or_null("Health") is UiValueBar, "unit status composes the reusable value bar")

	var info_card := InfoCardScene.instantiate() as BattleCompactInfoCard
	root.add_child(info_card)
	await process_frame
	var info_snapshot := info_card.set_info(source)
	_expect(String(info_snapshot.name) == "架构测试宠物", "info card consumes the shared visual model")
	_expect(info_card.get_attack_shape_cell_count() == 21, "info card delegates attack-grid rendering")
	_expect(info_card.get_node_or_null("Margin/Column/Health") is UiValueBar, "info card is scene-composed from reusable value bars")
	_expect(info_card.get_node_or_null("Margin/Column/CombatPanel/CombatMargin/CombatRow/AttackShapeGrid") is BattleAttackShapeGrid, "info card is scene-composed from the attack-grid component")

	value_bar.queue_free()
	attack_grid.queue_free()
	status_bar.queue_free()
	info_card.queue_free()
	print("SMOKE_BATTLE_UI_COMPONENT_ARCHITECTURE_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
