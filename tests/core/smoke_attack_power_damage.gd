extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const AutoPositionTestContextScript := preload("res://tests/helpers/auto_position_test_context.gd")

var failed := false


func _initialize() -> void:
	var state := StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture starts battle")
	var actor := state.unit_by_id("pal_002")
	var target := _first_enemy(state)
	_expect(not actor.is_empty() and not target.is_empty(), "fixture has actor and target")
	if actor.is_empty() or target.is_empty():
		_finish()
		return
	state.units = [actor, target]
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
	actor["quality_upgrade"] = {}
	actor["quality_runtime"] = {}
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
	state.ap = 3
	var option := Dictionary(state.call("_attack_option_for_direction", actor, "right"))
	var slot := Dictionary(Array(state.call("_action_slots_for_unit", actor))[0])
	var strike_count: int = max(1, int(slot.get("strike_count", 1)))
	_expect(not option.has("settle_count") and not option.has("strike_count"), "attack option exposes geometry without cadence")
	_expect(strike_count == 3, "legacy authored cadence is normalized onto the action slot")
	var candidates := AutoPositionTestContextScript.candidates(state, actor, {
		"limit": 64,
		"movementBudget": 0,
		"allowDirectionChanges": true,
		"positionIndependent": false,
	})
	var scored_candidate := _candidate_for(candidates, actor, "right", String(target.get("id", "")))
	var expected_raw_damage: int = 3 * strike_count
	_expect(int(scored_candidate.get("rawDamage", -1)) == expected_raw_damage, "auto-position derives raw damage from attack power times the action strike count")
	target["def"] = 1
	var defended_strike: int = int(state.call("_battle_query_damage_final", actor, target, 3, String(slot.get("element", "")), {"sourceType": "attack_power_smoke"}))
	_expect(defended_strike * strike_count == 2 * strike_count, "each action strike independently passes through the final defense pipeline")
	target["def"] = 0
	var expected_strike: int = int(state.call("_battle_query_damage_final", actor, target, 3, String(slot.get("element", "")), {"sourceType": "attack_power_smoke"}))
	var expected_total: int = expected_strike * strike_count
	_expect(state.dispatch({"type": "SELECT_UNIT", "unitId": String(actor.get("id", ""))}), "fixture selects 叶泥泥")
	_expect(state.dispatch({"type": "SELECT_CELL", "cell": {"c": 4, "r": 5}}), "叶泥泥 attacks the target")
	_expect(int(target.get("hp", -1)) == 20 - expected_total, "preview and mutation agree for every action strike")
	var action_damage_events := _damage_events(state.battle_trace, "action")
	_expect(action_damage_events.size() == strike_count, "one area cast produces one damage event per action strike")
	for strike_index in range(action_damage_events.size()):
		var payload := Dictionary(Dictionary(action_damage_events[strike_index]).get("payload", {}))
		_expect(int(payload.get("rawDamage", -1)) == 3 and int(payload.get("finalDamage", -1)) == expected_strike, "each strike starts from attack power 3 and uses final damage")
		_expect(int(payload.get("strikeIndex", -1)) == strike_index + 1 and int(payload.get("strikeCount", -1)) == strike_count, "damage trace preserves action strike order")
	_expect(_log_contains(state.snapshot().get("log_lines", []), "造成 %d段" % strike_count), "battle log reports the action strike count")
	_finish()


func _first_enemy(state: RefCounted) -> Dictionary:
	for unit in state.units:
		if String(unit.get("side", "")) == StateScript.ENEMY:
			return unit
	return {}


func _candidate_for(candidates: Array, actor: Dictionary, direction: String, target_id: String) -> Dictionary:
	for candidate_value in candidates:
		var candidate := Dictionary(candidate_value)
		var to := Dictionary(candidate.get("to", {}))
		if String(candidate.get("dir", "")) == direction \
				and int(to.get("x", -1)) == int(actor.get("x", -2)) \
				and int(to.get("y", -1)) == int(actor.get("y", -2)) \
				and Array(candidate.get("targets", [])).has(target_id):
			return candidate
	return {}


func _log_contains(lines: Array, needle: String) -> bool:
	for line in lines:
		if String(line).contains(needle):
			return true
	return false


func _damage_events(events: Array, source_type: String) -> Array:
	var out: Array = []
	for event_value in events:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) != "DAMAGE_APPLIED":
			continue
		if String(Dictionary(event.get("payload", {})).get("sourceType", "")) == source_type:
			out.append(event)
	return out


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)


func _finish() -> void:
	if failed:
		quit(1)
		return
	print("SMOKE_ATTACK_POWER_DAMAGE_OK")
	quit(0)
