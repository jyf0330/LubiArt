extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const EXPANDED_CAPTURE := "res://output/battle_direction_drawer_expanded.png"
const SCROLL_HINT_CAPTURE := "res://output/battle_direction_drawer_scroll_hint.png"
const COLLAPSED_CAPTURE := "res://output/battle_direction_drawer_collapsed.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_instance := MainScene.instantiate()
	main_instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	await create_timer(0.35).timeout

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	var drawer := battle_view.get_node_or_null("Board/AttackDirectionDrawer") as Control if battle_view != null else null
	var rows := drawer.get_node_or_null("Rows") as Control if drawer != null else null
	var first_arrow := drawer.get_node_or_null("Rows/Row1/Arrow1") as TextureRect if drawer != null else null
	var scroll_hint := drawer.get_node_or_null("ScrollHint") as TextureRect if drawer != null else null
	var collapse_button := drawer.get_node_or_null("CollapseButton") as TextureButton if drawer != null else null
	if drawer == null or rows == null or first_arrow == null or scroll_hint == null or collapse_button == null:
		_fail("attack direction drawer is unavailable")
		return
	await _stabilize_battle_view(battle_view)
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

	var hover_position := first_arrow.global_position + first_arrow.size * 0.5
	_disable_pointer_interactions(battle_view)
	drawer.set_process(false)
	first_arrow.mouse_entered.emit()
	for _frame in range(4):
		await process_frame
	await create_timer(0.12).timeout
	if not scroll_hint.visible:
		_fail("scroll hint did not appear while the pointer hovered an arrow")
		return
	var scroll_hint_animation := scroll_hint.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if scroll_hint_animation != null:
		scroll_hint_animation.stop()
	var scroll_hint_highlight := scroll_hint.get_node_or_null("WheelHighlight") as CanvasItem
	if scroll_hint_highlight != null:
		scroll_hint_highlight.modulate.a = 1.0
	scroll_hint.global_position = hover_position + Vector2(18.0, 18.0)
	_freeze_attack_highlights(battle_view)
	await RenderingServer.frame_post_draw
	if not _save_capture(SCROLL_HINT_CAPTURE):
		return

	collapse_button.pressed.emit()
	await create_timer(0.25).timeout
	if rows.visible or bool(drawer.call("is_expanded")) or collapse_button.position != Vector2(95.0, 0.0):
		_fail("drawer did not collapse to its locked tab position")
		return
	await RenderingServer.frame_post_draw
	if not _save_capture(COLLAPSED_CAPTURE):
		return

	print("VISIBLE_DIRECTION_DRAWER_PASS rows=4 slots=3 expanded=%s scroll_hint=%s collapsed=%s" % [
		ProjectSettings.globalize_path(EXPANDED_CAPTURE),
		ProjectSettings.globalize_path(SCROLL_HINT_CAPTURE),
		ProjectSettings.globalize_path(COLLAPSED_CAPTURE),
	])
	quit(0)


func _stabilize_battle_view(battle_view: Control) -> void:
	var vfx_player := battle_view.get_node_or_null("Board/BattleVfxPlayer")
	if vfx_player != null:
		var round_feedback := vfx_player.get_node_or_null("RoundFeedback")
		if round_feedback != null:
			round_feedback.queue_free()
	var board_grid := battle_view.get_node_or_null("Board/BoardGrid")
	if board_grid != null:
		for cell in board_grid.get_children():
			if not cell.has_method("get_unit_node"):
				continue
			var pet := cell.call("get_unit_node") as Control
			if pet == null:
				continue
			var animation := pet.get_node_or_null("CompleteBattleCreaturePrefab/03_AttackActions")
			if animation != null and animation.has_method("reset"):
				animation.call("reset")
	await process_frame
	await RenderingServer.frame_post_draw


func _freeze_attack_highlights(battle_view: Control) -> void:
	var board_grid := battle_view.get_node_or_null("Board/BoardGrid")
	if board_grid == null:
		return
	for cell in board_grid.get_children():
		if cell.has_method("set_attack_highlight_blinking"):
			cell.call("set_attack_highlight_blinking", false)


func _disable_pointer_interactions(battle_view: Control) -> void:
	battle_view.set_process_input(false)
	battle_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for control_value in battle_view.find_children("*", "Control", true, false):
		var control := control_value as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if control.has_method("set_hovered"):
				control.call("set_hovered", false)


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
