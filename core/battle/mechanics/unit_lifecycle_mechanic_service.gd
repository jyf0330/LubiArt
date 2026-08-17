extends RefCounted

## Owns the fixed unit/battle lifecycle order. Mechanic behavior is discovered
## from repository-owned handlers; authority remains behind the versioned port.

const MechanicHandlerRegistryScript := preload("res://core/battle/mechanics/mechanic_handler_registry.gd")

const PORT_CONTRACT_ID := &"ysbzs.unit-lifecycle-mechanic-port.v1"
const REQUIRED_PORT_METHODS: Array[StringName] = [
	&"contract_id", &"mechanic_ids", &"mechanism", &"mechanic_param_int",
	&"mechanic_param_float", &"mechanic_param_string", &"cross_damage",
	&"first_empty_near", &"first_adjacent_empty", &"summon_unit", &"summon_wall",
	&"copy_weak_self", &"all_units", &"battle_end_units", &"battle_round",
	&"shop_next_discount", &"set_shop_next_discount", &"enemy_side",
]

var _handler_registry: RefCounted


func _init(handler_directory: String = MechanicHandlerRegistryScript.HANDLER_DIRECTORY) -> void:
	_handler_registry = MechanicHandlerRegistryScript.new(handler_directory)


func configure_handler_registry(registry: RefCounted) -> RefCounted:
	_handler_registry = registry
	return self


func apply_on_death(port: RefCounted, unit: Dictionary, source: Dictionary) -> Array:
	var logs: Array = []
	if not _ready(port) or unit.is_empty() or int(unit.get("hp", 0)) > 0:
		return logs
	var flags := Dictionary(unit.get("flags", {}))
	if bool(flags.get("onDeathMechanicsApplied", false)):
		return logs
	# This is a lifecycle-wide guard, not a per-handler guard. It must be set once
	# before the first handler so explosion + summon combinations still both run.
	flags["onDeathMechanicsApplied"] = true
	unit["flags"] = flags
	return _dispatch_unit_logs(port, unit, &"on_death", [port, unit, source])


func apply_on_shield_break(port: RefCounted, unit: Dictionary, source: Dictionary) -> Array:
	if not _ready(port) or unit.is_empty():
		return []
	return _dispatch_unit_logs(port, unit, &"on_shield_break", [port, unit, source])


func apply_after_ally_death(port: RefCounted, defeated: Dictionary) -> Array:
	var logs: Array = []
	if not _ready(port) or defeated.is_empty() or int(defeated.get("hp", 0)) > 0:
		return logs
	var defeated_side := String(defeated.get("side", ""))
	var defeated_id := String(defeated.get("id", ""))
	for unit_value in port.all_units():
		var receiver := Dictionary(unit_value)
		if String(receiver.get("id", "")) == defeated_id or String(receiver.get("side", "")) != defeated_side or int(receiver.get("hp", 0)) <= 0:
			continue
		logs.append_array(_dispatch_unit_logs(port, receiver, &"after_ally_death", [port, receiver, defeated]))
	return logs


func apply_attacker_after_kill(port: RefCounted, killer: Dictionary, defeated: Dictionary) -> Array:
	if not _ready(port) or killer.is_empty() or defeated.is_empty() or int(killer.get("hp", 0)) <= 0:
		return []
	return _dispatch_unit_logs(port, killer, &"after_kill", [port, killer, defeated])


func apply_after_action(port: RefCounted, actor: Dictionary) -> Array:
	if not _ready(port) or actor.is_empty() or int(actor.get("hp", 0)) <= 0:
		return []
	return _dispatch_unit_logs(port, actor, &"after_action", [port, actor])


func apply_battle_end(port: RefCounted, win: bool, gold_reward: int) -> Dictionary:
	var initial_gold: int = max(0, gold_reward)
	var empty_result := {"gold": initial_gold, "logs": [], "applied": [], "extra_rewards": []}
	if not _ready(port):
		return empty_result
	var initial_discount := int(port.shop_next_discount())
	var reward_state := {
		"gold": initial_gold,
		"logs": [],
		"applied": [],
		"extra_rewards": [],
		"discount_from": initial_discount,
		"discount_to": initial_discount,
		"discount_requested": false,
	}
	for unit_value in port.battle_end_units():
		var unit := Dictionary(unit_value)
		for mechanism_id_value in port.mechanic_ids(unit):
			var mechanism_id := String(mechanism_id_value)
			var mechanism := Dictionary(port.mechanism(mechanism_id))
			var handler: RefCounted = _handler_registry.handler_for(mechanism_id, mechanism)
			if handler == null or not _handler_registry.supports(handler, &"battle_end"):
				continue
			var next_state_value: Variant = handler.call(&"battle_end", port, unit, win, reward_state, mechanism)
			if typeof(next_state_value) != TYPE_DICTIONARY:
				return empty_result
			var next_state := Dictionary(next_state_value)
			if not _valid_reward_state(next_state):
				return empty_result
			reward_state = next_state
	if bool(reward_state.get("discount_requested", false)):
		port.set_shop_next_discount(int(reward_state.get("discount_to", initial_discount)))
	return {
		"gold": int(reward_state.get("gold", initial_gold)),
		"logs": Array(reward_state.get("logs", [])).duplicate(true),
		"applied": Array(reward_state.get("applied", [])).duplicate(true),
		"extra_rewards": Array(reward_state.get("extra_rewards", [])).duplicate(true),
	}


func is_valid() -> bool:
	return _handler_registry != null and bool(_handler_registry.is_valid())


func validation_errors() -> Array[String]:
	return _handler_registry.validation_errors() if _handler_registry != null else ["Mechanic handler registry is unavailable."]


func _dispatch_unit_logs(port: RefCounted, unit: Dictionary, hook: StringName, arguments: Array) -> Array:
	var logs: Array = []
	for mechanism_id_value in port.mechanic_ids(unit):
		var mechanism_id := String(mechanism_id_value)
		var mechanism := Dictionary(port.mechanism(mechanism_id))
		var handler: RefCounted = _handler_registry.handler_for(mechanism_id, mechanism)
		if handler == null or not _handler_registry.supports(handler, hook):
			continue
		var hook_arguments := arguments.duplicate()
		hook_arguments.append(mechanism)
		var result: Variant = handler.callv(hook, hook_arguments)
		if typeof(result) != TYPE_ARRAY:
			continue
		for line in Array(result):
			logs.append(String(line))
	return logs


func _valid_reward_state(value: Dictionary) -> bool:
	for key in ["gold", "logs", "applied", "extra_rewards", "discount_from", "discount_to", "discount_requested"]:
		if not value.has(key):
			return false
	return (
		typeof(value.get("logs")) == TYPE_ARRAY
		and typeof(value.get("applied")) == TYPE_ARRAY
		and typeof(value.get("extra_rewards")) == TYPE_ARRAY
	)


func _ready(port: RefCounted) -> bool:
	return _accepts(port) and is_valid()


func _accepts(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.call(&"contract_id")) == PORT_CONTRACT_ID
