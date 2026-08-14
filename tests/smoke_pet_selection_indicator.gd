extends SceneTree

const PetScene := preload("res://art/prefabs/pet/pet.tscn")
const BattleBoardScript := preload("res://core_ui/scripts/battle/scenes/battle_board.gd")
const MockSession := preload("res://session/mock_game_session.gd")

class SelectionProbe:
	extends Control

	var selected := false

	func set_selected(value: bool) -> void:
		selected = value


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pet := PetScene.instantiate() as Control
	root.add_child(pet)
	pet.custom_minimum_size = Vector2.ZERO
	pet.size = Vector2(140.0, 100.0)
	pet.call("set_unit_data", {
		"unitId": "selection_test_pet",
		"unitName": "Selection Test Pet",
		"hp": 20,
		"shield": 0,
		"atk": 5,
	}, "player", null)
	await process_frame

	var visual := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual") as Control
	var frame := visual.get_node("SelectionFrame") as TextureRect
	var shadow := visual.get_node("Shadow") as TextureRect
	pet.call("set_selected", true)
	assert(frame.visible)
	assert(frame.texture != null)
	assert(frame.z_index <= shadow.z_index)
	assert(frame.get_rect().encloses(shadow.get_rect()))
	assert(frame.get_rect().get_center().distance_to(shadow.get_rect().get_center()) <= 1.0)
	var selection_material := frame.material as ShaderMaterial
	assert(selection_material != null)
	var ring_color: Color = selection_material.get_shader_parameter("ring_color")
	assert(ring_color.r > 0.9 and ring_color.g > 0.6 and ring_color.b < 0.2)
	pet.call("set_selected", false)
	assert(not frame.visible)

	var first := SelectionProbe.new()
	var second := SelectionProbe.new()
	var board := BattleBoardScript.new()
	board.set("_unit_nodes_by_id", {
		"first": first,
		"second": second,
	})
	board.call("_sync_unit_selection", {"selected_unit_id": "second"})
	assert(not first.selected)
	assert(second.selected)
	board.call("_sync_unit_selection", {"selectedUnitId": "first"})
	assert(first.selected)
	assert(not second.selected)
	board.call("_sync_unit_selection", {})
	assert(not first.selected)
	assert(not second.selected)

	var session: RefCounted = MockSession.new({"start_phase": "battle"})
	var snapshot := Dictionary(session.call("current_snapshot"))
	var cells := Array(Dictionary(snapshot.get("board", {})).get("cells", []))
	var player_cell := {}
	var empty_cell := {}
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		var side := String(cell.get("side", cell.get("unitSide", "")))
		if player_cell.is_empty() and unit_id != "" and side in ["player", "hero", "hero_leader"]:
			player_cell = cell
		if empty_cell.is_empty() and unit_id == "" \
				and not _has_visible_elements(Dictionary(cell.get("elements", {}))):
			empty_cell = cell
	assert(not player_cell.is_empty())
	assert(not empty_cell.is_empty())
	var select_response := Dictionary(session.call("submit_command", {
		"type": "SELECT_CELL",
		"x": int(player_cell.get("x", player_cell.get("c", -1))),
		"y": int(player_cell.get("y", player_cell.get("r", -1))),
	}))
	assert(bool(select_response.get("accepted", false)))
	assert(String(Dictionary(session.call("current_snapshot")).get("selected_unit_id", "")) != "")
	var clear_response := Dictionary(session.call("submit_command", {
		"type": "SELECT_CELL",
		"x": int(empty_cell.get("x", empty_cell.get("c", -1))),
		"y": int(empty_cell.get("y", empty_cell.get("r", -1))),
	}))
	assert(bool(clear_response.get("accepted", false)))
	assert(bool(Dictionary(clear_response.get("result", {})).get("cleared", false)))
	assert(String(Dictionary(session.call("current_snapshot")).get("selected_unit_id", "")) == "")

	board.free()
	first.free()
	second.free()
	pet.queue_free()
	await process_frame
	print("PET_SELECTION_INDICATOR_SMOKE_PASS")
	quit(0)


func _has_visible_elements(elements: Dictionary) -> bool:
	for amount in elements.values():
		if int(amount) > 0:
			return true
	return false
