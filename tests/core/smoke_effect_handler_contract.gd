extends SceneTree

const EffectInterpreterScript := preload("res://core/effects/effect_interpreter.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")
const StatIdsScript := preload("res://core/stats/stat_ids.gd")

const HANDLER_CASES := {
	"apply_element_layer": {
		"port_method": "apply_element_layers",
		"effect": {"type": "apply_element_layer", "layers": 2},
		"source_kind": EffectHookIdsScript.SKILL,
		"consumed_stats": [StatIdsScript.ELEMENT_LAYER_BONUS],
		"default_target": EffectVocabularyScript.DEFAULT_ACTION_TARGET,
	},
	"apply_status": {
		"port_method": "apply_status",
		"effect": {"type": "apply_status", "status_id": "status_fixture"},
		"source_kind": EffectHookIdsScript.SKILL,
		"consumed_stats": [StatIdsScript.STATUS_DURATION_PERMILLE, StatIdsScript.STATUS_HIT_PERMILLE],
	},
	"grant_shield": {
		"port_method": "apply_shield",
		"effect": {"type": "grant_shield", "amount": 4},
		"source_kind": EffectHookIdsScript.SKILL,
		"consumed_stats": [StatIdsScript.SHIELD_GAIN_PERMILLE],
	},
	"heal": {
		"port_method": "apply_heal",
		"effect": {"type": "heal", "amount": 4, "scale_with_atk": true},
		"source_kind": EffectHookIdsScript.SKILL,
		"consumed_stats": [StatIdsScript.ATK, StatIdsScript.HEALING_POWER_PERMILLE],
	},
	"modify_stat": {
		"port_method": "apply_stat_modifier",
		"effect": {"type": "modify_stat", "stat": StatIdsScript.ATK, "value": 2},
		"source_kind": EffectHookIdsScript.SKILL,
		"consumed_stats": [],
	},
	"physical_damage": {
		"port_method": "apply_physical_damage",
		"effect": {"type": "physical_damage", "amount": 7},
		"source_kind": EffectHookIdsScript.COMBO,
		"consumed_stats": [
			StatIdsScript.ATK,
			StatIdsScript.BOSS_DAMAGE_PERMILLE,
			StatIdsScript.COMBO_POWER_PERMILLE,
			StatIdsScript.CRIT_DAMAGE_PERMILLE,
			StatIdsScript.CRIT_RATE_PERMILLE,
			StatIdsScript.ELEMENT_POWER_PERMILLE,
			StatIdsScript.LIFESTEAL_PERMILLE,
			StatIdsScript.PHYSICAL_POWER_PERMILLE,
		],
		"default_target": EffectVocabularyScript.DEFAULT_ACTION_TARGET,
	},
	"remove_status": {
		"port_method": "remove_status",
		"effect": {"type": "remove_status", "status_id": "status_fixture"},
		"source_kind": EffectHookIdsScript.SKILL,
		"consumed_stats": [],
	},
}

var failed := false
var _fixture_root := "user://effect_handler_contract_%d" % OS.get_process_id()


class FakeEffectPort extends RefCounted:
	var calls: Array = []
	var applied_outcomes: Array = []

	func _record(method_name: String, context: Dictionary, effect: Dictionary) -> Dictionary:
		calls.append({
			"method": method_name,
			"context": context.duplicate(true),
			"effect": effect.duplicate(true),
		})
		return {"applied": true, "targets": [Dictionary(context.get("unit", {}))]}

	func apply_element_layers(context: Dictionary, effect: Dictionary) -> Dictionary:
		return _record("apply_element_layers", context, effect)

	func apply_status(context: Dictionary, effect: Dictionary) -> Dictionary:
		return _record("apply_status", context, effect)

	func apply_shield(context: Dictionary, effect: Dictionary) -> Dictionary:
		return _record("apply_shield", context, effect)

	func apply_heal(context: Dictionary, effect: Dictionary) -> Dictionary:
		return _record("apply_heal", context, effect)

	func apply_stat_modifier(context: Dictionary, effect: Dictionary) -> Dictionary:
		return _record("apply_stat_modifier", context, effect)

	func apply_physical_damage(context: Dictionary, effect: Dictionary) -> Dictionary:
		return _record("apply_physical_damage", context, effect)

	func remove_status(context: Dictionary, effect: Dictionary) -> Dictionary:
		return _record("remove_status", context, effect)

	func effect_applied(context: Dictionary, effect: Dictionary, outcome: Dictionary) -> void:
		applied_outcomes.append({
			"context": context.duplicate(true),
			"effect": effect.duplicate(true),
			"outcome": outcome.duplicate(true),
		})


func _initialize() -> void:
	_verify_exact_handler_cases()
	_verify_explicit_target_preservation()
	_verify_dynamic_stat_contracts()
	_verify_required_method_failure()
	_verify_authoring_assets()
	_remove_tree(_fixture_root)
	if failed:
		quit(1)
		return
	print("SMOKE_EFFECT_HANDLER_CONTRACT_OK handlers=%d" % HANDLER_CASES.size())
	quit(0)


