extends RefCounted

const RelicTimelineScript := preload("res://core/battle/relics/relic_timeline.gd")

const MAX_EVENTS_PER_TIMESTAMP := 1024
const MAX_EVENTS_PER_ADVANCE := 8192
const PORT_CONTRACT_ID := &"ysbzs.relic-combat-port.v1"
const REQUIRED_PORT_METHODS: Array[StringName] = [
	&"contract_id",
	&"relic_inventory",
	&"game_data",
	&"phase",
	&"relic_state",
	&"replace_relic_state",
	&"append_trace",
	&"skill_effect_port",
	&"log_guard",
]

var _catalog_service: RefCounted
var _effect_interpreter: RefCounted
var _timeline := RelicTimelineScript.new()
var _processing := false
var _immediate: Array = []


func configure(catalog_service: RefCounted, effect_interpreter: RefCounted) -> RefCounted:
	_catalog_service = catalog_service
	_effect_interpreter = effect_interpreter
	return self


func start(port: RefCounted) -> void:
	if not _accepts(port):
		return
	var state := _timeline.fresh()
	for entry_value in _catalog_service.inventory_entries(port.relic_inventory(), port.game_data()):
		var entry := Dictionary(entry_value)
		_timeline.add_instance(state, entry)
		var definition := Dictionary(entry.get("definition", {}))
		var cooldown := int(definition.get("cooldown_ticks", 0))
		if bool(definition.get("timer_enabled", false)) and cooldown > 0:
			_timeline.schedule(state, String(entry.get("instance_id", "")), cooldown, "initial")
	port.replace_relic_state(state)
	publish(port, "BATTLE_STARTED", {})


func publish(port: RefCounted, event_type: String, payload: Dictionary = {}) -> void:
	if not _accepts(port) or port.phase() != "battle":
		return
	var state := _state(port)
	if String(state.get("last_error", "")) != "":
		return
	_enqueue_matches(state, event_type, payload)
	port.replace_relic_state(state)
	_drain(port)


func publish_battle_end(port: RefCounted, payload: Dictionary = {}) -> void:
	if not _accepts(port):
		return
	var state := _state(port)
	if bool(state.get("battle_end_published", false)):
		return
	state["battle_end_published"] = true
	port.replace_relic_state(state)
	publish(port, "BATTLE_ENDED", payload)


func advance(port: RefCounted, target_tick: int) -> void:
	if not _accepts(port):
		return
	var state := _state(port)
	if String(state.get("last_error", "")) != "":
		return
	var target: int = max(int(state.get("current_tick", 0)), target_tick)
	var processed := 0
	while processed < MAX_EVENTS_PER_ADVANCE:
		var event := _timeline.pop_next_due(state, target)
		if event.is_empty():
			break
		_immediate.append({
			"instance_id": String(event.get("instance_id", "")),
			"event_type": "TIMER_READY",
			"payload": {"reason": String(event.get("reason", "timer"))},
			"scheduled": true,
		})
		port.replace_relic_state(state)
		_drain(port)
		state = _state(port)
		processed += 1
	if processed >= MAX_EVENTS_PER_ADVANCE:
		_guard(port, state, "advance_event_limit")
	state["current_tick"] = target
	port.replace_relic_state(state)


func current_tick(port: RefCounted) -> int:
	return int(_state(port).get("current_tick", 0)) if _accepts(port) else 0


func _state(port: RefCounted) -> Dictionary:
	return _timeline.normalize(port.relic_state())


func _enqueue_matches(state: Dictionary, event_type: String, payload: Dictionary) -> void:
	var instances := Dictionary(state.get("instances", {}))
	var ids := instances.keys()
	ids.sort_custom(func(a_value: Variant, b_value: Variant) -> bool:
		var a := Dictionary(instances[a_value])
		var b := Dictionary(instances[b_value])
		var a_priority := int(Dictionary(a.get("definition", {})).get("priority", 0))
		var b_priority := int(Dictionary(b.get("definition", {})).get("priority", 0))
		return a_priority < b_priority if a_priority != b_priority else String(a_value) < String(b_value)
	)
	for instance_id_value in ids:
		var instance := Dictionary(instances[instance_id_value])
		var definition := Dictionary(instance.get("definition", {}))
		if String(definition.get("trigger_type", "")) != event_type:
			continue
		if not _matches_filter(Dictionary(definition.get("event_filter", {})), payload):
			continue
		_immediate.append({
			"instance_id": String(instance_id_value),
			"event_type": event_type,
			"payload": payload.duplicate(true),
			"scheduled": false,
		})


func _drain(port: RefCounted) -> void:
	if _processing:
		return
	_processing = true
	var processed := 0
	var timestamp := current_tick(port)
	while not _immediate.is_empty():
		var state := _state(port)
		if current_tick(port) != timestamp:
			timestamp = current_tick(port)
			processed = 0
		if processed >= MAX_EVENTS_PER_TIMESTAMP:
			_guard(port, state, "timestamp_event_limit")
			_immediate.clear()
			break
		var trigger := Dictionary(_immediate.pop_front())
		_resolve(port, state, trigger)
		processed += 1
		if String(port.relic_state().get("last_error", "")) != "":
			_immediate.clear()
			break
	_processing = false


