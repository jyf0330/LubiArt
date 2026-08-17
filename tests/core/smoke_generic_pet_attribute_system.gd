extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const StatCatalogServiceScript := preload("res://core/stats/stat_catalog_service.gd")
const StatResolverScript := preload("res://core/stats/stat_resolver.gd")
const ConditionEvaluatorScript := preload("res://core/effects/condition_evaluator.gd")
const StatusServiceScript := preload("res://core/effects/status_service.gd")
const EffectInterpreterScript := preload("res://core/effects/effect_interpreter.gd")
const TraitServiceScript := preload("res://core/battle/traits/trait_service.gd")

var failed := false


class FakeEffectPort extends RefCounted:
	var calls: Array = []

	func apply_status(context: Dictionary, effect: Dictionary) -> void:
		calls.append({"type": "apply_status", "context": context, "effect": effect})

	func apply_stat_modifier(context: Dictionary, effect: Dictionary) -> void:
		calls.append({"type": "modify_stat", "context": context, "effect": effect})

	func log(message: String) -> void:
		calls.append({"type": "log", "message": message})


func _initialize() -> void:
	var state := StateScript.new()
	var data := Dictionary(state.game_data)
	var stat_catalog := Dictionary(data.get("stat_catalog", {}))
	var status_catalog := Dictionary(data.get("status_catalog", {}))
	_expect(stat_catalog.size() >= 40, "exported catalog supports dozens of stat categories")
	_expect(status_catalog.size() >= 8, "exported catalog includes reusable status types")
	_verify_stat_resolution(stat_catalog)
	_verify_conditions(stat_catalog)
	_verify_statuses(status_catalog, stat_catalog)
	_verify_effect_interpreter()
	_verify_trait_adapter(data, stat_catalog)
	_verify_snapshot(state)
	if failed:
		quit(1)
		return
	print("SMOKE_GENERIC_PET_ATTRIBUTE_SYSTEM_OK stats=%d statuses=%d" % [stat_catalog.size(), status_catalog.size()])
	quit(0)


func _verify_stat_resolution(catalog: Dictionary) -> void:
	var catalog_service := StatCatalogServiceScript.new()
	_expect(int(catalog_service.definition(catalog, "physical_power_permille").get("default_value", 0)) == 1000, "catalog exposes typed defaults")
	var resolver := StatResolverScript.new()
	var unit := {
		"id": "unit_stats",
		"atk": 10,
		"permanent_modifiers": [
			{"stat": "atk", "operation": "flat_add", "value": 2, "phase": "permanent", "source_id": "training", "priority": 20},
		],
		"equipment_modifiers": [
			{"stat": "atk", "operation": "percent_add", "value": 100, "phase": "equipment", "source_id": "ring", "priority": 10},
		],
	}
	var extras := [
		{"stat": "atk", "operation": "flat_add", "value": 4, "phase": "status", "source_id": "fury", "priority": 100},
		{"stat": "atk", "operation": "multiplier", "value": 1500, "phase": "trait", "source_id": "giant", "priority": 100},
	]
	var resolved := resolver.resolve(unit, "atk", catalog, extras)
	_expect(int(resolved.get("value", -1)) == 27, "resolver applies flat, percent and multiplier stages deterministically")
	_expect(Array(resolved.get("breakdown", [])).size() == 5, "resolver returns auditable base plus modifier breakdown")
	var reversed := extras.duplicate(true)
	reversed.reverse()
	_expect(int(resolver.resolve(unit, "atk", catalog, reversed).get("value", -1)) == 27, "modifier input order cannot change the result")
	_expect(int(resolver.value({}, "crit_damage_permille", catalog)) == 1500, "missing runtime values use catalog defaults")
	var capped := resolver.resolve({"crit_rate_permille": 950}, "crit_rate_permille", catalog, [
		{"stat": "crit_rate_permille", "operation": "flat_add", "value": 200, "source_id": "focus"},
	])
	_expect(int(capped.get("value", -1)) == 1000, "catalog maximum clamps resolved values")


func _verify_conditions(catalog: Dictionary) -> void:
	var evaluator := ConditionEvaluatorScript.new()
	var unit := {"hp": 20, "max_hp": 100, "element": "火", "tags": ["melee", "small"], "atk": 10}
	var context := {"unit": unit, "hook": "skill", "source_kind": "skill", "round": 3, "stat_catalog": catalog}
	_expect(evaluator.matches({"type": "hp_percent_below", "value": 500}, context), "condition evaluator handles hp thresholds")
	_expect(evaluator.matches({"type": "unit_has_tag", "value": "melee"}, context), "condition evaluator handles tags")
	_expect(evaluator.matches({"type": "all", "conditions": [
		{"type": "hook_is", "value": "skill"},
		{"type": "unit_element_is", "value": "火"},
	]}, context), "condition evaluator composes nested all conditions")
	_expect(not evaluator.matches({"type": "stat_compare", "stat": "atk", "operator": ">", "value": 20}, context), "condition evaluator compares resolved stats")


