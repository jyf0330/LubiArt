extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const PROJECTILE_CAPTURE := "lubi_battle_prefab_projectile.png"
const IMPACT_CAPTURE := "lubi_battle_prefab_impact.png"
const BITE_CAPTURE := "lubi_battle_prefab_bite.png"
const MOVEMENT_CAPTURE := "lubi_battle_prefab_movement.png"
const DEATH_CAPTURE := "lubi_battle_prefab_death.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main_instance := MainScene.instantiate()
	main_instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	await create_timer(0.5).timeout

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	var session := main_instance.call("get_game_session") as RefCounted
	var auto_button := battle_view.get_node_or_null("Hud/BattlePrimaryActions/AutoArrangeButton") as TextureButton if battle_view != null else null
	var begin_button := battle_view.get_node_or_null("Hud/BattlePrimaryActions/BeginTurnButton") as TextureButton if battle_view != null else null
	if battle_view == null or session == null or auto_button == null or begin_button == null:
		_fail("battle view is unavailable")
		return

	var before_auto_step := int(session.call("replay_step_index"))
	auto_button.pressed.emit()
	if not await _wait_for_step(session, before_auto_step + 1):
		_fail("auto-position did not advance")
		return
	await create_timer(0.25).timeout

	var before_action_step := int(session.call("replay_step_index"))
	begin_button.pressed.emit()
	if not await _wait_for_step(session, before_action_step + 1):
		_fail("start-action did not advance")
		return

	var observed := {
		"projectile": false,
		"element": false,
	}
	var projectile_capture_saved := false
	var impact_capture_saved := false
	var observed_lock := false
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		observed_lock = observed_lock or bool(battle_view.call("is_battle_input_locked"))
		for node in _all_descendants(battle_view):
			var node_name := String(node.name)
			var node_path := String(node.get_path())
			if node_name == "ProjectileArt" and node is CanvasItem and (node as CanvasItem).visible:
				observed["projectile"] = true
				assert(node_path.ends_with("/03_AttackActions/element_projectile/ProjectileArt"))
				if not projectile_capture_saved:
					await process_frame
					_save_capture(PROJECTILE_CAPTURE)
					projectile_capture_saved = true
			elif node_name == "ElementImpact":
				observed["element"] = true
				assert("/GroundElementEffects/ImpactLayer/" in node_path)
			if not impact_capture_saved and bool(observed["element"]):
				await process_frame
				_save_capture(IMPACT_CAPTURE)
				impact_capture_saved = true
		if observed_lock and not bool(battle_view.call("is_battle_input_locked")):
			break
		await process_frame

	var vfx_player := battle_view.get_node("Board/VfxHost")
	for child in vfx_player.get_children():
		assert(String(child.name) == "RoundFeedback")
	for key in observed.keys():
		if not bool(observed[key]):
			_fail("did not observe prefab-owned effect: %s" % key)
			return
	if not await _capture_pet_owned_samples(battle_view):
		return
	print("VISIBLE_PREFAB_VFX_PASS projectile=%s impact=%s bite=%s movement=%s death=%s" % [
		_capture_path(PROJECTILE_CAPTURE),
		_capture_path(IMPACT_CAPTURE),
		_capture_path(BITE_CAPTURE),
		_capture_path(MOVEMENT_CAPTURE),
		_capture_path(DEATH_CAPTURE),
	])
	quit(0)


func _capture_pet_owned_samples(battle_view: Control) -> bool:
	var pet: Control = null
	for node in _all_descendants(battle_view):
		if node is Control \
			and node.has_method("play_bite_impact") \
			and (node as Control).is_visible_in_tree():
			pet = node as Control
			break
	if pet == null:
		_fail("could not find a battle pet for visible samples")
		return false
	var authored_node_count := pet.find_children("*", "", true, false).size()
	var bite := pet.call("play_bite_impact") as Node
	if bite == null or not String(bite.get_path()).ends_with("/03_AttackActions"):
		_fail("bite did not use the authored 03_AttackActions node")
		return false
	if pet.find_children("*", "", true, false).size() != authored_node_count:
		_fail("bite playback changed the authored pet node structure")
		return false
	await create_timer(0.12).timeout
	_save_capture(BITE_CAPTURE)

	var origin_global := pet.global_position
	pet.call("play_grid_movement", origin_global, origin_global + Vector2(72.0, 0.0), 0.36)
	await create_timer(0.18).timeout
	_save_capture(MOVEMENT_CAPTURE)
	await create_timer(0.22).timeout

	pet.call("play_death_fade", 0.42)
	await create_timer(0.20).timeout
	_save_capture(DEATH_CAPTURE)
	await create_timer(0.28).timeout
	return true


func _wait_for_step(session: RefCounted, expected_step: int) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if int(session.call("replay_step_index")) == expected_step:
			return true
		await process_frame
	return false


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _save_capture(path: String) -> void:
	var error := root.get_texture().get_image().save_png(_capture_path(path))
	if error != OK:
		_fail("could not save %s (error %d)" % [path, error])


func _capture_path(file_name: String) -> String:
	return OS.get_environment("TEMP").path_join(file_name)


func _fail(message: String) -> void:
	push_error("VISIBLE_PREFAB_VFX_FAIL: %s" % message)
	quit(1)
