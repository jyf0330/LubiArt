extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const SkillEffectPortScript := preload("res://core/ports/skill_effect_port.gd")
const RelicCombatPortScript := preload("res://core/ports/relic_combat_port.gd")

var _failed := false


class InvalidPort extends RefCounted:
	func contract_id() -> StringName:
		return &"invalid.relic-combat-port.v1"


func _initialize() -> void:
	_verify_port_contract()
	_verify_charge_and_stale_schedule()
	_verify_same_timestamp_order()
	_verify_internal_cooldown()
	_verify_combat_event_bridges()
	_verify_relic_chain_and_loop_guard()
	_verify_chunk_equivalence()
	if _failed:
		print("SMOKE_RELIC_COMBAT_TIMELINE_FAIL")
		quit(1)
		return
	print("SMOKE_RELIC_COMBAT_TIMELINE_OK")
	quit(0)


func _verify_port_contract() -> void:
	var state: RefCounted = StateScript.new()
	var service: RefCounted = state._core_composition.relic_combat_service
	var before := Dictionary(state.relic_combat_state).duplicate(true)
	service.advance(InvalidPort.new(), 100)
	_expect(Dictionary(state.relic_combat_state) == before, "relic service rejects the wrong versioned Port without mutating authority")
	_expect(int(service.current_tick(InvalidPort.new())) == 0, "relic service fails closed for an invalid Port query")
	var service_source := FileAccess.get_file_as_string("res://core/battle/relics/relic_combat_service.gd")
	_expect(not service_source.contains("authority: Object"), "relic service never receives the complete authority")
	_expect(not service_source.contains('authority.get(') and not service_source.contains('authority.set('), "relic service cannot probe or mutate the complete authority")


func _verify_charge_and_stale_schedule() -> void:
	var state := _fixture([
		_relic("timer", "TIMER_READY", {"cooldown_ticks": 1000, "priority": 20, "effects": [{"type": "grant_shield", "target": "allies", "amount": 5}]}),
		_relic("charger", "BATTLE_STARTED", {"priority": 0, "charges": [{"target_relic_id": "timer", "amount_ticks": 400}]}),
	], ["timer", "charger"])
	var runtime := Dictionary(state.relic_combat_state)
	var timer := _instance_for_relic(runtime, "timer")
	_expect(int(timer.get("next_due_tick", -1)) == 600, "battle-start Charge moves the timer from 1000 to 600 ticks")
	state._core_composition.relic_combat_service.advance(_relic_port(state), 599)
	_expect(_trigger_count(state, "timer") == 0, "timer does not trigger before its exact integer tick")
	var shield_before := _player_shield(state)
	state._core_composition.relic_combat_service.advance(_relic_port(state), 600)
	_expect(_trigger_count(state, "timer") == 1, "charged timer triggers exactly at tick 600")
	_expect(_player_shield(state) == shield_before + 5, "off-board relic effect mutates the existing on-board pet through the effect port")
	state._core_composition.relic_combat_service.advance(_relic_port(state), 1000)
	_expect(_trigger_count(state, "timer") == 1, "generation invalidation discards the stale tick-1000 schedule")
	_expect(int(_instance_for_relic(Dictionary(state.relic_combat_state), "timer").get("next_due_tick", -1)) == 1600, "periodic timer reschedules from its actual trigger tick")


func _verify_same_timestamp_order() -> void:
	var state := _fixture([
		_relic("slow_priority", "TIMER_READY", {"cooldown_ticks": 100, "priority": 20}),
		_relic("fast_priority", "TIMER_READY", {"cooldown_ticks": 100, "priority": 10}),
	], ["slow_priority", "fast_priority"])
	state.battle_trace = []
	state._core_composition.relic_combat_service.advance(_relic_port(state), 100)
	var ids := _trigger_ids(state)
	_expect(ids == ["fast_priority", "slow_priority"], "same-timestamp relics use priority before creation sequence")


func _verify_internal_cooldown() -> void:
	var state := _fixture([
		_relic("listener", "RELIC_PULSE", {"internal_cooldown_ticks": 100}),
	], ["listener"])
	var service: RefCounted = state._core_composition.relic_combat_service
	var relic_port: RefCounted = _relic_port(state)
	service.publish(relic_port, "RELIC_PULSE", {})
	service.publish(relic_port, "RELIC_PULSE", {})
	_expect(_trigger_count(state, "listener") == 1, "internal cooldown suppresses repeated semantic triggers at the same tick")
	service.advance(relic_port, 99)
	service.publish(relic_port, "RELIC_PULSE", {})
	_expect(_trigger_count(state, "listener") == 1, "internal cooldown remains closed before its exact boundary")
	service.advance(relic_port, 100)
	service.publish(relic_port, "RELIC_PULSE", {})
	_expect(_trigger_count(state, "listener") == 2, "internal cooldown reopens at its exact integer boundary")


