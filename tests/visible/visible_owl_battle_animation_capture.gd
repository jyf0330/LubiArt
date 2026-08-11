extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const OUTPUT_FOLDER := "visible_owl_battle_animation"
const OWL_UNIT_ID := "shop_004"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame
	var snapshot := Dictionary(MockSession.new({"start_phase": "battle"}).call("current_snapshot"))
	battle.call("render_snapshot", snapshot)
	await process_frame
	await process_frame

	var owl := _find_unit(battle, OWL_UNIT_ID)
	if owl == null:
		_fail("could not find %s in the real battle snapshot" % OWL_UNIT_ID)
		return
	var animation := owl.get_node_or_null("CompleteBattleCreaturePrefab/03_AttackActions")
	if animation == null:
		_fail("owl animation owner is missing")
		return
	var initial := Dictionary(animation.call("get_frame_animation_snapshot"))
	if String(initial.get("active_action", "")) != "idle" \
			or int(Dictionary(initial.get("actions", {})).get("idle", 0)) != 16:
		_fail("owl idle animation is not active in the real battle scene: %s" % initial)
		return

	var output_dir := OS.get_environment("TEMP").path_join(OUTPUT_FOLDER)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var sampled_paths: Array[String] = []
	for sample in range(4):
		var state := Dictionary(animation.call("get_frame_animation_snapshot"))
		var sprite := owl.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
		sampled_paths.append(sprite.texture.resource_path if sprite.texture != null else "")
		if not await _capture(output_dir.path_join("battle_%02d.png" % (sample + 1))):
			return
		print("OWL_BATTLE_SAMPLE index=%d frame=%d texture=%s" % [
			sample + 1,
			int(state.get("frame_index", -1)),
			sampled_paths[-1],
		])
		await create_timer(0.32).timeout
	var unique_paths: Dictionary = {}
	for path in sampled_paths:
		unique_paths[path] = true
	if unique_paths.size() < 3:
		_fail("real battle owl did not visibly advance across enough frames: %s" % sampled_paths)
		return
	print("VISIBLE_OWL_BATTLE_ANIMATION_PASS output=%s unique_frames=%d" % [
		output_dir,
		unique_paths.size(),
	])
	quit(0)


func _find_unit(battle: Control, unit_id: String) -> Control:
	var cell_host := battle.get_node_or_null("Board/CellHost")
	if cell_host == null:
		return null
	for cell in cell_host.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var unit := cell.call("get_unit_node") as Control
		if unit != null and unit.has_method("get_unit_id") \
				and String(unit.call("get_unit_id")) == unit_id:
			return unit
	return null


func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var viewport_image := root.get_texture().get_image()
	if viewport_image.save_png(path) != OK:
		_fail("could not save %s" % path)
		return false
	return true


func _fail(message: String) -> void:
	push_error("VISIBLE_OWL_BATTLE_ANIMATION_FAIL: %s" % message)
	quit(1)
