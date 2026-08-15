extends SceneTree


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var battle_packed := load("res://art/scenes/battle/battle_art_scene.tscn") as PackedScene
	if battle_packed == null:
		_fail("battle scene did not load")
		return
	var battle := battle_packed.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame
	if battle.get_node_or_null("EnemyInfoDebugButton") != null \
			or battle.get_node_or_null("EnemyInfoDebugOverlay") != null:
		_fail("standalone enemy debug controls must not be routed into the formal battle scene")
		return
	battle.queue_free()
	await process_frame

	var debug_packed := load(
		"res://art/scenes/enemy_info_drawer_debug/enemy_info_drawer_debug_scene.tscn"
	) as PackedScene
	if debug_packed == null:
		_fail("standalone enemy info debug scene did not load")
		return
	var debug_scene := debug_packed.instantiate() as Control
	root.add_child(debug_scene)
	await process_frame
	var card := debug_scene.get_node("PreviewArea/AttackedEnemyInfoCard") as Control
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
		_fail("standalone debug scene must start with an empty attacker group")
		return
	print("BATTLE_ENEMY_INFO_DEBUG_PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