func _verify_statuses(status_catalog: Dictionary, stat_catalog: Dictionary) -> void:
	var service := StatusServiceScript.new()
	var unit := {"id": "status_unit", "atk": 10, "statuses": []}
	_expect(service.apply(unit, "status_fury", status_catalog, 2, 1, "skill_a", 7), "status can be applied from catalog")
	_expect(service.apply(unit, "status_fury", status_catalog, 2, 3, "skill_b", 8), "reapplying status stacks and refreshes")
	var statuses := Array(unit.get("statuses", []))
	_expect(statuses.size() == 1, "same status keeps one authoritative instance")
	_expect(int(Dictionary(statuses[0]).get("stacks", 0)) == 3, "status stacks clamp to catalog maximum")
	_expect(int(Dictionary(statuses[0]).get("remaining_rounds", 0)) == 3, "refresh policy keeps the longest duration")
	var modifiers := service.modifiers(unit, status_catalog, "skill", {"unit": unit})
	_expect(modifiers.size() == 1 and int(Dictionary(modifiers[0]).get("value", 0)) == 6, "per-stack status modifier is materialized deterministically")
	var resolver := StatResolverScript.new()
	_expect(int(resolver.value(unit, "atk", stat_catalog, modifiers)) == 16, "status modifiers flow through the common stat resolver")
	service.advance_round(unit, status_catalog)
	_expect(int(Dictionary(Array(unit.get("statuses", []))[0]).get("remaining_rounds", 0)) == 2, "status duration advances in authoritative state")
	service.advance_round(unit, status_catalog, 2)
	_expect(Array(unit.get("statuses", [])).is_empty(), "expired status instances are removed")


func _verify_effect_interpreter() -> void:
	var interpreter := EffectInterpreterScript.new()
	var port := FakeEffectPort.new()
	var ok := interpreter.execute(port, {"unit": {"id": "effect_unit"}}, [
		{"type": "apply_status", "status_id": "status_fury", "stacks": 1},
		{"type": "modify_stat", "stat": "atk", "operation": "flat_add", "value": 2},
	])
	_expect(ok, "effect interpreter accepts registered operations")
	_expect(port.calls.size() == 2, "effect interpreter dispatches ordered effects through a narrow port")
	_expect(not interpreter.execute(port, {}, [{"type": "arbitrary_script", "path": "res://bad.gd"}]), "unregistered data operations are rejected")


func _verify_trait_adapter(data: Dictionary, stat_catalog: Dictionary) -> void:
	var service := TraitServiceScript.new()
	var result := service.modifiers({"traits": ["trait_relentless"]}, Dictionary(data.get("trait_catalog", {})), "skill")
	var modifiers := Array(result.get("modifiers", []))
	_expect(modifiers.size() == 1, "traits expose generic modifier specs")
	_expect(String(Dictionary(modifiers[0]).get("stat", "")) == "physical_power_permille", "trait modifier targets a catalog stat id")
	var resolver := StatResolverScript.new()
	_expect(int(resolver.value({}, "physical_power_permille", stat_catalog, modifiers, {"hook": "skill"})) == 1100, "generic trait modifier preserves legacy +10% semantics at its declared hook")
	_expect(int(result.get("physical_power_bonus_permille", 0)) == 100, "legacy skill adapter remains compatible during migration")


func _verify_snapshot(state: RefCounted) -> void:
	_expect(state.dispatch({"type": "START_BATTLE"}), "snapshot fixture starts battle")
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and int(unit.get("hp", 0)) > 0:
			state.selected_unit_id = String(unit.get("id", ""))
			unit["statuses"] = [{"status_id": "status_fury", "stacks": 1, "remaining_rounds": 2, "source_id": "fixture", "applied_seq": 1}]
			break
	var snap: Dictionary = state.snapshot()
	_expect(Dictionary(snap.get("statCatalog", {})).size() >= 40, "snapshot exposes the typed stat catalog")
	_expect(Dictionary(snap.get("statusCatalog", {})).size() >= 8, "snapshot exposes status definitions")
	_expect(Dictionary(snap.get("selectedResolvedStats", {})).has("atk"), "snapshot projects selected-pet resolved stats")
	_expect(Dictionary(snap.get("selectedStatBreakdown", {})).has("atk"), "snapshot projects an auditable stat breakdown")
	_expect(Array(snap.get("selectedStatuses", [])).size() == 1, "snapshot projects authoritative status instances")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
