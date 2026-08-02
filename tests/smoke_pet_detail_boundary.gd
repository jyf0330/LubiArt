extends SceneTree

const PET_DETAIL_SCENE := preload("res://art/prefabs/pet/pet_detail.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var detail := PET_DETAIL_SCENE.instantiate() as Control
	root.add_child(detail)
	await process_frame
	assert(detail.get_node_or_null("DebugPanel") == null)
	assert(detail.get_node_or_null("DebugToggleButton") == null)
	assert(not detail.has_method("set_debug_enabled"))
	assert(not detail.has_method("debug_next_pet"))

	detail.call("show_detail", {
		"name": "正式宠物详情",
		"quality": "水晶",
		"element": "水",
		"hp": 24,
		"max_hp": 24,
		"attack": 4,
		"defense": 2,
	})
	await process_frame
	assert(detail.visible)
	assert(String(Dictionary(detail.call("get_detail_snapshot")).get("name", "")) == "正式宠物详情")
	assert(String(detail.call("get_display_text")).contains("正式宠物详情"))
	assert(int(detail.call("get_attack_shape_cell_count")) == 21)

	detail.call("show_context_detail", {"name": "悬停宠物", "element": "火"})
	await process_frame
	assert(bool(detail.call("is_context_detail")))
	assert(not (detail.get_node("Dim") as Control).visible)
	detail.call("close_context_detail")
	assert(not detail.visible)
	print("PET_DETAIL_BOUNDARY_SMOKE_PASS")
	quit(0)