func _resolve(port: RefCounted, state: Dictionary, trigger: Dictionary) -> void:
	var instance_id := String(trigger.get("instance_id", ""))
	var instances := Dictionary(state.get("instances", {}))
	if not instances.has(instance_id):
		return
	var instance := Dictionary(instances[instance_id]).duplicate(true)
	var definition := Dictionary(instance.get("definition", {}))
	var tick := int(state.get("current_tick", 0))
	if tick < int(instance.get("internal_cooldown_until", 0)):
		return
	if int(instance.get("last_trigger_tick", -1)) == tick:
		instance["triggers_at_last_tick"] = int(instance.get("triggers_at_last_tick", 0)) + 1
	else:
		instance["last_trigger_tick"] = tick
		instance["triggers_at_last_tick"] = 1
	var per_tick_limit := int(definition.get("max_triggers_per_tick", 0))
	if per_tick_limit > 0 and int(instance["triggers_at_last_tick"]) > per_tick_limit:
		instances[instance_id] = instance
		state["instances"] = instances
		_guard(port, state, "relic_trigger_limit:%s" % instance_id)
		return
	instance["internal_cooldown_until"] = tick + int(definition.get("internal_cooldown_ticks", 0))
	instance["total_triggers"] = int(instance.get("total_triggers", 0)) + 1
	instances[instance_id] = instance
	state["instances"] = instances
	if bool(trigger.get("scheduled", false)):
		var cooldown := int(definition.get("cooldown_ticks", 0))
		if cooldown > 0:
			_timeline.schedule(state, instance_id, tick + cooldown, "periodic")
	port.replace_relic_state(state)
	_append_trace(port, "RELIC_TRIGGERED", instance, trigger)
	var effects := Array(definition.get("effects", []))
	if not effects.is_empty() and _effect_interpreter != null:
		var effect_port: RefCounted = port.skill_effect_port()
		var context := Dictionary(effect_port.call(&"begin_relic", instance, definition, trigger))
		if not context.is_empty():
			_effect_interpreter.call(&"execute", effect_port, context, effects)
			effect_port.call(&"finish_relic", context)
	_apply_charges(port, instance, definition)
	_emit_events(port, instance, definition, trigger)


func _apply_charges(port: RefCounted, source_instance: Dictionary, definition: Dictionary) -> void:
	for charge_value in Array(definition.get("charges", [])):
		var charge := Dictionary(charge_value)
		var amount: int = max(0, int(charge.get("amount_ticks", 0)))
		if amount <= 0:
			continue
		var state := _state(port)
		var targets: Array[String] = []
		var target_instance_id := String(charge.get("target_instance_id", ""))
		var target_relic_id := String(charge.get("target_relic_id", ""))
		for candidate_id_value in Dictionary(state.get("instances", {})).keys():
			var candidate_id := String(candidate_id_value)
			var candidate := Dictionary(Dictionary(state["instances"])[candidate_id])
			if target_instance_id != "" and candidate_id == target_instance_id:
				targets.append(candidate_id)
			elif target_instance_id == "" and target_relic_id != "" and String(candidate.get("relic_id", "")) == target_relic_id:
				targets.append(candidate_id)
		targets.sort()
		for target_id in targets:
			var scheduled := _timeline.charge(state, target_id, amount)
			if not scheduled.is_empty() and int(scheduled.get("due_tick", -1)) <= int(state.get("current_tick", 0)):
				_immediate.append({"instance_id": target_id, "event_type": "TIMER_READY", "payload": {"reason": "charge", "source_instance_id": String(source_instance.get("instance_id", ""))}, "scheduled": true})
		port.replace_relic_state(state)


func _emit_events(port: RefCounted, source_instance: Dictionary, definition: Dictionary, trigger: Dictionary) -> void:
	for emitted_value in Array(definition.get("emit_events", [])):
		var emitted := Dictionary(emitted_value)
		var event_type := String(emitted.get("event_type", emitted.get("type", ""))).to_upper()
		if event_type == "":
			continue
		var payload := Dictionary(emitted.get("payload", {})).duplicate(true)
		payload["source_instance_id"] = String(source_instance.get("instance_id", ""))
		payload["caused_by_event"] = String(trigger.get("event_type", ""))
		var state := _state(port)
		_enqueue_matches(state, event_type, payload)
		port.replace_relic_state(state)


func _matches_filter(filter: Dictionary, payload: Dictionary) -> bool:
	for key_value in filter.keys():
		if payload.get(key_value) != filter[key_value]:
			return false
	return true


func _append_trace(port: RefCounted, event_type: String, instance: Dictionary, trigger: Dictionary) -> void:
	port.append_trace(event_type, instance, current_tick(port), trigger)


func _guard(port: RefCounted, state: Dictionary, reason: String) -> void:
	state["last_error"] = reason
	port.replace_relic_state(state)
	_append_trace(port, "RELIC_LOOP_GUARD", {}, {"event_type": reason, "payload": {}})
	port.log_guard(reason)


func _accepts(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.contract_id()) == PORT_CONTRACT_ID
