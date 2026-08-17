extends SceneTree

const MechanicHandlerRegistryScript := preload("res://core/battle/mechanics/mechanic_handler_registry.gd")
const DamageMechanicServiceScript := preload("res://core/battle/mechanics/damage_mechanic_service.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")

const VALID_DIRECTORY := "res://tests/fixtures/plugins/mechanics/valid"
const INVALID_CASES := {
	"res://tests/fixtures/plugins/mechanics/duplicate": ["fixture_duplicate", "Duplicate plugin id"],
	"res://tests/fixtures/plugins/mechanics/missing_plugin_id": ["", "Plugin is missing plugin_id"],
	"res://tests/fixtures/plugins/mechanics/zero_hook": ["fixture_zero_hook", "at least one allowed hook"],
	"res://tests/fixtures/plugins/mechanics/wrong_arity": ["fixture_wrong_arity", "before_damage expected 7 arguments, found 6"],
	"res://tests/fixtures/plugins/mechanics/wrong_arg_type": ["fixture_wrong_arg_type", "project_trap_entry argument 0 expected Dictionary, found Array"],
	"res://tests/fixtures/plugins/mechanics/wrong_arg_class": ["fixture_wrong_arg_class", "on_battle_start argument 0 expected RefCounted, found Node"],
	"res://tests/fixtures/plugins/mechanics/wrong_return": ["fixture_wrong_return", "method project_death_preview return expected Dictionary, found Array"],
	"res://tests/fixtures/plugins/mechanics/untyped_hook": ["fixture_untyped_hook", "project_element_settlement argument 0 expected Dictionary"],
	"res://tests/fixtures/plugins/mechanics/untyped_hook_return": ["fixture_untyped_hook_return", "method project_death_preview return expected Dictionary, found Nil"],
	"res://tests/fixtures/plugins/mechanics/untyped_plugin_id": ["fixture_untyped_plugin_id", "method plugin_id return expected String, found Nil"],
	"res://tests/fixtures/plugins/mechanics/wrong_plugin_id_return": ["fixture_wrong_plugin_id_return", "method plugin_id return expected String, found StringName"],
	"res://tests/fixtures/plugins/mechanics/wrong_plugin_id_arity": ["fixture_wrong_plugin_id_arity", "method plugin_id expected 0 arguments, found 1"],
	"res://tests/fixtures/plugins/mechanics/unknown_hook": ["fixture_unknown_hook", "unknown hook 'during_round'"],
}
const EXPECTED_ALLOWED_HOOKS: Array[StringName] = [
	&"on_battle_start",
	&"before_damage",
	&"after_damage",
	&"after_hit",
	&"after_cross_damage",
	&"attacker_after_hit",
	&"after_element",
	&"on_death",
	&"on_shield_break",
	&"after_ally_death",
	&"after_kill",
	&"after_action",
	&"battle_end",
	&"round_start",
	&"round_end",
	&"project_element_settlement",
	&"project_trap_entry",
	&"project_threat_redirect",
	&"project_death_preview",
]
const EXPECTED_HOOK_ARGUMENT_TYPES := {
	"on_battle_start": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"before_damage": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_STRING, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_damage": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_hit": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_cross_damage": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_STRING, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"attacker_after_hit": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_STRING, TYPE_STRING, TYPE_DICTIONARY],
	"after_element": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_STRING, TYPE_INT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"on_death": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"on_shield_break": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_ally_death": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_kill": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_action": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"battle_end": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_BOOL, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"round_start": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_STRING, TYPE_DICTIONARY],
	"round_end": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_STRING, TYPE_DICTIONARY],
	"project_element_settlement": [TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"project_trap_entry": [TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"project_threat_redirect": [TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"project_death_preview": [TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
}
const EXPECTED_HOOK_RETURN_TYPES := {
	"on_battle_start": TYPE_ARRAY,
	"before_damage": TYPE_DICTIONARY,
	"after_damage": TYPE_ARRAY,
	"after_hit": TYPE_ARRAY,
	"after_cross_damage": TYPE_ARRAY,
	"attacker_after_hit": TYPE_ARRAY,
	"after_element": TYPE_ARRAY,
	"on_death": TYPE_ARRAY,
	"on_shield_break": TYPE_ARRAY,
	"after_ally_death": TYPE_ARRAY,
	"after_kill": TYPE_ARRAY,
	"after_action": TYPE_ARRAY,
	"battle_end": TYPE_DICTIONARY,
	"round_start": TYPE_ARRAY,
	"round_end": TYPE_ARRAY,
	"project_element_settlement": TYPE_DICTIONARY,
	"project_trap_entry": TYPE_DICTIONARY,
	"project_threat_redirect": TYPE_DICTIONARY,
	"project_death_preview": TYPE_DICTIONARY,
}
const EXPECTED_PRODUCTION_HOOKS := {
	"mech_shield_flat": [&"on_battle_start"],
	"mech_armor_flat": [&"before_damage"],
	"mech_damage_reduce_pct": [&"before_damage"],
	"mech_first_hit_immunity": [&"before_damage"],
	"mech_damage_cap_per_round": [&"before_damage"],
	"mech_element_barrier": [&"before_damage"],
	"mech_last_stand_shield": [&"after_damage"],
	"mech_rage_low_hp": [&"after_damage"],
	"mech_second_phase": [&"after_damage"],
	"mech_counter_damage": [&"after_hit"],
	"mech_thorn_shield": [&"after_hit"],
	"mech_thorns_percent": [&"after_hit"],
	"mech_reflect_first_hit": [&"after_hit"],
	"mech_harden_when_hit": [&"after_hit"],
	"mech_soften_when_hit": [&"after_hit"],
	"mech_on_hit_blast": [&"after_hit"],
	"mech_counter_attack": [&"after_hit"],
	"mech_summon_when_hit": [&"after_hit"],
	"mech_retaliate_summon": [&"after_hit"],
	"mech_wind_push_on_hit": [&"attacker_after_hit"],
	"mech_wind_slow_ap": [&"attacker_after_hit"],
	"mech_water_heal_on_layer": [&"after_element"],
	"mech_earth_shield_on_layer": [&"after_element"],
	"mech_summon_on_empty_cell": [&"after_element"],
	"mech_summon_trap": [&"after_element"],
	"mech_dirty_cell": [&"after_element"],
	"mech_earth_block_cell": [&"after_element"],
	"mech_consume_layers_grow": [&"after_element"],
	"mech_death_explosion": [&"on_death", &"project_death_preview"],
	"mech_self_destruct": [&"on_death", &"round_end", &"project_death_preview"],
	"mech_shield_break_explosion": [&"on_death", &"on_shield_break", &"project_death_preview"],
	"mech_death_summon": [&"on_death"],
	"mech_split_into_minions": [&"on_death"],
	"mech_revenge_buff": [&"after_ally_death"],
	"mech_summon_after_kill": [&"after_kill"],
	"mech_copy_weak_self": [&"after_action"],
	"mech_summon_wall": [&"after_action"],
	"mech_elite_reward_bonus": [&"battle_end"],
	"mech_shop_discount_after_clear": [&"battle_end"],
	"mech_bonus_reward_under_round5": [&"battle_end"],
	"mech_curse_gold_loss": [&"battle_end"],
	"mech_reduce_reward_if_alive": [&"battle_end"],
	"mech_shield_regen": [&"round_start"],
	"mech_grow_shield_each_round": [&"round_start"],
	"mech_grow_atk_each_round": [&"round_start"],
	"mech_enrage_after_round": [&"round_start"],
	"mech_delayed_powerup": [&"round_start"],
	"mech_scale_with_allies": [&"round_start"],
	"mech_water_cleanse_debuff": [&"round_start"],
	"mech_countdown_pressure": [&"round_start"],
	"mech_summon_each_round": [&"round_start"],
	"mech_hatch_after_rounds": [&"round_end"],
	"mech_fire_ignite_bonus": [&"project_element_settlement"],
	"mech_multi_element_bonus": [&"project_element_settlement"],
	"mech_fire_cross_detonate_diamond": [&"project_element_settlement"],
	"mech_trap_stack_trigger": [&"project_trap_entry"],
	"mech_guard_taunt": [&"project_threat_redirect"],
}
const SERVICE_PATHS := [
	"res://core/battle/mechanics/damage_mechanic_service.gd",
	"res://core/battle/mechanics/element_mechanic_service.gd",
	"res://core/battle/mechanics/unit_lifecycle_mechanic_service.gd",
	"res://core/battle/round_lifecycle_service.gd",
]

var _failed := false


class FixtureDamagePort extends RefCounted:
	var definitions := {}
	var mechanic_scans := 0

	func contract_id() -> StringName:
		return &"ysbzs.damage-mechanic-port.v2"

	func mechanic_ids(unit: Dictionary) -> Array:
		mechanic_scans += 1
		return Array(unit.get("mechanics", []))

	func mechanism(mechanism_id: String) -> Dictionary:
		return Dictionary(definitions.get(mechanism_id, {"id": mechanism_id}))

	func mechanic_param_int(_unit: Dictionary, _definition: Dictionary, _key: String, fallback: int) -> int:
		return fallback

	func mechanic_param_float(_unit: Dictionary, _definition: Dictionary, _key: String, fallback: float) -> float:
		return fallback

	func mechanic_param_string(_unit: Dictionary, _definition: Dictionary, _key: String, fallback: String) -> String:
		return fallback

	func battle_round() -> int:
		return 1

	func all_units() -> Array:
		return []

	func deal_damage(_source: Dictionary, _target: Dictionary, _amount: int, _element: String, _trace_context: Dictionary = {}, _damage_props: Variant = {}) -> Dictionary:
		return {}

	func resolve_damage_deaths(_candidates: Array) -> Array:
		return []

	func resolved_stat_value(_unit: Dictionary, _stat_id: String, _context: Dictionary) -> int:
		return 0

	func first_adjacent_empty_cell(_unit: Dictionary) -> Dictionary:
		return {}

	func summon_unit_on_cell(_caster: Dictionary, _definition: Dictionary, _cell: Dictionary, _summon_id: String, _display_name: String, _hp: int, _atk: int) -> Dictionary:
		return {}

	func direction_delta(_direction: String) -> Vector2i:
		return Vector2i.ZERO

	func inside(_x: int, _y: int) -> bool:
		return false

	func unit_at(_x: int, _y: int) -> Dictionary:
		return {}


func _initialize() -> void:
	_verify_typed_contract_table()
	_verify_production_inventory()
	_verify_discovery_and_runtime_alias()
	_verify_invalid_registries_fail_closed()
	_verify_static_boundaries()
	if _failed:
		quit(1)
		return
	print("SMOKE_MECHANIC_HANDLER_DISCOVERY_OK production=%d invalid=%d" % [EXPECTED_PRODUCTION_HOOKS.size(), INVALID_CASES.size()])
	quit(0)


func _verify_typed_contract_table() -> void:
	_expect(MechanicHandlerRegistryScript.ALLOWED_HOOKS == EXPECTED_ALLOWED_HOOKS, "registry exposes the exact 19 frozen hooks")
	_expect(MechanicHandlerRegistryScript.HOOK_ARITIES.size() == 19, "all 19 hooks have an exact arity")
	_expect(MechanicHandlerRegistryScript.HOOK_ARGUMENT_TYPES.size() == 19, "all 19 hooks have exact Variant.Type contracts")
	_expect(MechanicHandlerRegistryScript.HOOK_ARGUMENT_CLASSES.size() == 19, "all 19 hooks have exact object class contracts")
	_expect(MechanicHandlerRegistryScript.HOOK_RETURN_TYPES.size() == 19, "all 19 hooks have exact return contracts")
	_expect(MechanicHandlerRegistryScript.PLUGIN_ID_ARITY == 0, "plugin_id arity is exactly zero")
	_expect(MechanicHandlerRegistryScript.PLUGIN_ID_RETURN_TYPE == TYPE_STRING, "plugin_id return is exactly String")
	for hook in EXPECTED_ALLOWED_HOOKS:
		var hook_name := String(hook)
		var expected_types := Array(EXPECTED_HOOK_ARGUMENT_TYPES[hook_name])
		var actual_types := Array(MechanicHandlerRegistryScript.HOOK_ARGUMENT_TYPES.get(hook_name, []))
		var actual_classes := Array(MechanicHandlerRegistryScript.HOOK_ARGUMENT_CLASSES.get(hook_name, []))
		_expect(actual_types == expected_types, "%s keeps its exact argument Variant.Type contract" % hook_name)
		_expect(int(MechanicHandlerRegistryScript.HOOK_ARITIES.get(hook_name, -1)) == expected_types.size(), "%s arity matches its typed arguments" % hook_name)
		_expect(actual_classes.size() == expected_types.size(), "%s class-name contract covers every argument" % hook_name)
		_expect(int(MechanicHandlerRegistryScript.HOOK_RETURN_TYPES.get(hook_name, -1)) == int(EXPECTED_HOOK_RETURN_TYPES[hook_name]), "%s keeps its exact return type" % hook_name)
		for argument_index in expected_types.size():
			var expected_class := &"RefCounted" if argument_index == 0 and int(expected_types[argument_index]) == TYPE_OBJECT else &""
			_expect(StringName(actual_classes[argument_index]) == expected_class, "%s argument %d keeps its exact object class" % [hook_name, argument_index])


func _verify_production_inventory() -> void:
	var registry: RefCounted = MechanicHandlerRegistryScript.new()
	_expect(registry.is_valid(), "production handler registry is valid: %s" % " | ".join(registry.validation_errors()))
	for mechanism_id_value in EXPECTED_PRODUCTION_HOOKS.keys():
		var mechanism_id := String(mechanism_id_value)
		var handler: RefCounted = registry.handler_for(mechanism_id, {"id": mechanism_id})
		_expect(handler != null, "production handler is discovered for %s" % mechanism_id)
		if handler == null:
			continue
		for hook_value in Array(EXPECTED_PRODUCTION_HOOKS[mechanism_id]):
			var hook := StringName(hook_value)
			_expect(registry.supports(handler, hook), "%s supports %s" % [mechanism_id, String(hook)])


func _verify_discovery_and_runtime_alias() -> void:
	var registry: RefCounted = MechanicHandlerRegistryScript.new(VALID_DIRECTORY)
	_expect(registry.is_valid(), "new fixture plugins are discovered without registry edits")
	var started := {}
	var start_handler: RefCounted = registry.handler_for("fixture_battle_start", {})
	_expect(start_handler != null and registry.supports(start_handler, &"on_battle_start"), "new lifecycle hook resolves by plugin id")
	if start_handler != null:
		_expect(start_handler.on_battle_start(null, started, {}) == ["fixture battle start"] and bool(started.get("fixture_started", false)), "discovered lifecycle hook executes")
	var shared: RefCounted = registry.handler_for("fixture_new_mechanism", {"runtime_handler": "fixture_shared_before_damage"})
	_expect(shared != null and registry.supports(shared, &"before_damage"), "runtime_handler selects a shared repository-owned handler")
	if shared != null:
		var result := Dictionary(shared.before_damage(null, {}, {}, 7, "火", {}, {}))
		_expect(result == {"damage": 5, "logs": ["fixture shared"]}, "shared runtime handler preserves its typed hook result")
	_expect(registry.handler_for("missing", {"runtime_handler": "res://user/script.gd"}) == null, "data cannot select a script path")
	var port := FixtureDamagePort.new()
	port.definitions["fixture_new_mechanism"] = {"id": "fixture_new_mechanism", "runtime_handler": "fixture_shared_before_damage"}
	var service: RefCounted = DamageMechanicServiceScript.new(VALID_DIRECTORY)
	var service_result := Dictionary(service.apply_before_damage(
		port,
		{"mechanics": ["fixture_new_mechanism"]},
		{},
		7,
		"火",
		DamagePropsScript.move_damage()
	))
	_expect(service_result == {"damage": 5, "logs": ["fixture shared"]}, "new mechanism data composes through the unchanged Service loop")
	var invalid_service: RefCounted = DamageMechanicServiceScript.new("res://tests/fixtures/plugins/mechanics/zero_hook")
	var invalid_result := Dictionary(invalid_service.apply_before_damage(port, {"mechanics": ["fixture_new_mechanism"]}, {}, 7))
	_expect(invalid_result == {"damage": 7, "logs": []} and port.mechanic_scans == 1, "invalid registry fails closed before a second mechanic scan or mutation")


func _verify_invalid_registries_fail_closed() -> void:
	for directory_value in INVALID_CASES.keys():
		var directory := String(directory_value)
		var case := Array(INVALID_CASES[directory])
		var registry: RefCounted = MechanicHandlerRegistryScript.new(directory)
		_expect(not registry.is_valid(), "%s invalidates the whole registry" % directory)
		_expect(registry.handler_for(String(case[0]), {}) == null, "%s exposes no partial handler" % directory)
		_expect("\n".join(registry.validation_errors()).contains(String(case[1])), "%s reports its deterministic contract error" % directory)


func _verify_static_boundaries() -> void:
	for path in SERVICE_PATHS:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains('"mech_'), "%s contains no business mechanism id literal" % path)
		_expect(source.contains("MechanicHandlerRegistryScript"), "%s delegates hook discovery to MechanicHandlerRegistry" % path)
	var registry_source := FileAccess.get_file_as_string("res://core/battle/mechanics/mechanic_handler_registry.gd")
	_expect(registry_source.contains('mechanism.get("runtime_handler", mechanism_id)'), "handler selection is data-driven by stable id")
	_expect(not registry_source.contains("load(handler_id)"), "handler id is never interpreted as a script path")
	for path in _gd_files("res://core/battle/mechanics/handlers"):
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("core/state/game_state.gd") and not source.contains("YsbzsState"), "%s has no authority dependency" % path)
		_expect(not source.contains("FileAccess") and not source.contains("DirAccess"), "%s has no persistence or discovery side channel" % path)


func _gd_files(root: String) -> Array[String]:
	var result: Array[String] = []
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var current := String(directories.pop_front())
		var directory := DirAccess.open(current)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry := directory.get_next()
		while entry != "":
			if entry != "." and entry != "..":
				var path := "%s/%s" % [current, entry]
				if directory.current_is_dir():
					directories.append(path)
				elif entry.ends_with(".gd"):
					result.append(path)
			entry = directory.get_next()
		directory.list_dir_end()
	result.sort()
	return result


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_MECHANIC_HANDLER_DISCOVERY_FAIL: %s" % label)