func _verify_exact_handler_cases() -> void:
	var interpreter := EffectInterpreterScript.new()
	_expect(interpreter.is_valid(), "effect handler Registry is valid")
	var registered := interpreter.supported_types()
	var covered: Array[String] = []
	for handler_id_value in HANDLER_CASES.keys():
		covered.append(String(handler_id_value))
	covered.sort()
	_expect(registered == covered, "registered handler IDs and dedicated behavior cases are bidirectionally exact")
	for handler_id in registered:
		var case := Dictionary(HANDLER_CASES.get(handler_id, {}))
		_expect(not case.is_empty(), "%s has a dedicated behavior case" % handler_id)
		if case.is_empty():
			continue
		var input_effect := Dictionary(case.get("effect", {})).duplicate(true)
		var original_effect := input_effect.duplicate(true)
		var expected_effect := original_effect.duplicate(true)
		var expected_target := String(case.get("default_target", ""))
		if expected_target != "":
			expected_effect[EffectVocabularyScript.FIELD_TARGET] = expected_target
		var context := {
			"unit": {"id": "source_%s" % handler_id},
			"definition": {"id": "definition_%s" % handler_id},
			"source_kind": String(case.get("source_kind", EffectHookIdsScript.SKILL)),
		}
		var port := FakeEffectPort.new()
		_expect(interpreter.execute(port, context, [input_effect]), "%s executes through EffectInterpreter" % handler_id)
		_expect(input_effect == original_effect, "%s never mutates the source content Dictionary" % handler_id)
		_expect(port.calls.size() == 1, "%s dispatches exactly one narrow Port call" % handler_id)
		if port.calls.size() != 1:
			continue
		var call := Dictionary(port.calls[0])
		_expect(String(call.get("method", "")) == String(case.get("port_method", "")), "%s dispatches to its declared Port method" % handler_id)
		_expect(Dictionary(call.get("context", {})) == context, "%s preserves the execution context" % handler_id)
		var dispatched_effect := Dictionary(call.get("effect", {}))
		_expect(dispatched_effect == expected_effect, "%s preserves every effect parameter and only materializes documented defaults" % handler_id)
		var consumed := interpreter.consumed_stats([input_effect], String(case.get("source_kind", EffectHookIdsScript.SKILL)))
		_expect(consumed == _strings(Array(case.get("consumed_stats", []))), "%s reports its exact consumed stat contract" % handler_id)
		_expect(port.applied_outcomes.size() == 1, "%s publishes one effect_applied attribution outcome" % handler_id)
		if port.applied_outcomes.size() == 1:
			var applied := Dictionary(port.applied_outcomes[0])
			_expect(Dictionary(applied.get("context", {})) == context, "%s preserves context through effect_applied" % handler_id)
			_expect(Dictionary(applied.get("effect", {})) == original_effect, "%s attributes the original content effect" % handler_id)
			_expect(_strings(Array(Dictionary(applied.get("outcome", {})).get("consumed_stats", []))) == _strings(Array(case.get("consumed_stats", []))), "%s attributes its exact consumed stats in the execution outcome" % handler_id)


func _verify_explicit_target_preservation() -> void:
	var interpreter := EffectInterpreterScript.new()
	for handler_id in ["apply_element_layer", "physical_damage"]:
		var case := Dictionary(HANDLER_CASES.get(handler_id, {}))
		var input_effect := Dictionary(case.get("effect", {})).duplicate(true)
		input_effect[EffectVocabularyScript.FIELD_TARGET] = EffectVocabularyScript.DEFAULT_TARGET
		var original_effect := input_effect.duplicate(true)
		var context := {
			"unit": {"id": "explicit_target_%s" % handler_id},
			"definition": {"id": "definition_%s" % handler_id},
			"source_kind": String(case.get("source_kind", EffectHookIdsScript.SKILL)),
		}
		var port := FakeEffectPort.new()
		_expect(interpreter.execute(port, context, [input_effect]), "%s executes with an explicit target" % handler_id)
		_expect(input_effect == original_effect, "%s keeps explicit-target source content immutable" % handler_id)
		_expect(port.calls.size() == 1 and Dictionary(Dictionary(port.calls[0]).get("effect", {})) == original_effect, "%s preserves an explicit target instead of overwriting it" % handler_id)


