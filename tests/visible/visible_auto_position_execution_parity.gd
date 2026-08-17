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
	var players := _living_units_for_side(middle.state, "player")
	var enemies := _living_units_for_side(middle.state, "enemy")
	if players.is_empty() or enemies.is_empty():
		push_error("Visible fixture is missing player or enemy units.")
		quit(1)
		return
	var actor_a := Dictionary(players[0])
	var actor_b := actor_a.duplicate(true)
	actor_b["id"] = "pal_auto_ally"
	actor_b["name"] = "%s·协同" % String(actor_a.get("name", "我方宠物"))
	var target_a := Dictionary(enemies[0])
	var target_b := target_a.duplicate(true)
	target_b["id"] = "enemy_auto_right"
	target_b["name"] = "%s·右" % String(target_a.get("name", "敌方宠物"))
	_prepare_actor(actor_a, 1, 3)
	_prepare_actor(actor_b, 1, 5)
	_prepare_target(target_a, 4, 3)
	_prepare_target(target_b, 4, 5)
	middle.state.units = [actor_a, actor_b, target_a, target_b]
	middle.state.ap = 2
	middle.state.selected_unit_id = String(actor_a.get("id", ""))
	middle.state.selected_action_slot_index = 0
	middle.state.battle_trace.clear()
	middle.state.auto_position_action_plan = []
	middle.call("render_current_view")
	await _settle_seconds(0.8)
	print("VISIBLE_AUTO_POSITION_EXECUTION_READY players=R4C2,R6C2 enemies=R4C5,R6C5")
	if OS.get_cmdline_user_args().has("--keep-open") or OS.get_cmdline_args().has("--keep-open"):
		return
	quit(0)


func _prepare_actor(actor: Dictionary, x: int, y: int) -> void:
	actor["x"] = x
	actor["y"] = y
	actor["atk"] = 10
	actor["attack"] = 10
	actor["shape"] = "形状01"
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["slot_count"] = 1
	actor["slot_elements"] = [String(actor.get("element", "土"))]
	actor["base_layers"] = 1
	actor["move_range"] = 5
	actor["moveRange"] = 5
	actor["has_attacked"] = false
	actor["hasAttacked"] = false
	actor["action_slots_used"] = {}
	actor["action_ap_spent"] = 0


func _prepare_target(target: Dictionary, x: int, y: int) -> void:
	target["x"] = x
	target["y"] = y
	target["hp"] = 10
	target["max_hp"] = 10
	target["shield"] = 0
	target["def"] = 0
	target["boss"] = false
	target["isBoss"] = false


func _living_units_for_side(state: RefCounted, side: String) -> Array:
	var result: Array = []
	for unit in state.units:
		if String(unit.get("side", "")) == side and int(unit.get("hp", 0)) > 0:
			result.append(unit)
	return result


func _find_route_button(scene: Node, kind: String) -> BaseButton:
	for node in scene.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == "CHOOSE_ROUTE" and String(button.get_meta("route_kind", "")).to_lower() == kind:
			return button
	return null


func _wait_for_phase(middle: Node, expected_phase: String, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if String(middle.state.snapshot().get("phase", "")) == expected_phase:
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
