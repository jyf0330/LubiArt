extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false
var lethal_finished_before_sequence := false
var follow_started_with_target_hidden := false
var sequence_finished := false
var target_visual: Control = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var actor := _first_side(state, StateScript.PLAYER)
	var target := _first_side(state, StateScript.ENEMY)
	_expect(not actor.is_empty() and not target.is_empty(), "fixture has both sides")
	if actor.is_empty() or target.is_empty():
		_finish()
		return
	state.units = [actor, target]
	actor["id"] = "fade_actor"
	actor["x"] = 3
	actor["y"] = 5
	target["id"] = "fade_target"
	target["x"] = 4
	target["y"] = 5
	target["hp"] = 1
	target["max_hp"] = 1
	target["shield"] = 0

	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	battle_flow.call("render_snapshot", state.snapshot())
	await process_frame
	var vfx_player := battle_flow.get_node_or_null("Board/VfxHost") as Control
	_expect(vfx_player != null, "battle UI exposes VfxHost")
	if vfx_player == null:
		battle_flow.queue_free()
		_finish()
		return
	target_visual = vfx_player.call("_unit_by_id", "fade_target") as Control
	_expect(target_visual != null, "target is visible before lethal damage")
	if target_visual == null:
		battle_flow.queue_free()
		_finish()
		return

	vfx_player.trace_event_started.connect(_on_trace_event_started)
	vfx_player.trace_event_finished.connect(_on_trace_event_finished)
	vfx_player.trace_sequence_finished.connect(func(): sequence_finished = true)
	target["hp"] = 0
	state.battle_trace = [_lethal_event(), _follow_event()]
	battle_flow.call("render_snapshot", state.snapshot())
	var fade_deadline := Time.get_ticks_msec() + 3000
	while is_instance_valid(target_visual) \
			and (target_visual.modulate.a >= 0.99 or target_visual.modulate.a <= 0.01) \
			and Time.get_ticks_msec() < fade_deadline:
		await process_frame
	_expect(is_instance_valid(target_visual) and target_visual.visible, "target remains present while lethal fade is in progress")
	_expect(target_visual.modulate.a > 0.01 and target_visual.modulate.a < 0.99, "lethal hit changes alpha gradually before hiding target")
	await vfx_player.trace_sequence_finished
	_expect(lethal_finished_before_sequence, "lethal target hides before the whole trace sequence finishes")
	_expect(follow_started_with_target_hidden, "following trace starts after target has faded out")

	battle_flow.queue_free()
	await process_frame
	_finish()


func _lethal_event() -> Dictionary:
	return {
		"eventId": "lethal_fade_001",
		"type": "DAMAGE_APPLIED",
		"round": 1,
		"actor": {"id": "fade_actor", "side": "player", "x": 3, "y": 5},
		"target": {"id": "fade_target", "side": "enemy", "x": 4, "y": 5},
		"payload": {
			"element": "fire",
			"sourceType": "action",
			"finalDamage": 1,
			"hpDamage": 1,
			"hpFrom": 1,
			"hpTo": 0,
			"shieldFrom": 0,
			"shieldTo": 0
		}
	}


func _follow_event() -> Dictionary:
	return {
		"eventId": "lethal_fade_follow_001",
		"type": "round_start",
		"kind": "round_start",
		"round": 2,
		"side": "player"
	}


func _on_trace_event_started(event_id: String) -> void:
	if event_id == "lethal_fade_follow_001":
		follow_started_with_target_hidden = is_instance_valid(target_visual) and not target_visual.visible


func _on_trace_event_finished(event_id: String) -> void:
	if event_id != "lethal_fade_001":
		return
	lethal_finished_before_sequence = (
		not sequence_finished
		and is_instance_valid(target_visual)
		and not target_visual.visible
		and target_visual.modulate.a <= 0.01
	)


func _first_side(state: RefCounted, side: String) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side:
			return unit
	return {}


func _finish() -> void:
	print("SMOKE_LETHAL_HIT_IMMEDIATE_FADE_%s" % ["FAIL" if failed else "OK"])
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_LETHAL_HIT_IMMEDIATE_FADE_FAIL: %s" % message)
