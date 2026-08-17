extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_battle_hides_persistent_hud()
	await _verify_battle_outcome_labels()
	if failed:
		quit(1)
		return
	print("SMOKE_RECORDING_VISUAL_CLEANUP_OK")
	quit(0)


func _verify_battle_hides_persistent_hud() -> void:
	var scene := GameScene.instantiate() as Control
	root.add_child(scene)
	await create_timer(1.0).timeout
	var middle := scene
	var view := middle.call("get_three_choice_view") as Control
	var bags_panel := scene.find_child("Bags", true, false) as Control
	var party_panel := scene.find_child("Party", true, false) as Control
	_expect(middle != null, "artist middle controller exists")
	_expect(bags_panel != null and party_panel != null, "persistent Bags and Party panels exist")
	if middle == null or bags_panel == null or party_panel == null:
		scene.queue_free()
		await process_frame
		return
	_expect(bags_panel.visible and party_panel.visible, "route view starts with persistent HUD visible")
	middle.state.dispatch({"type": "START_BATTLE"})
	middle.call("render_current_view")
	await create_timer(1.0).timeout
	var battle_view := scene.find_child("BattleArtScene", true, false) as Control
	_expect(battle_view != null and battle_view.visible, "battle view becomes visible")
	_expect(not bags_panel.visible and not party_panel.visible, "battle view hides persistent Bags and Party artwork")
	view.call("_show_view", &"three_option")
	await process_frame
	_expect(bags_panel.visible and party_panel.visible, "persistent HUD returns after leaving battle view")
	scene.queue_free()
	await process_frame


func _verify_battle_outcome_labels() -> void:
	var scene := GameScene.instantiate() as Control
	root.add_child(scene)
	await process_frame
	var panel := scene.find_child("BazaarInfoPanel", true, false) as Control
	var base_snapshot := {
		"phase": "battle_end",
		"day": 1,
		"node_index": 3,
		"coins": 16,
		"roster": [],
	}
	var draw_snapshot := base_snapshot.duplicate(true)
	draw_snapshot["battle_result"] = {"code": "DRAW", "draw": true, "win": false, "grade": "DRAW", "gold_from": 16, "gold_to": 16, "battle_round": 12}
	panel.call("render_snapshot", draw_snapshot, &"three_option")
	var draw_text := String(panel.call("get_summary_text"))
	_expect(draw_text.contains("平局 · 评级DRAW"), "DRAW settlement is labeled as a draw")
	_expect(not draw_text.contains("失败 · 评级DRAW"), "DRAW settlement is not labeled as a failure")
	var win_snapshot := base_snapshot.duplicate(true)
	win_snapshot["battle_result"] = {"code": "WIN", "win": true, "grade": "A", "gold_from": 16, "gold_to": 20, "battle_round": 8}
	panel.call("render_snapshot", win_snapshot, &"three_option")
	_expect(String(panel.call("get_summary_text")).contains("胜利 · 评级A"), "win settlement keeps victory label")
	var lose_snapshot := base_snapshot.duplicate(true)
	lose_snapshot["battle_result"] = {"code": "LOSE", "win": false, "grade": "D", "gold_from": 16, "gold_to": 16, "battle_round": 6}
	panel.call("render_snapshot", lose_snapshot, &"three_option")
	_expect(String(panel.call("get_summary_text")).contains("失败 · 评级D"), "loss settlement keeps failure label")
	scene.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_RECORDING_VISUAL_CLEANUP_FAIL: %s" % message)