func _verify_combat_event_bridges() -> void:
	var state := _fixture([
		_relic("timer", "TIMER_READY", {"cooldown_ticks": 50}),
		_relic("combo_listener", "SKILL_COMBO_USED"),
		_relic("damage_listener", "DAMAGE_APPLIED"),
	], ["timer", "combo_listener", "damage_listener"])
	var player := _first_unit(state, "player")
	var enemy := _first_unit(state, "enemy")
	var port: RefCounted = SkillEffectPortScript.new(state)
	port.finish_skill({
		"unit": player,
		"definition": {"id": "bridge_combo", "name": "bridge_combo", "duration_ticks": 50},
		"option": {},
		"targets": [],
		"logs": [],
		"source_kind": "combo",
	})
	_expect(int(Dictionary(state.relic_combat_state).get("current_tick", -1)) == 50, "skill duration advances the relic timeline before the completion event")
	_expect(_trigger_count(state, "timer") == 1, "skill duration releases an intervening timer event")
	_expect(_trigger_count(state, "combo_listener") == 1, "skill completion publishes the semantic combo event")
	state.call("_deal_damage", player, enemy, 1, "无", false, {"sourceType": "skill"})
	_expect(_trigger_count(state, "damage_listener") == 1, "authoritative damage trace publishes DAMAGE_APPLIED to off-board relics")


func _verify_relic_chain_and_loop_guard() -> void:
	var state := _fixture([
		_relic("emitter", "BATTLE_STARTED", {"emit_events": [{"event_type": "RELIC_PULSE"}]}),
		_relic("listener", "RELIC_PULSE", {"effects": [{"type": "grant_shield", "target": "allies", "amount": 2}]}),
		_relic("loop_seed", "BATTLE_STARTED", {"emit_events": [{"event_type": "RELIC_LOOP"}]}),
		_relic("loop", "RELIC_LOOP", {"max_triggers_per_tick": 3, "emit_events": [{"event_type": "RELIC_LOOP"}]}),
	], ["emitter", "listener", "loop_seed", "loop"])
	_expect(_trigger_count(state, "listener") == 1, "one relic can emit a semantic event that triggers another relic")
	_expect(_trigger_count(state, "loop") == 3, "per-relic timestamp cap stops a self-repeating chain at the configured count")
	_expect(String(Dictionary(state.relic_combat_state).get("last_error", "")).begins_with("relic_trigger_limit:"), "loop protection records a deterministic authoritative error")
	_expect(_trace_events(state, "RELIC_LOOP_GUARD").size() == 1, "loop protection emits a presentation trace")


func _verify_chunk_equivalence() -> void:
	var definitions := [_relic("timer", "TIMER_READY", {"cooldown_ticks": 200, "effects": [{"type": "grant_shield", "target": "allies", "amount": 1}]})]
	var whole := _fixture(definitions, ["timer"])
	var chunked := _fixture(definitions, ["timer"])
	whole._core_composition.relic_combat_service.advance(_relic_port(whole), 1000)
	for tick in range(100, 1001, 100):
		chunked._core_composition.relic_combat_service.advance(_relic_port(chunked), tick)
	_expect(Dictionary(whole.relic_combat_state) == Dictionary(chunked.relic_combat_state), "one large advance and ten smaller advances produce identical timeline state")
	_expect(_player_shield(whole) == _player_shield(chunked), "chunk size does not change relic effects on pets")
	_expect(String(whole.snapshot().get("stateHash", "")) == String(chunked.snapshot().get("stateHash", "")), "chunk size does not change the authoritative state hash")


func _fixture(definitions: Array, inventory: Array) -> RefCounted:
	var state: RefCounted = _test_state()
	var data := Dictionary(state.game_data).duplicate(true)
	var economy := Dictionary(data.get("economy", {})).duplicate(true)
	economy["relics"] = definitions.duplicate(true)
	data["economy"] = economy
	data["relic_inventory"] = inventory.duplicate(true)
	_expect(state.call("replace_game_data_for_test", data, &"current_assembly"), "relic fixture content binds through the test-only authority helper")
	state.reset()
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture enters battle")
	return state


func _test_state() -> RefCounted:
	var production: RefCounted = StateScript.new()
	return StateScript.new({
		"mode": "test",
		"content_pack": Dictionary(production.get("game_data")).duplicate(true),
		"content_source_kind": production.call("content_source_kind"),
	})


func _relic(relic_id: String, trigger_type: String, overrides: Dictionary = {}) -> Dictionary:
	var definition := {
		"id": relic_id,
		"name": relic_id,
		"trigger_type": trigger_type,
		"cooldown_ticks": 0,
		"internal_cooldown_ticks": 0,
		"priority": 0,
		"effects": [],
		"charges": [],
		"emit_events": [],
	}
	definition.merge(overrides, true)
	return definition


func _instance_for_relic(runtime: Dictionary, relic_id: String) -> Dictionary:
	for value in Dictionary(runtime.get("instances", {})).values():
		var instance := Dictionary(value)
		if String(instance.get("relic_id", "")) == relic_id:
			return instance
	return {}


func _trigger_count(state: RefCounted, relic_id: String) -> int:
	return int(_instance_for_relic(Dictionary(state.relic_combat_state), relic_id).get("total_triggers", 0))


func _trigger_ids(state: RefCounted) -> Array:
	var ids: Array = []
	for event_value in _trace_events(state, "RELIC_TRIGGERED"):
		ids.append(String(Dictionary(Dictionary(event_value).get("payload", {})).get("relicId", "")))
	return ids


func _trace_events(state: RefCounted, event_type: String) -> Array:
	var events: Array = []
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) == event_type:
			events.append(event)
	return events


func _player_shield(state: RefCounted) -> int:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == "player" and int(unit.get("hp", 0)) > 0:
			return int(unit.get("shield", 0))
	return -1


func _first_unit(state: RefCounted, side: String) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _relic_port(state: RefCounted) -> RefCounted:
	return RelicCombatPortScript.new(state)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_RELIC_COMBAT_TIMELINE_FAIL: %s" % message)
