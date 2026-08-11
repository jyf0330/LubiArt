extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	for _frame in range(4):
		await process_frame
	var session := MockSession.new({"start_phase": "battle"})
	battle.call("render_snapshot", Dictionary(session.call("current_snapshot")))
	for _frame in range(4):
		await process_frame
	var hud := battle.get_node("Hud") as Control
	var button := hud.get_node("BattleActionPanel/Margin/Content/HealthBarTierButton") as Button
	var expected := ["silver", "gold", "diamond", "bronze"]
	for tier in expected:
		button.pressed.emit()
		await process_frame
		assert(String(hud.call("debug_health_bar_tier")) == tier)
		for unit in battle.get_node("Board/UnitHost").get_children():
			if unit is Control and unit.visible and unit.has_method("get_health_bar_tier"):
				assert(String(unit.call("get_health_bar_tier")) == tier)
	print("HEALTH_BAR_TIER_DEBUG_SMOKE_PASS")
	quit(0)
