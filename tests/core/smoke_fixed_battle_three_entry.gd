extends SceneTree

const YsbzsStateScript := preload("res://core/state/game_state.gd")
const FIXED_BATTLE_STEPS := [3, 6]


func _initialize() -> void:
	var state := YsbzsStateScript.new()
	for step in FIXED_BATTLE_STEPS:
		if not _assert_shared_battle_entries(state, step):
			quit(1)
			return
	print("SMOKE_FIXED_BATTLE_THREE_ENTRY_OK steps=3,6 entries=3 shared_encounter=true")
	quit(0)


func _assert_shared_battle_entries(state: Object, step: int) -> bool:
	state.reset()
	state.node_index = step
	state.route_options = state._build_route_options()
	var options := Array(state.snapshot().get("route_options", []))
	if options.size() != 3:
		push_error("Fixed battle step %d should expose 3 entries, got %d." % [step, options.size()])
		return false
	var encounter_id := ""
	for entry_index in range(options.size()):
		var option := Dictionary(options[entry_index])
		if String(option.get("kind", "")) != "battle":
			push_error("Fixed battle step %d entry %d should be kind=battle." % [step, entry_index + 1])
			return false
		if int(option.get("entryIndex", 0)) != entry_index + 1 or int(option.get("entryCount", 0)) != 3:
			push_error("Fixed battle step %d entry metadata is invalid." % step)
			return false
		var current_encounter_id := String(option.get("encounterId", ""))
		if current_encounter_id == "":
			push_error("Fixed battle step %d entry %d is missing encounterId." % [step, entry_index + 1])
			return false
		if encounter_id == "":
			encounter_id = current_encounter_id
		elif current_encounter_id != encounter_id:
			push_error("Fixed battle step %d entries must share one encounter." % step)
			return false
	var selected := Dictionary(options[2])
	if not state.choose_route(String(selected.get("optionId", ""))):
		push_error("Fixed battle step %d third entry should be selectable." % step)
		return false
	var snapshot := Dictionary(state.snapshot())
	if String(snapshot.get("phase", "")) != "battle":
		push_error("Fixed battle step %d third entry should enter battle." % step)
		return false
	var active_encounter := Dictionary(state.active_encounter)
	if String(active_encounter.get("encounterId", "")) != encounter_id:
		push_error("Fixed battle step %d selected the wrong encounter." % step)
		return false
	return true
