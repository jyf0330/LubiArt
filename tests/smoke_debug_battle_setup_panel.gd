extends SceneTree

const PreviewScene := preload("res://art/scenes/debug/debug_battle_setup_panel_preview.tscn")

var failed := false
var requested := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var preview := PreviewScene.instantiate() as Control
	root.add_child(preview)
	await process_frame
	var panel := preview.get_node("DebugBattleSetupPanel") as Control
	_expect(panel != null, "preview owns the authored setup panel")
	if panel != null:
		_expect(int(panel.call("catalog_count")) == 8, "Mock preview loads eight presentation records")
		_expect(Array(panel.call("selected_player_pet_ids")) == ["pal_002", "pal_011", "pal_028", "pal_030"], "recommended player ids fill four authored selectors")
		_expect(Array(panel.call("selected_enemy_pet_ids")) == ["pal_001", "pal_042", "pal_006", "pal_003"], "recommended enemy ids fill four authored selectors")
		panel.connect("start_requested", func(seed: String, player_ids: Array, enemy_ids: Array):
			requested = seed == "ysbzs-debug-first-battle-v1" and player_ids.size() == 4 and enemy_ids.size() == 4
		)
		panel.get_node("PanelMargin/Panel/VBox/Actions/StartButton").emit_signal("pressed")
		_expect(requested, "authored start button emits only seed and eight pet ids")
		panel.call("enter_battle_mode")
		_expect(panel.get_node("ReopenButton").visible and not panel.get_node("PanelMargin").visible, "battle mode keeps one authored reconfigure entry without covering battle")
		panel.call("show_configuration")
		_expect(not panel.get_node("ReopenButton").visible and panel.get_node("PanelMargin").visible, "reconfigure restores the authored eight-pet panel")
		_expect(panel.get_node("PanelMargin/Panel/VBox/Teams/PlayerTeam/PlayerSlots").get_child_count() == 4, "player selector geometry remains authored in Scene")
		_expect(panel.get_node("PanelMargin/Panel/VBox/Teams/EnemyTeam/EnemySlots").get_child_count() == 4, "enemy selector geometry remains authored in Scene")
	preview.queue_free()
	await process_frame
	if failed:
		quit(1)
		return
	print("SMOKE_DEBUG_BATTLE_SETUP_PANEL_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
