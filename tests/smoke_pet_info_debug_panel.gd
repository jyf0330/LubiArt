extends SceneTree

const PET_DETAIL_SCENE := preload("res://art/prefabs/pet/pet_detail.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var detail := PET_DETAIL_SCENE.instantiate() as Control
	root.add_child(detail)
	await process_frame
	detail.call("show_detail", {"name": "初始宠物", "quality": "水晶", "element": "水"})
	detail.call("set_debug_enabled", true)
	assert(bool(detail.call("is_debug_enabled")))
	assert(int(detail.call("debug_record_count")) >= 2)
	var before := int(detail.call("debug_current_index"))
	var next_result := Dictionary(detail.call("debug_next_pet"))
	assert(bool(next_result.get("ok", false)))
	assert(int(detail.call("debug_current_index")) != before)
	assert(String(Dictionary(next_result.get("normalized", {})).get("name", "")) != "")
	assert(int(next_result.get("attack_cell_count", 0)) == 21)
	assert(String(next_result.get("component_source", "")) == "res://art/prefabs/pet/sprite_info_card.tscn")
	var previous_result := Dictionary(detail.call("debug_previous_pet"))
	assert(bool(previous_result.get("ok", false)))
	assert(int(detail.call("debug_current_index")) == before)
	print("PET_INFO_DEBUG_PANEL_SMOKE_PASS")
	quit(0)
