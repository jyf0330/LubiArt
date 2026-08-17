extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_title("YSBZS Auto Kill Priority Validation")
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
	var actor := Dictionary(players[0])
	var low_target := Dictionary(enemies[0])
	var high_target := low_target.duplicate(true)
	_prepare_actor(actor)
	_prepare_target(low_target, "low_damage_kill", "1血近目标", 2, 5, 1)
	_prepare_target(high_target, "high_damage_target", "60血高伤目标", 7, 5, 60)
	middle.state.units = [actor, low_target, high_target]
	middle.state.ap = 1
	middle.state.selected_unit_id = String(actor.get("id", ""))
	middle.state.selected_action_slot_index = 0
	middle.state.action_dirs["%s:slot0" % String(actor.get("id", ""))] = "left"
	middle.state.battle_trace.clear()
	middle.state.auto_position_action_plan = []
	middle.call("render_current_view")
	await _settle_seconds(0.8)
	print("VISIBLE_AUTO_POSITION_KILL_THEN_DAMAGE_READY actor=R6C4 low=R6C3:1 high=R6C8:60")
	if OS.get_cmdline_user_args().has("--keep-open") or OS.get_cmdline_args().has("--keep-open"):
		call_deferred("_monitor_validation", middle)
		return
	quit(0)


func _monitor_validation(middle: Node) -> void:
	var positioned_reported := false
	var stable_reported := false
	var first_plan_json := ""
	while is_instance_valid(middle):
		var actor: Dictionary = middle.state.unit_by_id("kill_priority_actor")
		var auto_log_count := 0
		for line_value in middle.state.log_lines:
			if String(line_value).contains("智能调整站位"):
				auto_log_count += 1
		var plan := Array(middle.state.auto_position_action_plan)
		var plan_json := JSON.stringify(plan)
		var targets_low := false
		if not plan.is_empty():
			var action := Dictionary(plan[0])
			targets_low = Array(action.get("targets", [])).has("low_damage_kill")
		if targets_low and auto_log_count >= 1 and not positioned_reported:
			positioned_reported = true
			first_plan_json = plan_json
			print("VISIBLE_AUTO_POSITION_KILL_THEN_DAMAGE_POSITIONED actor=R%dC%d target=low_damage_kill" % [int(actor.get("y", -1)) + 1, int(actor.get("x", -1)) + 1])
		if targets_low and auto_log_count >= 2 and plan_json == first_plan_json and not stable_reported:
			stable_reported = true
			print("VISIBLE_AUTO_POSITION_KILL_THEN_DAMAGE_STABLE repeated_click_same_result")
		var low_target: Dictionary = middle.state.unit_by_id("low_damage_kill")
		var high_target: Dictionary = middle.state.unit_by_id("high_damage_target")
		if stable_reported and int(low_target.get("hp", -1)) == 0 and int(high_target.get("hp", -1)) == 60:
			DisplayServer.window_set_title("YSBZS Auto Kill Priority Validation SUCCESS")
			print("VISIBLE_AUTO_POSITION_KILL_THEN_DAMAGE_EXECUTED low_hp=0 high_hp=60")
			return
		await _settle_seconds(0.1)


func _prepare_actor(actor: Dictionary) -> void:
	actor["id"] = "kill_priority_actor"
	actor["name"] = "击杀优先宠物"
	actor["x"] = 3
	actor["y"] = 5
	actor["atk"] = 10
	actor["attack"] = 10
	actor["skill"] = ""
	actor["quality_upgrade"] = {}
	actor["shape"] = "形状01"
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["slot_count"] = 1
	actor["slot_elements"] = [String(actor.get("element", "土"))]
	actor["base_layers"] = 1
	actor["move_range"] = 3
	actor["moveRange"] = 3
	actor["has_attacked"] = false
	actor["hasAttacked"] = false
	actor["action_slots_used"] = {}
	actor["action_ap_spent"] = 0


func _prepare_target(target: Dictionary, unit_id: String, display_name: String, x: int, y: int, hp: int) -> void:
	target["id"] = unit_id
	target["name"] = display_name
	target["x"] = x
	target["y"] = y
	target["hp"] = hp
	target["max_hp"] = hp
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
