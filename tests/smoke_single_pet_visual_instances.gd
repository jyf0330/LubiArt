extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
	await create_timer(1.0).timeout
	var counts := {}
	var summaries := []
	for node in _all_descendants(main):
		if not node.has_method("get_unit_id"):
			continue
		var unit_id := String(node.call("get_unit_id"))
		if unit_id == "":
			continue
		counts[unit_id] = int(counts.get(unit_id, 0)) + 1
		var sprite := node.get_node_or_null("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
		summaries.append({
			"name": String(node.name),
			"unit_id": unit_id,
			"parent": String(node.get_parent().name) if node.get_parent() != null else "",
			"trace_ghost": bool(node.get_meta("trace_ghost", false)),
			"position": node.position if node is Control else Vector2.ZERO,
			"texture": sprite.texture.resource_path if sprite != null and sprite.texture != null else "",
		})
	print(JSON.stringify(summaries, "  "))
	for unit_id in counts:
		if int(counts[unit_id]) != 1:
			push_error("SINGLE_PET_VISUAL_INSTANCE_FAIL %s count=%d" % [unit_id, counts[unit_id]])
			quit(1)
			return
	var capture_path := OS.get_environment("SINGLE_PET_CAPTURE_PATH").strip_edges()
	if capture_path != "":
		await RenderingServer.frame_post_draw
		var capture_error := root.get_texture().get_image().save_png(capture_path)
		if capture_error != OK:
			push_error("SINGLE_PET_VISUAL_INSTANCE_FAIL capture=%s" % error_string(capture_error))
			quit(1)
			return
	print("SINGLE_PET_VISUAL_INSTANCE_PASS units=%d" % counts.size())
	quit(0)


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result
