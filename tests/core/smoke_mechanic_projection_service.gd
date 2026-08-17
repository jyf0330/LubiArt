extends SceneTree

const MechanicHandlerRegistryScript := preload("res://core/battle/mechanics/mechanic_handler_registry.gd")
const MechanicProjectionServiceScript := preload("res://core/battle/mechanics/mechanic_projection_service.gd")
const BattleTraceFactoryScript := preload("res://core/battle/battle_trace_factory.gd")
const DeathExplosionScript := preload("res://core/battle/mechanics/handlers/mech_death_explosion.gd")
const SelfDestructScript := preload("res://core/battle/mechanics/handlers/mech_self_destruct.gd")
const ShieldBreakExplosionScript := preload("res://core/battle/mechanics/handlers/mech_shield_break_explosion.gd")

var failed := false


class FixtureProjectionHandler extends RefCounted:
	var seen_facts: Dictionary = {}

	func project_element_settlement(unit: Dictionary, _mechanism: Dictionary, facts: Dictionary) -> Dictionary:
		seen_facts = facts.duplicate(true)
		return {
			"exclusive_key": "fixture_bonus",
			"damage_add": 2,
			"source": unit.duplicate(true),
			"target_pattern": "single",
		}


class MutatingProjectionHandler extends RefCounted:
	func project_element_settlement(unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
		unit["mutated"] = true
		return {
			"exclusive_key": "mutating",
			"damage_add": 1,
			"source": {},
			"target_pattern": "",
		}


class BadElementProjectionHandler extends RefCounted:
	func project_element_settlement(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
		return {
			"exclusive_key": "bad",
			"damage_add": 1,
			"source": {},
			"target_pattern": "",
			"extra": true,
		}


class NonFiniteElementProjectionHandler extends RefCounted:
	func project_element_settlement(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
		return {
			"exclusive_key": "nonfinite",
			"damage_add": 1,
			"source": {"invalid": INF},
			"target_pattern": "",
		}


class BadTrapProjectionHandler extends RefCounted:
	func project_trap_entry(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
		return {"allow": 1}


class BadThreatProjectionHandler extends RefCounted:
	func project_threat_redirect(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
		return {"range": 1, "mechanic_id": "bad", "mechanic_name": "bad", "extra": true}


class BadDeathProjectionHandler extends RefCounted:
	func project_death_preview(_unit: Dictionary, _mechanism: Dictionary, _facts: Dictionary) -> Dictionary:
		return {"radius": 1.0, "metric": "manhattan", "damage": 1}


class FakeProjectionRegistry extends RefCounted:
	var valid := true
	var handler: RefCounted

	func _init(value: RefCounted = null, is_valid_value: bool = true) -> void:
		handler = value
		valid = is_valid_value

	func is_valid() -> bool:
		return valid

	func handler_for(_mechanism_id: String, _mechanism: Dictionary) -> RefCounted:
		return handler

	func supports(value: RefCounted, hook: StringName) -> bool:
		return value != null and value.has_method(hook)


class FakeLifecyclePort extends RefCounted:
	var trace_contexts: Array = []

	func contract_id() -> StringName:
		return &"ysbzs.unit-lifecycle-mechanic-port.v1"

	func mechanic_param_int(_unit: Dictionary, _mechanism: Dictionary, _key: String, fallback: int) -> int:
		return fallback

	func cross_damage(
		_unit: Dictionary,
		_source: Dictionary,
		_damage: int,
		_element: String,
		_label: String,
		trace_context: Dictionary
	) -> Dictionary:
		trace_contexts.append(trace_context.duplicate(true))
		return {"logs": [], "hit_count": 1}


class FakeRoundPort extends RefCounted:
	var trace_contexts: Array = []

	func contract_id() -> StringName:
		return &"ysbzs.round-lifecycle-port.v1"

	func mechanic_param_int(_unit: Dictionary, _mechanism: Dictionary, _key: String, fallback: int) -> int:
		return fallback

	func apply_cross_damage(
		_unit: Dictionary,
		_source: Dictionary,
		_damage: int,
		_element: String,
		_label: String,
		trace_context: Dictionary
	) -> Dictionary:
		trace_contexts.append(trace_context.duplicate(true))
		return {"logs": [], "hit_count": 1}


func _initialize() -> void:
	var registry := MechanicHandlerRegistryScript.new()
	_expect(registry.is_valid(), "57-handler production registry passes the typed hook gate: %s" % [registry.validation_errors()])
	_expect(_production_handler_count() == 57, "production handler inventory is exactly 57")
	var service := MechanicProjectionServiceScript.new().configure(registry)
	_test_element_projection(service)
	_test_trap_projection(service)
	_test_threat_projection(service)
	_test_death_projection(service)
	_test_extension_and_fail_closed()
	_test_execution_source_labels()
	if failed:
		quit(1)
		return
	print("SMOKE_MECHANIC_PROJECTION_SERVICE_OK")
	quit(0)


func _test_element_projection(service: RefCounted) -> void:
	var mechanisms := _mechanisms()
	var units := [
		{"id": "ignite-first", "name": "点燃一号", "hp": 5, "mechanics": ["mech_fire_ignite_bonus"], "mechanic_params": {"per_layer": 2}},
		{"id": "ignite-second", "name": "点燃二号", "hp": 5, "mechanics": ["mech_fire_ignite_bonus"], "mechanic_params": {"per_layer": 9}},
		{"id": "multi", "name": "多元素", "hp": 5, "mechanics": ["mech_multi_element_bonus"]},
		{"id": "cross-first", "name": "十字一号", "hp": 5, "element": "火", "quality": "diamond", "mechanics": ["mech_fire_cross_detonate_diamond"]},
		{"id": "cross-second", "name": "十字二号", "hp": 5, "element": "火", "quality": "钻石", "mechanics": ["mech_fire_cross_detonate_diamond"]},
		{"id": "dead", "hp": 0, "mechanics": ["mech_fire_ignite_bonus"]},
	]
	var elements := {"火": 4, "水": 1}
	var units_before := units.duplicate(true)
	var mechanisms_before := mechanisms.duplicate(true)
	var elements_before := elements.duplicate(true)
	var plan := Dictionary(service.element_settlement_plan(units, mechanisms, elements, "火"))
	_expect(plan.keys().size() == 6 and _has_keys(plan, ["ok", "base_damage", "damage", "source", "target_pattern", "contributions"]), "element plan uses the exact six-key return contract")
	_expect(bool(plan.get("ok", false)) and int(plan.get("base_damage", -1)) == 10, "element base damage is triangular ElementBurstPolicy damage")
	_expect(int(plan.get("damage", -1)) == 21, "ignite and multi additions are accumulated after triangular base")
	_expect(String(plan.get("target_pattern", "")) == "cross", "diamond fire projection selects cross")
	_expect(String(Dictionary(plan.get("source", {})).get("id", "")) == "cross-first", "first target-pattern source outranks earlier damage-add sources")
	var contributions := Array(plan.get("contributions", []))
	_expect(contributions.size() == 4, "ignite exclusive key deduplicates while both cross projections remain observable")
	for contribution_value in contributions:
		var contribution := Dictionary(contribution_value)
		_expect(contribution.keys().size() == 4 and _has_keys(contribution, ["exclusive_key", "damage_add", "source", "target_pattern"]), "each accepted contribution has exact keys")
	_expect(_deep_equal(units, units_before) and _deep_equal(mechanisms, mechanisms_before) and _deep_equal(elements, elements_before), "element projection leaves all caller inputs deep-equal")
	Dictionary(plan.get("source", {}))["name"] = "mutated-result"
	if not Array(plan.get("contributions", [])).is_empty():
		Dictionary(Array(plan.get("contributions", []))[0]).get("source", {})["name"] = "mutated-contribution"
	_expect(_deep_equal(units, units_before), "element plan sources are detached deep copies")

	var plain_plan := Dictionary(service.element_settlement_plan(
		[{"id": "multi", "hp": 1, "mechanics": ["mech_multi_element_bonus"]}],
		mechanisms,
		{"水": 3},
		"水"
	))
	_expect(int(plain_plan.get("damage", -1)) == 6 and Array(plain_plan.get("contributions", [])).is_empty(), "multi-element bonus stays inactive below two active element types")
	var zero_add_plan := Dictionary(service.element_settlement_plan(
		[{"id": "multi-zero", "hp": 1, "mechanics": ["mech_multi_element_bonus"], "mechanic_params": {"bonus": 0}}],
		mechanisms,
		{"水": 3, "火": 1},
		"水"
	))
	_expect(String(Dictionary(zero_add_plan.get("source", {})).get("id", "")) == "multi-zero", "first nonempty add source wins even when its exact damage addition is zero")


func _test_trap_projection(service: RefCounted) -> void:
	var mechanisms := _mechanisms()
	var trap_unit := {"id": "trap", "hp": 4, "mechanics": ["mech_trap_stack_trigger"]}
	var before := trap_unit.duplicate(true)
	_expect(service.trap_entry_allowed(trap_unit, mechanisms, false), "trap handler opts a non-enemy carrier into trap settlement")
	_expect(_deep_equal(trap_unit, before), "trap projection leaves its unit deep-equal")
	_expect(service.trap_entry_allowed({"id": "enemy", "hp": 4}, mechanisms, true), "enemy default is preserved without a mechanic")
	_expect(not service.trap_entry_allowed({"id": "player", "hp": 4}, mechanisms, false), "non-enemy without opt-in remains disallowed")
	_expect(not service.trap_entry_allowed({"id": "missing", "mechanics": ["missing"]}, mechanisms, true), "missing trap definition fails closed instead of preserving a permissive default")


func _test_threat_projection(service: RefCounted) -> void:
	var mechanisms := _mechanisms()
	var units := [
		{"id": "guard", "side": "player", "hp": 5, "x": 1, "y": 2, "mechanics": ["mech_guard_taunt"], "mechanic_params": {"range": 3}},
		{"id": "enemy-guard", "side": "enemy", "hp": 5, "mechanics": ["mech_guard_taunt"]},
		{"id": "dead-guard", "side": "player", "hp": 0, "mechanics": ["mech_guard_taunt"]},
	]
	var facts := {"enemy": {"id": "enemy", "side": "enemy", "x": 2, "y": 2}}
	var units_before := units.duplicate(true)
	var facts_before := facts.duplicate(true)
	var candidates: Array = service.threat_candidates(units, mechanisms, facts)
	_expect(candidates.size() == 1, "threat projection includes only living player guards")
	var candidate := Dictionary(candidates[0]) if not candidates.is_empty() else {}
	_expect(candidate.keys().size() == 4 and _has_keys(candidate, ["target", "range", "mechanic_id", "mechanic_name"]), "threat service adds target to the exact handler result")
	_expect(int(candidate.get("range", -1)) == 3 and String(candidate.get("mechanic_id", "")) == "mech_guard_taunt" and String(candidate.get("mechanic_name", "")) == "嘲讽守护", "guard projection preserves configured range and catalog identity")
	_expect(_deep_equal(units, units_before) and _deep_equal(facts, facts_before), "threat projection leaves units and facts deep-equal")
	Dictionary(candidate.get("target", {}))["hp"] = 0
	_expect(_deep_equal(units, units_before), "threat candidate target is a detached deep copy")
	_expect(service.threat_candidates(units, mechanisms, {"enemy": {}, "extra": true}).is_empty(), "threat facts with extra keys fail closed")
	var alias_mechanisms := mechanisms.duplicate(true)
	alias_mechanisms.append({
		"id": "mech_guard_taunt_alias",
		"name": "别名守护",
		"runtime_handler": "mech_guard_taunt",
		"default_params": "range=4",
	})
	var alias_candidates: Array = service.threat_candidates(
		[{"id": "alias-guard", "side": "player", "hp": 5, "mechanics": ["mech_guard_taunt_alias"]}],
		alias_mechanisms,
		facts
	)
	var alias_candidate := Dictionary(alias_candidates[0]) if alias_candidates.size() == 1 else {}
	_expect(
		String(alias_candidate.get("mechanic_id", "")) == "mech_guard_taunt_alias"
		and String(alias_candidate.get("mechanic_name", "")) == "别名守护"
		and int(alias_candidate.get("range", -1)) == 4,
		"guard runtime handler preserves alias mechanism ID, name and parameters"
	)


func _test_death_projection(service: RefCounted) -> void:
	var mechanisms := _mechanisms()
	var unit := {
		"id": "exploder",
		"hp": 1,
		"mechanics": ["mech_death_explosion", "mech_self_destruct", "mech_shield_break_explosion"],
	}
	var before := unit.duplicate(true)
	var effects: Array = service.death_preview_effects(unit, mechanisms, {"projected_dead": true})
	_expect(effects == [
		{"radius": 1, "metric": "manhattan", "damage": 6},
		{"radius": 1, "metric": "manhattan", "damage": 8},
		{"radius": 1, "metric": "manhattan", "damage": 5},
	], "death preview preserves mechanic order and all three frozen damage defaults")
	_expect(_deep_equal(unit, before), "death preview leaves its unit deep-equal")
	_expect(service.death_preview_effects(unit, mechanisms, {"projected_dead": false}).is_empty(), "death preview requires the exact projected-dead fact")
	_expect(service.death_preview_effects(unit, mechanisms, {"projected_dead": true, "extra": true}).is_empty(), "death facts with extra keys fail closed")


func _test_extension_and_fail_closed() -> void:
	var fixture := FixtureProjectionHandler.new()
	var fixture_service := MechanicProjectionServiceScript.new().configure(FakeProjectionRegistry.new(fixture))
	var unit := {"id": "fixture", "hp": 1, "mechanics": ["fixture"]}
	var plan := Dictionary(fixture_service.element_settlement_plan([unit], [{"id": "fixture"}], {"火": 3, "水": 1}, "火"))
	_expect(bool(plan.get("ok", false)) and int(plan.get("damage", -1)) == 8 and String(plan.get("target_pattern", "")) == "single", "a fixture handler projects without any consumer edit")
	_expect(fixture.seen_facts == {"element": "火", "layers": 3, "active_element_type_count": 2, "base_damage": 6}, "element hook receives the exact frozen facts")

	var invalid_service := MechanicProjectionServiceScript.new().configure(FakeProjectionRegistry.new(null, false))
	_expect(invalid_service.element_settlement_plan([], [], {}, "火") == {"ok": false}, "invalid registry makes element projection fail closed")
	_expect(not invalid_service.trap_entry_allowed({"id": "unit"}, [], true), "invalid registry makes permissive trap default fail closed")
	_expect(invalid_service.threat_candidates([], [], {"enemy": {}}).is_empty(), "invalid registry makes threat projection fail closed")
	_expect(invalid_service.death_preview_effects({"id": "unit"}, [], {"projected_dead": true}).is_empty(), "invalid registry makes death projection fail closed")

	var missing_service := MechanicProjectionServiceScript.new().configure(FakeProjectionRegistry.new())
	_expect(missing_service.element_settlement_plan([unit], [{"id": "fixture"}], {"火": 3}, "火") == {"ok": false}, "missing handler fails element projection closed")

	var mutating_service := MechanicProjectionServiceScript.new().configure(FakeProjectionRegistry.new(MutatingProjectionHandler.new()))
	var mutating_before := unit.duplicate(true)
	_expect(mutating_service.element_settlement_plan([unit], [{"id": "fixture"}], {"火": 3}, "火") == {"ok": false}, "handler argument mutation is detected and rejected")
	_expect(_deep_equal(unit, mutating_before), "mutating handler cannot reach caller-owned input")

	var bad_element_service := MechanicProjectionServiceScript.new().configure(FakeProjectionRegistry.new(BadElementProjectionHandler.new()))
	_expect(bad_element_service.element_settlement_plan([unit], [{"id": "fixture"}], {"火": 3}, "火") == {"ok": false}, "extra element result keys fail closed")
	var nonfinite_service := MechanicProjectionServiceScript.new().configure(FakeProjectionRegistry.new(NonFiniteElementProjectionHandler.new()))
	_expect(nonfinite_service.element_settlement_plan([unit], [{"id": "fixture"}], {"火": 3}, "火") == {"ok": false}, "non-finite nested return values fail the JSON-compatible gate")
	var bad_trap_service := MechanicProjectionServiceScript.new().configure(FakeProjectionRegistry.new(BadTrapProjectionHandler.new()))
	_expect(not bad_trap_service.trap_entry_allowed(unit, [{"id": "fixture"}], true), "wrong trap allow type fails closed")
	var bad_threat_service := MechanicProjectionServiceScript.new().configure(FakeProjectionRegistry.new(BadThreatProjectionHandler.new()))
	var guard := {"id": "fixture", "side": "player", "hp": 1, "mechanics": ["fixture"]}
	_expect(bad_threat_service.threat_candidates([guard], [{"id": "fixture"}], {"enemy": {}}).is_empty(), "extra threat result keys fail closed")
	var bad_death_service := MechanicProjectionServiceScript.new().configure(FakeProjectionRegistry.new(BadDeathProjectionHandler.new()))
	_expect(bad_death_service.death_preview_effects(unit, [{"id": "fixture"}], {"projected_dead": true}).is_empty(), "wrong death result types fail closed")


func _test_execution_source_labels() -> void:
	var lifecycle_port := FakeLifecyclePort.new()
	DeathExplosionScript.new().on_death(
		lifecycle_port,
		{"id": "death", "name": "死亡", "hp": 0},
		{},
		{"id": "mech_death_explosion", "name": "死亡爆炸"}
	)
	SelfDestructScript.new().on_death(
		lifecycle_port,
		{"id": "self-death", "name": "自爆死亡", "hp": 0},
		{},
		{"id": "mech_self_destruct", "name": "自爆"}
	)
	ShieldBreakExplosionScript.new().on_death(
		lifecycle_port,
		{"id": "shield-death", "name": "破盾死亡", "hp": 0},
		{},
		{"id": "mech_shield_break_explosion", "name": "破盾爆炸"}
	)
	ShieldBreakExplosionScript.new().on_shield_break(
		lifecycle_port,
		{"id": "shield", "name": "破盾", "hp": 1, "flags": {}},
		{},
		{"id": "mech_shield_break_explosion"}
	)
	_expect(lifecycle_port.trace_contexts.size() == 4, "three inherited death hooks and shield-break execution emit trace contexts")
	if lifecycle_port.trace_contexts.size() == 4:
		_expect(Dictionary(lifecycle_port.trace_contexts[0]) == {"sourceType": "mech_death_explosion", "sourceLabel": "死亡爆炸波及"}, "death explosion inherited hook passes exact trace protocol")
		_expect(Dictionary(lifecycle_port.trace_contexts[1]) == {"sourceType": "mech_self_destruct", "sourceLabel": "自爆波及"}, "self-destruct inherited death hook passes exact trace protocol")
		_expect(Dictionary(lifecycle_port.trace_contexts[2]) == {"sourceType": "mech_shield_break_explosion", "sourceLabel": "破盾爆炸波及"}, "shield-break inherited death hook passes exact trace protocol")
		_expect(Dictionary(lifecycle_port.trace_contexts[3]) == {"sourceType": "mech_shield_break_explosion", "sourceLabel": "破盾爆炸波及"}, "shield-break execution passes exact trace protocol")
		_expect_trace_text_and_protocol(Dictionary(lifecycle_port.trace_contexts[0]), "死亡爆炸波及", "death explosion")
		_expect_trace_text_and_protocol(Dictionary(lifecycle_port.trace_contexts[1]), "自爆波及", "self-destruct death")
		_expect_trace_text_and_protocol(Dictionary(lifecycle_port.trace_contexts[2]), "破盾爆炸波及", "shield-break death")
	var round_port := FakeRoundPort.new()
	SelfDestructScript.new().round_end(
		round_port,
		{"id": "self", "name": "自爆", "hp": 1, "flags": {"selfDestructTicks": 1}},
		"enemy",
		{"id": "mech_self_destruct"}
	)
	_expect(round_port.trace_contexts.size() == 1 and Dictionary(round_port.trace_contexts[0]) == {"sourceType": "mech_self_destruct", "sourceLabel": "自爆波及"}, "self-destruct round-end passes exact trace protocol")
	if round_port.trace_contexts.size() == 1:
		_expect_trace_text_and_protocol(Dictionary(round_port.trace_contexts[0]), "自爆波及", "self-destruct round-end")


func _expect_trace_text_and_protocol(trace_context: Dictionary, source_label: String, description: String) -> void:
	var event := BattleTraceFactoryScript.damage_event(
		7,
		2,
		"monster_turn",
		{"id": "source", "name": "爆炸源", "side": "enemy", "x": 1, "y": 1},
		{"id": "target", "name": "目标", "side": "player", "x": 2, "y": 1},
		3,
		0,
		3,
		10,
		7,
		0,
		0,
		"火",
		trace_context
	)
	_expect(
		String(event.get("text", "")) == "爆炸源%s目标造成 3 伤害（护盾 0，生命 3；HP 10→7，护盾 0→0）。" % source_label,
		"%s preserves exact battle-trace text" % description
	)
	_expect(
		String(event.get("protocol", "")) == "|DAMAGE_APPLIED|id=bt_000007|round=2|phase=monster_turn|actor=source|target=target|hp=3|shield=0|element=火",
		"%s preserves exact battle-trace protocol" % description
	)


func _mechanisms() -> Array:
	return [
		{"id": "mech_fire_ignite_bonus", "name": "点燃增伤", "default_params": "per_layer=1"},
		{"id": "mech_multi_element_bonus", "name": "多元素增伤", "default_params": "bonus=3"},
		{"id": "mech_fire_cross_detonate_diamond", "name": "火魔十字", "default_params": "shape=cross5"},
		{"id": "mech_trap_stack_trigger", "name": "陷阱结算", "default_params": "trigger_all=true"},
		{"id": "mech_guard_taunt", "name": "嘲讽守护", "default_params": "range=1"},
		{"id": "mech_death_explosion", "name": "死亡爆炸", "default_params": "damage=6"},
		{"id": "mech_self_destruct", "name": "自爆", "default_params": "rounds=2; damage=8"},
		{"id": "mech_shield_break_explosion", "name": "破盾爆炸", "default_params": "damage=5"},
	]


func _production_handler_count() -> int:
	var count := 0
	for file_name in DirAccess.get_files_at(MechanicHandlerRegistryScript.HANDLER_DIRECTORY):
		if file_name.ends_with(".gd"):
			count += 1
	return count


func _has_keys(value: Dictionary, expected: Array) -> bool:
	for key in expected:
		if not value.has(String(key)):
			return false
	return true


func _deep_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if typeof(left) == TYPE_ARRAY:
		var left_array := Array(left)
		var right_array := Array(right)
		if left_array.size() != right_array.size():
			return false
		for index in left_array.size():
			if not _deep_equal(left_array[index], right_array[index]):
				return false
		return true
	if typeof(left) == TYPE_DICTIONARY:
		var left_dictionary := Dictionary(left)
		var right_dictionary := Dictionary(right)
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key in left_dictionary.keys():
			if not right_dictionary.has(key) or not _deep_equal(left_dictionary[key], right_dictionary[key]):
				return false
		return true
	return left == right


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
