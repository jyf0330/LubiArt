extends RefCounted

const SCHEMA := "ysbzs.relic-combat.v1"


func fresh() -> Dictionary:
	return {
		"schema": SCHEMA,
		"current_tick": 0,
		"next_sequence": 1,
		"queue": [],
		"instances": {},
		"last_error": "",
		"battle_end_published": false,
	}


func normalize(value: Dictionary) -> Dictionary:
	var state := fresh()
	state["current_tick"] = max(0, int(value.get("current_tick", 0)))
	state["next_sequence"] = max(1, int(value.get("next_sequence", 1)))
	state["queue"] = Array(value.get("queue", [])).duplicate(true)
	state["instances"] = Dictionary(value.get("instances", {})).duplicate(true)
	state["last_error"] = String(value.get("last_error", ""))
	state["battle_end_published"] = bool(value.get("battle_end_published", false))
	_sort_queue(state)
	return state


func add_instance(state: Dictionary, entry: Dictionary) -> void:
	var instance_id := String(entry.get("instance_id", ""))
	if instance_id == "":
		return
	var definition := Dictionary(entry.get("definition", {}))
	var instances := Dictionary(state.get("instances", {}))
	instances[instance_id] = {
		"instance_id": instance_id,
		"relic_id": String(entry.get("relic_id", "")),
		"side": String(entry.get("side", "player")),
		"definition": definition.duplicate(true),
		"generation": 0,
		"next_due_tick": -1,
		"internal_cooldown_until": 0,
		"last_trigger_tick": -1,
		"triggers_at_last_tick": 0,
		"total_triggers": 0,
	}
	state["instances"] = instances


func schedule(state: Dictionary, instance_id: String, due_tick: int, reason: String = "timer") -> Dictionary:
	var instances := Dictionary(state.get("instances", {}))
	if not instances.has(instance_id):
		return {}
	var instance := Dictionary(instances[instance_id]).duplicate(true)
	instance["generation"] = int(instance.get("generation", 0)) + 1
	instance["next_due_tick"] = max(int(state.get("current_tick", 0)), due_tick)
	instances[instance_id] = instance
	state["instances"] = instances
	var event := {
		"due_tick": int(instance["next_due_tick"]),
		"phase": 0,
		"priority": int(Dictionary(instance.get("definition", {})).get("priority", 0)),
		"sequence": int(state.get("next_sequence", 1)),
		"instance_id": instance_id,
		"generation": int(instance["generation"]),
		"reason": reason,
	}
	state["next_sequence"] = int(event["sequence"]) + 1
	var queue := Array(state.get("queue", []))
	queue.append(event)
	state["queue"] = queue
	_sort_queue(state)
	return event


func charge(state: Dictionary, instance_id: String, amount_ticks: int) -> Dictionary:
	var instances := Dictionary(state.get("instances", {}))
	if not instances.has(instance_id) or amount_ticks <= 0:
		return {}
	var instance := Dictionary(instances[instance_id])
	var due_tick := int(instance.get("next_due_tick", -1))
	if due_tick < 0:
		return {}
	return schedule(state, instance_id, max(int(state.get("current_tick", 0)), due_tick - amount_ticks), "charge")


func pop_next_due(state: Dictionary, through_tick: int) -> Dictionary:
	var queue := Array(state.get("queue", []))
	while not queue.is_empty():
		var event := Dictionary(queue[0])
		if int(event.get("due_tick", 0)) > through_tick:
			state["queue"] = queue
			return {}
		queue.remove_at(0)
		state["queue"] = queue
		var instance := Dictionary(Dictionary(state.get("instances", {})).get(String(event.get("instance_id", "")), {}))
		if instance.is_empty() or int(instance.get("generation", -1)) != int(event.get("generation", -2)):
			continue
		state["current_tick"] = int(event.get("due_tick", state.get("current_tick", 0)))
		return event
	state["queue"] = queue
	return {}


func _sort_queue(state: Dictionary) -> void:
	var queue := Array(state.get("queue", []))
	queue.sort_custom(func(a_value: Variant, b_value: Variant) -> bool:
		var a := Dictionary(a_value)
		var b := Dictionary(b_value)
		for key in ["due_tick", "phase", "priority", "sequence"]:
			var left := int(a.get(key, 0))
			var right := int(b.get(key, 0))
			if left != right:
				return left < right
		return String(a.get("instance_id", "")) < String(b.get("instance_id", ""))
	)
	state["queue"] = queue
