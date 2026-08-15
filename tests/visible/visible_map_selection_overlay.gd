extends SceneTree

const OUTPUT_DIR := "C:/Users/GenomaxDEF/.codex/visualizations/2026/08/12/019ff4e7-8e5f-7573-b96c-f02bc2079764/map_selection_checks"


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var packed := load("res://art/scenes/battle/battle_art_scene.tscn") as PackedScene
	var battle := packed.instantiate() as Control
	root.add_child(battle)
	await _settle()
	await _capture("01_default_mountain")

	var open_button := battle.get_node(
		"Hud/BattleActionPanel/Margin/Content/MapDebugButton"
	) as Button
	var overlay := battle.get_node("OverlayHost/MapSelectionOverlay") as Control
	open_button.pressed.emit()
	await _settle()
	await _capture("02_opened_11_maps")

	var spring_button := overlay.get_node(
		"Panel/Margin/Content/MapGrid/ForestSpring"
	) as TextureButton
	spring_button.pressed.emit()
	await _settle()
	await _capture("03_forest_spring_selected")

	open_button.pressed.emit()
	await _settle()
	var autumn_button := overlay.get_node(
		"Panel/Margin/Content/MapGrid/ForestAutumn"
	) as TextureButton
	autumn_button.pressed.emit()
	await _settle()
	await _capture("04_forest_autumn_selected")

	open_button.pressed.emit()
	await _settle()
	var mountain_button := overlay.get_node(
		"Panel/Margin/Content/MapGrid/NewMountain"
	) as TextureButton
	mountain_button.pressed.emit()
	await _settle()
	await _capture("05_mountain_selected_again")

	print("VISIBLE_MAP_SELECTION_CAPTURE_PASS")
	quit(0)


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _capture(name: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png("%s/%s.png" % [OUTPUT_DIR, name])
	assert(error == OK)
	await process_frame
