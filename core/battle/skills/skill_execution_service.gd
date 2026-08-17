extends RefCounted

const EffectInterpreterScript := preload("res://core/effects/effect_interpreter.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")

var _effect_interpreter: RefCounted = EffectInterpreterScript.new()
var _battle_hook_pipeline: RefCounted = null


func configure(effect_interpreter: RefCounted, battle_hook_pipeline: RefCounted = null) -> RefCounted:
	if effect_interpreter != null:
		_effect_interpreter = effect_interpreter
	_battle_hook_pipeline = battle_hook_pipeline
	return self

## Ordered effect interpreter for one skill. The service owns effect sequencing;
## all authoritative mutation remains behind SkillEffectPort.


func execute(
	port: RefCounted,
	unit: Dictionary,
	definition: Dictionary,
	order_index: int,
	modifiers: Dictionary = {},
	source_kind: String = EffectHookIdsScript.SKILL
) -> bool:
	if port.has_method(&"skill_available") and not bool(port.call(&"skill_available", unit, definition)):
		return false
	var filter_context := {
		"unit": unit,
		"definition": definition,
		"source_kind": source_kind,
		"hook": source_kind,
	}
	if port.has_method(&"condition_context"):
		filter_context = Dictionary(port.call(&"condition_context", filter_context, {}))
	var effective_modifiers := modifiers.duplicate(true)
	if _battle_hook_pipeline != null and port.has_method(&"game_data"):
		effective_modifiers = Dictionary(_battle_hook_pipeline.collect(unit, Dictionary(port.call(&"game_data")), source_kind, filter_context))
	effective_modifiers = Dictionary(_effect_interpreter.call(&"relevant_bundle", port, filter_context, effective_modifiers, Array(definition.get("effects", [])), source_kind))
	var context: Dictionary = port.begin_skill(unit, definition, order_index, effective_modifiers, source_kind)
	if context.is_empty():
		return false
	var accepted := true
	if _battle_hook_pipeline != null:
		var before_hook := EffectHookIdsScript.BEFORE_COMBO if source_kind == EffectHookIdsScript.COMBO else EffectHookIdsScript.BEFORE_SKILL
		var before_context := context
		if port.has_method(&"condition_context"):
			before_context = Dictionary(port.call(&"condition_context", context, {}))
		var before_collected := Dictionary(_battle_hook_pipeline.collect(unit, Dictionary(port.call(&"game_data")), before_hook, before_context))
		accepted = bool(_battle_hook_pipeline.execute(port, context, before_collected))
		accepted = bool(_battle_hook_pipeline.execute(port, context, effective_modifiers)) and accepted
	accepted = bool(_effect_interpreter.execute(port, context, Array(definition.get("effects", [])))) and accepted
	if _battle_hook_pipeline != null and port.has_method(&"game_data"):
		var after_hook := EffectHookIdsScript.AFTER_COMBO if source_kind == EffectHookIdsScript.COMBO else EffectHookIdsScript.AFTER_SKILL
		var after_context := context
		if port.has_method(&"condition_context"):
			after_context = Dictionary(port.call(&"condition_context", context, {}))
		var after_collected := Dictionary(_battle_hook_pipeline.collect(unit, Dictionary(port.call(&"game_data")), after_hook, after_context))
		accepted = bool(_battle_hook_pipeline.execute(port, context, after_collected)) and accepted
	port.finish_skill(context)
	if port.has_method(&"start_skill_cooldown"):
		port.call(&"start_skill_cooldown", unit, definition)
	return accepted
