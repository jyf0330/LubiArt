extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var session := MockSession.new({"start_phase": "battle"})
	var snapshot := Dictionary(session.call("current_snapshot"))
	assert(String(snapshot.get("selected_unit_id", snapshot.get("selectedUnitId", ""))) == "")
	var previews := Dictionary(snapshot.get(
		"placement_damage_by_unit",
		snapshot.get("placementDamageByUnit", {})
	))
	var friendly_ids := _friendly_unit_ids(snapshot)
	assert(not friendly_ids.is_empty())
	for unit_id in friendly_ids:
		assert(previews.has(unit_id))

	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await _settle(4)
	battle.call("render_snapshot", snapshot)
	await _settle(6)
	var board := battle.get_node("Board") as Control
	for unit_id in friendly_ids:
		var unit := board.call("_rendered_unit_node", unit_id) as Control
		assert(unit != null)
		var preview := Dictionary(unit.call("get_damage_preview_snapshot"))
		assert(bool(preview.get("active", false)))
		assert(bool(preview.get("pinned", false)))

	var detail_response := Dictionary(session.call("submit_command", {
		"type": "GET_CELL_DETAIL",
		"x": 1,
		"y": 4,
	}))
	assert(bool(detail_response.get("accepted", false)))
	var after_detail := Dictionary(session.call("current_snapshot"))
	var after_detail_previews := Dictionary(after_detail.get(
		"placement_damage_by_unit",
		after_detail.get("placementDamageByUnit", {})
	))
	for unit_id in friendly_ids:
		assert(after_detail_previews.has(unit_id))

	var capture_path := OS.get_environment("INITIAL_DAMAGE_PREVIEW_CAPTURE").strip_edges()
	if capture_path != "":
		await RenderingServer.frame_post_draw
		var capture_error := root.get_texture().get_image().save_png(capture_path)
		assert(capture_error == OK)

	battle.queue_free()
	await process_frame
	quit(0)


func _friendly_unit_ids(snapshot: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		var cell := Dictionary(value)
		var side := String(cell.get("side", cell.get("unitSide", ""))).to_lower()
		if side not in ["player", "ally", "hero_leader", "player_leader"]:
			continue
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		if unit_id != "":
			result.append(unit_id)
	return result


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame
