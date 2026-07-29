extends SceneTree

const MainScene := preload("res://art/scenes/three_choice/three_choice_scene.tscn")
const EXPANDED_CAPTURE := "res://output/battle_direction_drawer_expanded.png"
const COLLAPSED_CAPTURE := "res://output/battle_direction_drawer_collapsed.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_instance := MainScene.instantiate()
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	await create_timer(0.35).timeout

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	var drawer := battle_view.get_node_or_null("Board/AttackDirectionDrawer") as Control if battle_view != null else null
	var rows := drawer.get_node_or_null("Rows") as Control if drawer != null else null
	var collapse_button := drawer.get_node_or_null("CollapseButton") as TextureButton if drawer != null else null
	if drawer == null or rows == null or collapse_button == null:
		_fail("attack direction drawer is unavailable")
		return
	var display_directions := Array(drawer.call("debug_display_directions"))
	if display_directions.size() != 4:
		_fail("expected four player-pet direction rows, got %d" % display_directions.size())
		return
	for row_value in display_directions:
		if Array(Dictionary(row_value).get("directions", [])).size() != 3:
			_fail("each player-pet row must contain exactly three attack directions")
			return
	if not _save_capture(EXPANDED_CAPTURE):
		return

	collapse_button.pressed.emit()
	await create_timer(0.25).timeout
	if rows.visible or bool(drawer.call("is_expanded")) or collapse_button.position != Vector2(95.0, 0.0):
		_fail("drawer did not collapse to its locked tab position")
		return
	if not _save_capture(COLLAPSED_CAPTURE):
		return

	print("VISIBLE_DIRECTION_DRAWER_PASS rows=4 slots=3 expanded=%s collapsed=%s" % [
		ProjectSettings.globalize_path(EXPANDED_CAPTURE),
		ProjectSettings.globalize_path(COLLAPSED_CAPTURE),
	])
	quit(0)


func _save_capture(path: String) -> bool:
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("res://output"))
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_fail("could not save visible capture %s (error %d)" % [path, error])
		return false
	return true


func _fail(message: String) -> void:
	push_error("VISIBLE_DIRECTION_DRAWER_FAIL: %s" % message)
	quit(1)
