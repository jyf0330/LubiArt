extends SceneTree

const PhasePolicyScript := preload("res://core/state/phase_policy.gd")
const StateScript := preload("res://core/state/game_state.gd")


func _init() -> void:
	var ok := true
	ok = _expect(PhasePolicyScript.can_transition(&"route", &"shop"), "route can enter shop") and ok
	ok = _expect(PhasePolicyScript.can_transition(&"battle", &"battle_end"), "battle can finish") and ok
	ok = _expect(not PhasePolicyScript.can_transition(&"shop", &"battle"), "shop cannot jump directly to battle") and ok
	ok = _expect(PhasePolicyScript.can_execute(&"shop", "BUY_OFFER"), "shop owns BUY_OFFER") and ok
	ok = _expect(not PhasePolicyScript.can_execute(&"route", "BUY_OFFER"), "route rejects BUY_OFFER") and ok
	ok = _expect(PhasePolicyScript.can_execute(&"battle", "SET_SKILL_CONTROL_ORDER"), "battle owns SET_SKILL_CONTROL_ORDER") and ok
	ok = _expect(not PhasePolicyScript.can_execute(&"route", "SET_SKILL_CONTROL_ORDER"), "route rejects SET_SKILL_CONTROL_ORDER") and ok
	ok = _expect(PhasePolicyScript.can_execute(&"battle", "REWIND_TO_PREVIOUS_ROUND_START"), "battle owns round rewind") and ok
	ok = _expect(not PhasePolicyScript.can_execute(&"route", "REWIND_TO_PREVIOUS_ROUND_START"), "route rejects round rewind") and ok
	ok = _expect(PhasePolicyScript.can_execute(&"route", "EXPORT_REPLAY"), "global query remains phase independent") and ok

	var state: RefCounted = StateScript.new()
	var before_version := int(Dictionary(state.call("snapshot")).get("stateVersion", -1))
	ok = _expect(not bool(state.call("dispatch", {"type": "BUY_OFFER", "offerId": "missing", "baseStateVersion": before_version - 1})), "stale command is rejected before phase validation") and ok
	var stale_timeline := Array(Dictionary(state.call("replay_document")).get("debugTimeline", []))
	var stale_error := Dictionary(Dictionary(stale_timeline.back()).get("error", {}))
	ok = _expect(String(stale_error.get("code", "")) == "STATE_VERSION_MISMATCH", "stale command keeps optimistic-concurrency error precedence") and ok
	ok = _expect(not bool(state.call("dispatch", {"type": "BUY_OFFER", "offerId": "missing"})), "dispatch applies phase policy before handler") and ok
	ok = _expect(int(Dictionary(state.call("snapshot")).get("stateVersion", -2)) == before_version, "phase rejection does not mutate state version") and ok
	ok = _expect(bool(state.call("dispatch", {"type": "ENTER_SHOP", "poolId": "night_base", "slots": 3})), "valid phase command still executes") and ok
	ok = _expect(String(Dictionary(state.call("snapshot")).get("phase", "")) == "shop", "valid transition changes authoritative phase") and ok

	print("SMOKE_PHASE_POLICY_%s" % ["OK" if ok else "FAIL"])
	quit(0 if ok else 1)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Failed: %s" % label)
	return condition
