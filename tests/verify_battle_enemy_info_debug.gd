extends SceneTree


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://art/scenes/battle/battle_art_scene.tscn") as PackedScene
	if packed == null:
		_fail("battle scene did not load")
		return
	var battle := packed.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame
	var button := battle.get_node_or_null("EnemyInfoDebugButton") as Button
	var overlay := battle.get_node_or_null("EnemyInfoDebugOverlay") as Control
	if button == null or overlay == null:
		_fail("debug button or overlay missing")
		return
	if overlay.visible:
		_fail("debug overlay must start hidden")
		return
	button.emit_signal("pressed")
	await process_frame
	if not overlay.visible or button.text != "关闭敌人信息调试":
		_fail("button did not open debug overlay")
		return
	var card := overlay.get_node("PreviewArea/AttackedEnemyInfoCard") as Control
	var hp := card.get_node("HealthBar/Fill") as TextureProgressBar
	var shield := card.get_node("ShieldBar/Fill") as TextureProgressBar
	var visible_attackers := 0
	for index in range(1, 5):
		if (card.get_node("Attackers/AttackerPortrait%d" % index) as TextureRect).visible:
			visible_attackers += 1
	if int(hp.value) != int(hp.max_value) or int(shield.value) != int(shield.max_value):
		_fail("debug overlay must start at full HP and shield")
		return
	if visible_attackers != 0:
		_fail("debug overlay must start with an empty attacker group")
		return
	button.emit_signal("pressed")
	await process_frame
	if overlay.visible or button.text != "打开敌人信息调试":
		_fail("button did not close debug overlay")
		return
	print("BATTLE_ENEMY_INFO_DEBUG_PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
