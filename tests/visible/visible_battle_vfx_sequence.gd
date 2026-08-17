extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const YsbzsStateScript := preload("res://core/state/game_state.gd")

var state := YsbzsStateScript.new()
var battle_flow: Control = null
var _capture_requested := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	battle_flow = BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	state.start_battle()
	var player := _first_living_unit("player")
	var enemy := _first_living_unit("enemy")
	if player.is_empty() or enemy.is_empty():
		_fail("Visible VFX fixture requires one player and one enemy unit.")
		return
	var target_cell := _first_shape_target_cell(player)
	if target_cell.is_empty():
		_fail("Visible VFX fixture could not find a real attack-shape target cell.")
		return
	enemy["x"] = int(target_cell.get("x", -1))
	enemy["y"] = int(target_cell.get("y", -1))
	enemy["hp"] = max(12, int(player.get("atk", 1)) * 3)
	enemy["max_hp"] = enemy["hp"]
	state.units = [player, enemy]
	battle_flow.command_requested.connect(_on_command_requested)
	var vfx_player := battle_flow.get_node_or_null("Board/BattleVfxPlayer") as Control
	if vfx_player == null or not vfx_player.has_signal("trace_event_started"):
		_fail("Visible VFX fixture requires sequential BattleVfxPlayer.")
		return
	vfx_player.connect("trace_event_started", _on_trace_event_started)
	battle_flow.call("render_snapshot", state.snapshot())
	print("VISIBLE_BATTLE_VFX_READY click BeginTurnButton")


func _on_command_requested(command: Dictionary) -> void:
	var response := state.run_command(command)
	if not bool(response.get("accepted", false)):
		push_error("Visible VFX core command rejected: %s" % JSON.stringify(response))
		return
	battle_flow.call("render_snapshot", state.snapshot())


func _on_trace_event_started(_event_id: String) -> void:
	if _capture_requested:
		return
	_capture_requested = true
	_capture_projectile_frame.call_deferred()


func _capture_projectile_frame() -> void:
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://output/battle_begin_turn_artist_vfx.png")
	if error != OK:
		push_error("Visible VFX capture failed with error %d." % error)
		return
	print("VISIBLE_BATTLE_VFX_CAPTURED res://output/battle_begin_turn_artist_vfx.png")


func _first_living_unit(side: String) -> Dictionary:
	for value in state.units:
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == side and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _first_shape_target_cell(player: Dictionary) -> Dictionary:
	for option_value in Array(state.call("_shape_attack_options", player)):
		var option := Dictionary(option_value)
		for cell_value in Array(option.get("cells", [])):
			var cell := Dictionary(cell_value)
			var x := int(cell.get("x", -1))
			var y := int(cell.get("y", -1))
			if x >= 0 and x < 8 and y >= 0 and y < 8:
				return {"x": x, "y": y}
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