func _verify_dynamic_stat_contracts() -> void:
	var interpreter := EffectInterpreterScript.new()
	var heal_without_atk := interpreter.consumed_stats([{"type": "heal", "scale_with_atk": false}], EffectHookIdsScript.SKILL)
	_expect(heal_without_atk == [StatIdsScript.HEALING_POWER_PERMILLE], "heal only consumes ATK when scale_with_atk is enabled")
	var skill_stats := interpreter.consumed_stats([{"type": "physical_damage"}], EffectHookIdsScript.SKILL)
	var combo_stats := interpreter.consumed_stats([{"type": "physical_damage"}], EffectHookIdsScript.COMBO)
	var common_stats := [
		StatIdsScript.ATK,
		StatIdsScript.BOSS_DAMAGE_PERMILLE,
		StatIdsScript.CRIT_DAMAGE_PERMILLE,
		StatIdsScript.CRIT_RATE_PERMILLE,
		StatIdsScript.ELEMENT_POWER_PERMILLE,
		StatIdsScript.LIFESTEAL_PERMILLE,
		StatIdsScript.PHYSICAL_POWER_PERMILLE,
	]
	var expected_skill := common_stats.duplicate()
	expected_skill.append(StatIdsScript.SKILL_POWER_PERMILLE)
	var expected_combo := common_stats.duplicate()
	expected_combo.append(StatIdsScript.COMBO_POWER_PERMILLE)
	_expect(skill_stats == _strings(expected_skill), "physical damage declares the complete exact Skill stat set")
	_expect(combo_stats == _strings(expected_combo), "physical damage declares the complete exact Combo stat set")


func _verify_required_method_failure() -> void:
	_remove_tree(_fixture_root)
	var absolute := ProjectSettings.globalize_path(_fixture_root)
	DirAccess.make_dir_recursive_absolute(absolute)
	var fixtures := {
		"missing_consumed_stats.gd": "extends RefCounted\nfunc plugin_id() -> String: return \"missing_consumed_stats\"\nfunc execute(_port: RefCounted, _context: Dictionary, _effect: Dictionary) -> bool: return true\n",
		"wrong_execute_arity.gd": "extends RefCounted\nfunc plugin_id() -> String: return \"wrong_execute_arity\"\nfunc consumed_stats(_effect: Dictionary, _source_kind: String) -> Array[String]: return []\nfunc execute(_port: RefCounted, _context: Dictionary) -> bool: return true\n",
		"wrong_consumed_arity.gd": "extends RefCounted\nfunc plugin_id() -> String: return \"wrong_consumed_arity\"\nfunc consumed_stats(_effect: Dictionary) -> Array[String]: return []\nfunc execute(_port: RefCounted, _context: Dictionary, _effect: Dictionary) -> bool: return true\n",
		"wrong_id_arity.gd": "extends RefCounted\nfunc plugin_id(_suffix: String) -> String: return \"wrong_id_arity\"\nfunc consumed_stats(_effect: Dictionary, _source_kind: String) -> Array[String]: return []\nfunc execute(_port: RefCounted, _context: Dictionary, _effect: Dictionary) -> bool: return true\n",
	}
	for file_name in fixtures:
		var file := FileAccess.open(_fixture_root.path_join(String(file_name)), FileAccess.WRITE)
		if file == null:
			_expect(false, "contract mutation fixture %s can be written" % file_name)
			continue
		file.store_string(String(fixtures[file_name]))
		file.close()
	var registry := ScriptPluginRegistryScript.new().configure(
		_fixture_root,
		&"plugin_id",
		[&"execute", &"consumed_stats"],
		{"execute": 3, "consumed_stats": 2}
	)
	_expect(not registry.is_valid(), "missing methods and wrong arities invalidate the whole handler Registry")
	_expect(registry.ids().is_empty(), "an invalid handler Registry exposes no partial plugin set")
	var joined := "\n".join(registry.validation_errors())
	_expect(joined.contains("consumed_stats"), "handler contract error names the missing method")
	_expect(joined.contains("execute expected 3 found 2"), "handler discovery rejects wrong execute arity")
	_expect(joined.contains("consumed_stats expected 2 found 1"), "handler discovery rejects wrong consumed_stats arity")
	_expect(joined.contains("must declare 0 arguments, found 1"), "handler discovery rejects wrong plugin_id arity")


func _verify_authoring_assets() -> void:
	var interpreter_source := FileAccess.get_file_as_string("res://core/effects/effect_interpreter.gd")
	_expect(interpreter_source.contains('[&"execute", &"consumed_stats"]'), "EffectInterpreter declares the complete handler Registry contract")
	_expect(interpreter_source.contains('{"execute": 3, "consumed_stats": 2}'), "EffectInterpreter declares exact handler method arities")
	var template_path := "res://tools/templates/effect_handler.gd.template"
	_expect(FileAccess.file_exists(template_path), "copyable handler template exists outside the runtime Registry directory")
	var template_source := FileAccess.get_file_as_string(template_path)
	for method_name in ["plugin_id", "consumed_stats", "execute"]:
		_expect(template_source.contains("func %s(" % method_name), "handler template includes %s" % method_name)
	var guide := FileAccess.get_file_as_string("res://docs/16_EFFECT_HANDLER_AUTHORING.md")
	for phrase in ["plugin_id", "consumed_stats", "execute", "JSON", "Port", "smoke_effect_handler_contract"]:
		_expect(guide.contains(phrase), "handler authoring guide documents %s" % phrase)


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	result.sort()
	return result


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := absolute.path_join(name)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
