extends SceneTree

const ART_SCENE_PATH := "res://art/scenes/battle/battle_art_scene.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(ART_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("MOCK_BATTLE_ART_SCENE_FAIL: scene did not load")
		quit(1)
		return
	var art_scene := packed.instantiate() as Control
	root.add_child(art_scene)
	await process_frame
	await process_frame
	var board := art_scene.get_node_or_null("Board") as Control
	var board_grid := art_scene.get_node_or_null("Board/BoardGrid") as Control
	var top_info_bar := art_scene.get_node_or_null("TopInfoBar") as Control
	var cell_detail := art_scene.get_node_or_null("CellDetail") as Control
	var passed: bool = (
		board != null
		and board_grid != null
		and board_grid.get_child_count() == 64
		and top_info_bar != null
		and cell_detail != null
		and art_scene.get_node_or_null("Board/BattleVfxPlayer") != null
		and art_scene.get_node_or_null("Board/BattleActionPanel") != null
		and art_scene.get_node_or_null("Runtime") == null
		and art_scene.get_node_or_null("PrefabCatalog") == null
	)
	if not passed:
		push_error("MOCK_BATTLE_ART_SCENE_FAIL: two-scene/four-prefab hierarchy mismatch")
	art_scene.queue_free()
	await process_frame
	print("MOCK_BATTLE_ART_SCENE_%s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
