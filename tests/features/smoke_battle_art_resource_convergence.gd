extends SceneTree

const AssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")

const EXPECTED_ENEMY_PATHS := {
	"enemy_r01_001": "res://art/images/shared/pets/sheets/slices/pet_style_005_earth_slime.png",
	"enemy_r01_002": "res://art/images/shared/pets/sheets/slices/pet_style_014_horned_wing_dragon.png",
	"enemy_r02_003": "res://art/images/shared/pets/sheets/slices/pet_style_057_frost_fox.png",
	"enemy_r03_004": "res://art/images/shared/pets/sheets/slices/pet_style_012_azure_wind_feather.png",
}


func _init() -> void:
	var registry := AssetRegistryScript.new()
	for unit_id in EXPECTED_ENEMY_PATHS:
		var expected_path := String(EXPECTED_ENEMY_PATHS[unit_id])
		_expect(ResourceLoader.exists(expected_path), "%s art resource exists" % unit_id)
		var result := Dictionary(registry.call("texture_for_unit", {
			"id": unit_id,
			"unitId": unit_id,
		}, "enemy"))
		var texture := result.get("texture") as Texture2D
		_expect(texture != null, "%s texture resolves" % unit_id)
		if texture != null:
			_expect(texture.resource_path == expected_path, "%s uses art-project identity" % unit_id)

	for leader_side in ["player", "enemy"]:
		var side := "hero_leader" if leader_side == "player" else "boss"
		var texture := Dictionary(registry.call("texture_for_unit", {}, side)).get("texture") as Texture2D
		_expect(texture != null, "%s hero texture resolves" % leader_side)

	var unit := BattleUnitScene.instantiate() as Control
	root.add_child(unit)
	await process_frame
	unit.call("set_unit_data", {
		"id": "resource_convergence_pet",
		"name": "资源收敛宠物",
		"hp": 24,
		"max_hp": 30,
		"shield": 3,
		"attack": 8,
		"damage_cap": 5,
	}, "player", null)
	var bar := unit.get_node_or_null("CompleteBattleCreaturePrefab/01_UnitVisual/BattleUnitStatusBar") as Control
	_expect(bar != null and bar.visible, "formal battle unit exposes the independent health-bar component")
	_expect(bar.get_node_or_null("Health") is UiValueBar, "battle unit health uses the shared value-bar component")
	var legacy_stats := unit.get_node_or_null("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	_expect(legacy_stats != null and not legacy_stats.visible, "legacy four-label HUD is hidden in battle")
	unit.queue_free()
	print("SMOKE_BATTLE_ART_RESOURCE_CONVERGENCE_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
