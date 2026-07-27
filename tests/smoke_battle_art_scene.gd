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
	var runtime_view := art_scene.call("get_runtime_view") as Control
	var round_feedback := art_scene.get_node_or_null(
		"PrefabCatalog/RuntimeEffects/RoundFeedback"
	) as TextureRect
	var passed: bool = (
		runtime_view != null
		and runtime_view.get_parent() == art_scene.get_node_or_null("Runtime")
		and round_feedback != null
		and round_feedback.texture is AtlasTexture
		and round_feedback.get_script() != null
		and round_feedback.get_node_or_null("Banner") == null
		and round_feedback.get_node_or_null("Title") is Label
		and round_feedback.get_node_or_null("Subtitle") is Label
		and not round_feedback.get_parent().visible
	)
	if not passed:
		push_error("MOCK_BATTLE_ART_SCENE_FAIL: hierarchy or RoundFeedback contract mismatch")
	art_scene.queue_free()
	await process_frame
	print("MOCK_BATTLE_ART_SCENE_%s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
