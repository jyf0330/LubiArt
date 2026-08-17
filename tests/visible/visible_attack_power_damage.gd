extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	if packed == null:
		push_error("Could not load ysbzs_singleplayer scene.")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await _settle_seconds(0.8)
	var middle := scene
	if middle == null:
		push_error("Artist UI middle controller is missing.")
		quit(1)
		return
	middle.state.reset()
	middle.state.node_index = 3
	middle.state.route_options = middle.state._build_route_options()
	middle.call("render_current_view")
	await _settle_seconds(0.8)
	var battle_button := _find_route_button(scene, "battle")
	if battle_button == null:
		push_error("Route choices do not expose a battle option.")
		quit(1)
		return
	battle_button.emit_signal("pressed")
	if not await _wait_for_phase(middle, "battle", 2.0):
		push_error("Battle route did not enter battle phase.")
		quit(1)
		return
	var battle_flow := await _wait_for_battle_flow(scene, 2.0)
	if battle_flow == null:
		push_error("BattleArtScene scene is missing or hidden.")
		quit(1)
		return
	var actor: Dictionary = middle.state.unit_by_id("pal_002")
	var target: Dictionary = _first_enemy(middle.state)
	if actor.is_empty() or target.is_empty():
		push_error("Visible fixture is missing actor or target.")
		quit(1)
		return
	middle.state.units = [actor, target]
	actor["id"] = "pal_013"
	actor["name"] = "叶泥泥"
	actor["pet_id"] = "pal_013"
	actor["atk"] = 3
	actor["attack"] = 3
	actor["skill"] = "castleReduce"
	actor["shape"] = "形状13"
	actor["shape_id"] = "13"
	actor["shape_name"] = "形状13"
	actor["slot_count"] = 3
	actor["slot_elements"] = ["土", "土", "土"]
	actor["base_layers"] = 1
	actor["x"] = 3
	actor["y"] = 5
	actor["has_attacked"] = false
	actor["action_slots_used"] = {}
	target["x"] = 4
	target["y"] = 5
	target["hp"] = 20
	target["max_hp"] = 20
	target["shield"] = 0
	target["def"] = 0
	middle.state.ap = 3
	middle.state.selected_unit_id = "pal_013"
	middle.state.selected_action_slot_index = 0
	middle.state.battle_trace.clear()
	middle.call("render_current_view")
	await _settle_seconds(0.6)
	print("VISIBLE_ATTACK_POWER_DAMAGE_READY actor_cell=3,5 target_cell=4,5 settle_count=3 expected_target_hp=11")
	if OS.get_cmdline_user_args().has("--keep-open") or OS.get_cmdline_args().has("--keep-open"):
		return
	quit(0)


func _first_enemy(state: RefCounted) -> Dictionary:
	for unit in state.units:
		if String(unit.get("side", "")) == "enemy":
			return unit
	return {}


func _find_route_button(scene: Node, kind: String) -> BaseButton:
	for node in scene.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == "CHOOSE_ROUTE" and String(button.get_meta("route_kind", "")).to_lower() == kind:
			return button
	return null


func _wait_for_phase(middle: Node, phase: String, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if String(middle.state.snapshot().get("phase", "")) == phase:
			return true
		await _settle_seconds(0.05)
		elapsed += 0.05
	return false


func _wait_for_battle_flow(scene: Node, timeout: float) -> Control:
	var elapsed := 0.0
	while elapsed < timeout:
		var battle_flow := scene.find_child("BattleArtScene", true, false) as Control
		if battle_flow != null and battle_flow.visible:
			return battle_flow
		await _settle_seconds(0.05)
		elapsed += 0.05
	return null


func _settle_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
