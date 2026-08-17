extends SceneTree

const YsbzsStateScript := preload("res://core/state/game_state.gd")
const AutoPositionTestContextScript := preload("res://tests/helpers/auto_position_test_context.gd")

var _failed := false


func _initialize() -> void:
	var state = YsbzsStateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture starts battle")
	var player := _first_alive_player(state)
	_expect(not player.is_empty(), "fixture has an alive player unit")
	if player.is_empty():
		quit(1)
		return

	var player_before := player.duplicate(true)
	var units_before: Array = state.units.duplicate(true)
	var hash_before := String(state.call("_state_hash"))
	var evaluator := AutoPositionTestContextScript.evaluator(state)
	var context := AutoPositionTestContextScript.build(state)
	var options := {"limit": 32, "movementBudget": -1}
	var context_before := context.duplicate(true)
	var options_before := options.duplicate(true)
	_expect(String(context.get("schema", "")) == "ysbzs.auto-position-context.v1", "candidate search uses the versioned value context")
	_expect(not _contains_forbidden_value(context), "auto-position context contains no Object or Callable authority handle")
	_expect(Dictionary(context.get("limits", {})).keys().size() == 7, "auto-position context freezes all seven search limits")
	var first_candidates: Array = evaluator.candidates_for_unit(context, player, options)
	var second_candidates: Array = evaluator.candidates_for_unit(context, player, options)

	_expect(not first_candidates.is_empty(), "candidate search returns placements")
	_expect(player == player_before, "candidate search does not mutate the input unit")
	_expect(state.units == units_before, "candidate search does not mutate live battle units")
	_expect(String(state.call("_state_hash")) == hash_before, "candidate search does not mutate core state")
	_expect(first_candidates == second_candidates, "repeated pure candidate search is deterministic")
	_expect(context == context_before, "candidate search does not mutate AutoPositionContextV1")
	_expect(options == options_before, "candidate search does not mutate caller options")
	if not first_candidates.is_empty():
		var choices := [Dictionary(first_candidates[0]).duplicate(true)]
		var choices_before := choices.duplicate(true)
		evaluator.choices_conflict(choices, Dictionary(first_candidates[0]))
		_expect(choices == choices_before, "conflict evaluation does not mutate caller choices")
		var beams := [{"choices": choices, "evaluation": {"projectedDamage": {}}}]
		var beams_before := beams.duplicate(true)
		var decorated := Array(evaluator.decorate_finalists(context, beams, "player"))
		_expect(beams == beams_before, "retaliation decoration does not mutate caller beams")
		_expect(decorated.size() == beams.size(), "retaliation decoration returns a detached finalist list")
		Dictionary(first_candidates[0])["to"] = {"x": -99, "y": -99}
		_expect(state.units == units_before and String(state.call("_state_hash")) == hash_before, "mutating returned candidates cannot reach authority state")

	if _failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_CANDIDATE_PURITY_OK candidates=%d" % first_candidates.size())
	quit()


func _first_alive_player(state) -> Dictionary:
	for value in state.units:
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == "player" and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _contains_forbidden_value(value: Variant) -> bool:
	if value is Callable or value is Object:
		return true
	if value is Array:
		for item in Array(value):
			if _contains_forbidden_value(item):
				return true
	elif value is Dictionary:
		for item in Dictionary(value).values():
			if _contains_forbidden_value(item):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_AUTO_POSITION_CANDIDATE_PURITY_FAIL: %s" % message)
