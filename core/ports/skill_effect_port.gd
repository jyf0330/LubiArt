extends RefCounted

const BattleTraceFactoryScript := preload("res://core/battle/battle_trace_factory.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const SkillActionRulesScript := preload("res://core/battle/skills/skill_action_rules.gd")
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")

## Narrow mutation adapter for SkillExecutionService. This preserves the
## existing authoritative combat math, trace, quality, and mechanism hooks.

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func game_data() -> Dictionary:
	return Dictionary(_authority.get("game_data"))


func begin_hook(unit: Dictionary, hook: String) -> Dictionary:
	var targets: Array = []
	for unit_value in Array(_authority.get("units")):
		var candidate := Dictionary(unit_value)
		if String(candidate.get("side", "")) != String(unit.get("side", "")) and int(candidate.get("hp", 0)) > 0:
			targets.append(candidate)
	return {
		"unit": unit,
		"definition": {"id": hook, "name": hook, "effects": []},
		"slot": {},
		"option": {},
		"targets": targets,
		"all_units": Array(_authority.get("units")),
		"cells": [],
		"element": _skill_element(unit, {}),
		"logs": [],
		"order_index": -1,
		"modifiers": {},
		"source_kind": hook,
		"applied_trait_ids": [],
		"applied_trait_names": [],
	}


func finish_hook(context: Dictionary) -> void:
	_append_trait_trace(context)
	for line in Array(context.get("logs", [])):
		_authority.call("_log", String(line))
	_authority.call("_check_battle_end")


func begin_skill(
	unit: Dictionary,
	definition: Dictionary,
	order_index: int,
	modifiers: Dictionary = {},
	source_kind: String = EffectHookIdsScript.SKILL
) -> Dictionary:
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return {}
	var slots: Array = Array(_authority.call("_action_slots_for_unit", unit))
	if slots.is_empty():
		return {}
	var slot_index: int = clampi(SkillActionRulesScript.action_slot_index(definition), 0, slots.size() - 1)
	var slot := Dictionary(slots[slot_index]).duplicate(true)
	var direction := String(_authority.call("_action_slot_direction", unit, slot_index))
	var option := Dictionary(_authority.call("_attack_option_for_direction", unit, direction)).duplicate(true)
	if option.is_empty():
		return {}
	slot["index"] = slot_index
	slot["base_layers"] = 1
	slot["layers"] = 1
	slot["effective_layers"] = 1
	var element := _skill_element(unit, definition)
	var context := {
		"unit": unit,
		"definition": definition,
		"slot": slot,
		"option": option,
		"targets": Array(_authority.call("_enemies_in_attack_option", unit, option)),
		"all_units": Array(_authority.get("units")),
		"cells": Array(option.get("cells", [])).duplicate(true),
		"element": element,
		"logs": Array(_authority.call("_apply_quality_before_attack", unit, option)) if source_kind == EffectHookIdsScript.SKILL else [],
		"order_index": order_index,
		"modifiers": modifiers.duplicate(true),
		"source_kind": source_kind,
		"applied_trait_ids": [],
		"applied_trait_names": [],
	}
	var trace := Array(_authority.get("battle_trace"))
	if source_kind == EffectHookIdsScript.COMBO:
		trace.append(BattleTraceFactoryScript.skill_combo_event(
			trace.size() + 1,
			int(_authority.get("battle_round")),
			String(_authority.get("phase")),
			unit,
			definition,
			Array(context["cells"])
		))
	else:
		trace.append(BattleTraceFactoryScript.skill_event(
			trace.size() + 1,
			int(_authority.get("battle_round")),
			String(_authority.get("phase")),
			unit,
			definition,
			order_index,
			Array(context["cells"])
		))
	_authority.set("battle_trace", trace)
	return context


func begin_relic(instance: Dictionary, definition: Dictionary, trigger: Dictionary) -> Dictionary:
	var side := String(instance.get("side", "player"))
	var preferred_source_id := String(definition.get("source_unit_id", ""))
	var source := {}
	var targets: Array = []
	for unit_value in Array(_authority.get("units")):
		var candidate := Dictionary(unit_value)
		if int(candidate.get("hp", 0)) <= 0:
			continue
		if String(candidate.get("side", "")) == side:
			if source.is_empty() or (preferred_source_id != "" and String(candidate.get("id", candidate.get("pet_id", ""))) == preferred_source_id):
				source = candidate
		else:
			targets.append(candidate)
	if source.is_empty():
		return {}
	return {
		"unit": source,
		"definition": definition,
		"slot": {},
		"option": {},
		"targets": targets,
		"all_units": Array(_authority.get("units")),
		"cells": [],
		"element": String(definition.get("element", _skill_element(source, definition))),
		"logs": [],
		"order_index": -1,
		"modifiers": {},
		"source_kind": "relic",
		"relic_instance": instance.duplicate(true),
		"trigger": trigger.duplicate(true),
	}


func finish_relic(context: Dictionary) -> void:
	var definition := Dictionary(context.get("definition", {}))
	_authority.call("_log", "场下遗物【%s】生效。" % String(definition.get("name", definition.get("id", "遗物"))))
	for line in Array(context.get("logs", [])):
		_authority.call("_log", String(line))
	_authority.call("_check_battle_end")


func apply_physical_damage(context: Dictionary, effect: Dictionary) -> Dictionary:
	var unit := Dictionary(context["unit"])
	var slot := Dictionary(context.get("slot", {}))
	var option := Dictionary(context.get("option", {}))
	var targets := _effect_targets(context, effect)
	var cells := Array(context["cells"])
	var element := String(context["element"])
	var definition := Dictionary(context["definition"])
	var strike_count := SkillActionRulesScript.physical_strike_count(definition, effect)
	var modifiers := Dictionary(context.get("modifiers", {}))
	var source_kind := String(context.get("source_kind", EffectHookIdsScript.SKILL))
	var context_modifiers := Array(modifiers.get("modifiers", []))
	var stat_context := _stat_context(context)
	var attack := _resolved_stat(unit, StatIdsScript.ATK, context_modifiers, stat_context)
	var physical_power := _resolved_stat(unit, StatIdsScript.PHYSICAL_POWER_PERMILLE, context_modifiers, stat_context)
	var source_power_stat := StatIdsScript.COMBO_POWER_PERMILLE if source_kind == EffectHookIdsScript.COMBO else StatIdsScript.SKILL_POWER_PERMILLE
	var source_power := _resolved_stat(unit, source_power_stat, context_modifiers, stat_context)
	var base_damage: int = _round_permille(_round_permille(_round_permille(attack, int(effect.get("power_permille", 1000))), physical_power), source_power)
	var damage_bonus: int = int(_authority.call("_skill_damage_bonus", unit, slot, option, targets)) if source_kind == EffectHookIdsScript.SKILL else 0
	var applied_targets: Array = []
	var pending_deaths: Array = []
	var total_damage := 0
	var damage_props := DamagePropsScript.move_damage() if [EffectHookIdsScript.SKILL, EffectHookIdsScript.COMBO].has(source_kind) else DamagePropsScript.non_move_unpowered()
	for strike_index in range(strike_count):
		_authority.call("_record_attack_strike_trace", unit, cells, element, strike_index + 1, strike_count)
		for hit_index in range(targets.size()):
			var target := Dictionary(targets[hit_index])
			if int(target.get("hp", 0)) <= 0:
				continue
			var hit_damage: int = int(_authority.call("_quality_damage_for_hit", unit, slot, option, targets, target, hit_index, base_damage + damage_bonus)) if source_kind == EffectHookIdsScript.SKILL else base_damage
			var result := Dictionary(_authority.call("_deal_damage", unit, target, hit_damage, element, false, {
				"sourceType": "skill_combo" if source_kind == EffectHookIdsScript.COMBO else source_kind,
				"calculationKind": "physical",
				"strikeIndex": strike_index + 1,
				"strikeCount": strike_count,
				"suppressProjectile": true,
				"deferDeathResolution": true,
				"causedById": String(definition.get("id", "")),
				"causedByName": String(definition.get("name", "")),
			}, damage_props))
			if not applied_targets.has(target):
				applied_targets.append(target)
			total_damage += int(result.get("final", 0))
			if bool(result.get("pending_death", false)):
				pending_deaths.append({"source": unit, "target": target, "result": result})
			_append_logs(context, Array(result.get("mechanic_logs", [])))
			if source_kind == EffectHookIdsScript.SKILL:
				_append_logs(context, Array(_authority.call("_apply_attacker_mechanic_after_hit", unit, target, int(result.get("final", 0)), element, String(option.get("direction", "")))))
				_append_logs(context, Array(_authority.call("_apply_quality_after_hit", unit, target)))
	_append_logs(context, Array(_authority.call("_resolve_damage_deaths", pending_deaths)))
	return {"applied": not applied_targets.is_empty(), "targets": applied_targets, "payload": {"totalDamage": total_damage}}


func apply_element_layers(context: Dictionary, effect: Dictionary) -> Dictionary:
	var unit := Dictionary(context["unit"])
	var option := Dictionary(context["option"])
	var targets := _effect_targets(context, effect)
	var cells := Array(context["cells"])
	var element := _skill_element(unit, Dictionary(context["definition"]), String(effect.get("element_source", "")))
	var modifiers := Dictionary(context.get("modifiers", {}))
	var source_kind := String(context.get("source_kind", EffectHookIdsScript.SKILL))
	var base_layers: int = max(1, int(effect.get("layers", 1)) + _resolved_stat(unit, StatIdsScript.ELEMENT_LAYER_BONUS, Array(modifiers.get("modifiers", [])), _stat_context(context)))
	var layers: int = int(_authority.call("_quality_element_layers", unit, element, base_layers)) if source_kind == EffectHookIdsScript.SKILL else base_layers
	var effect_application_count := SkillActionRulesScript.element_application_count(effect)
	for target_value in targets:
		var target := Dictionary(target_value)
		var cell := {"x": int(target.get("x", -1)), "y": int(target.get("y", -1))}
		var apply_count: int = int(_authority.call("_quality_element_apply_count", unit, cell)) * effect_application_count
		for _apply_index in range(apply_count):
			_authority.call("_apply_element_to_unit", target, element, layers)
			_authority.call("_apply_element_to_cell", int(cell.x), int(cell.y), element, layers)
			_append_logs(context, Array(_authority.call("_apply_mechanic_after_element_apply", unit, target, element, layers, cell)))
		_append_logs(context, Array(_authority.call("_quality_immediate_element_burst", unit, target, element)))
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		var occupant := Dictionary(_authority.call("unit_at", int(cell.get("x", -1)), int(cell.get("y", -1))))
		if not occupant.is_empty():
			if String(occupant.get("side", "")) == String(unit.get("side", "")):
				continue
			var already_applied := false
			for target_value in targets:
				if String(Dictionary(target_value).get("id", "")) == String(occupant.get("id", "")):
					already_applied = true
					break
			if already_applied:
				continue
		var apply_count: int = int(_authority.call("_quality_element_apply_count", unit, cell)) * effect_application_count
		for _apply_index in range(apply_count):
			_authority.call("_apply_element_to_cell", int(cell.get("x", -1)), int(cell.get("y", -1)), element, layers)
			if not occupant.is_empty():
				_authority.call("_apply_element_to_unit", occupant, element, layers)
			_append_logs(context, Array(_authority.call("_apply_mechanic_after_element_apply", unit, occupant, element, layers, cell)))
	_authority.call("_record_element_applied_trace", unit, cells, element, layers, not targets.is_empty())
	context["element"] = element
	return {"applied": not targets.is_empty() or not cells.is_empty(), "targets": targets, "payload": {"element": element, "layers": layers}}


func apply_heal(context: Dictionary, effect: Dictionary) -> Dictionary:
	var unit := Dictionary(context["unit"])
	var targets := _effect_targets(context, effect)
	var amount := int(effect.get("amount", 0))
	if bool(effect.get("scale_with_atk", false)):
		amount += _round_permille(_resolved_stat(unit, StatIdsScript.ATK, _trait_modifiers(context), _stat_context(context)), int(effect.get("power_permille", 1000)))
	amount = _round_permille(amount, _resolved_stat(unit, StatIdsScript.HEALING_POWER_PERMILLE, _trait_modifiers(context), _stat_context(context)))
	var applied_targets: Array = []
	var total_healed := 0
	for target_value in targets:
		var target := Dictionary(target_value)
		var healed: int = int(_authority.call("_heal_unit", target, max(0, amount), unit))
		if healed > 0:
			applied_targets.append(target)
			total_healed += healed
			_append_logs(context, ["%s 恢复 %d 点生命。" % [String(target.get("name", "宠物")), healed]])
	return {"applied": not applied_targets.is_empty(), "targets": applied_targets, "payload": {"healed": total_healed}}


func apply_shield(context: Dictionary, effect: Dictionary) -> Dictionary:
	var unit := Dictionary(context["unit"])
	var amount := _round_permille(max(0, int(effect.get("amount", 0))), _resolved_stat(unit, StatIdsScript.SHIELD_GAIN_PERMILLE, _trait_modifiers(context), _stat_context(context)))
	var applied_targets: Array = []
	for target_value in _effect_targets(context, effect):
		var target := Dictionary(target_value)
		target["shield"] = max(0, int(target.get("shield", 0))) + amount
		if amount > 0: applied_targets.append(target)
		_append_logs(context, ["%s 获得 %d 点护盾。" % [String(target.get("name", "宠物")), amount]])
	return {"applied": not applied_targets.is_empty(), "targets": applied_targets, "payload": {"shield": amount}}


func apply_status(context: Dictionary, effect: Dictionary) -> Dictionary:
	var composition: RefCounted = _authority.get("_core_composition")
	var catalog := Dictionary(Dictionary(_authority.get("game_data")).get("status_catalog", {}))
	var source := Dictionary(context["unit"])
	var applied_targets: Array = []
	for target_value in _effect_targets(context, effect):
		var target := Dictionary(target_value)
		var status_id := EffectVocabularyScript.status_id(effect)
		var definition := Dictionary(catalog.get(status_id, {}))
		var base_duration := int(effect.get("duration", definition.get("default_duration", 1)))
		var semantic := _apply_stat_semantics("status_apply", {
			"source": source,
			"target": target,
			"status_definition": definition,
			"duration": max(1, base_duration),
			"event_seed": _effect_event_seed(context, effect, target),
		})
		if not bool(semantic.get("accepted", true)):
			continue
		if composition.status_service.apply(
			target,
			status_id,
			catalog,
			max(1, int(effect.get("stacks", 1))),
			int(semantic.get("duration", base_duration)),
			String(source.get("id", "")),
			int(_authority.get("state_version"))
		):
			applied_targets.append(target)
			_append_logs(context, ["%s 获得状态【%s】。" % [String(target.get("name", "宠物")), String(Dictionary(catalog.get(status_id, {})).get("name", status_id))]] )
	return {"applied": not applied_targets.is_empty(), "targets": applied_targets, "payload": {"statusId": EffectVocabularyScript.status_id(effect)}}


func remove_status(context: Dictionary, effect: Dictionary) -> Dictionary:
	var composition: RefCounted = _authority.get("_core_composition")
	var applied_targets: Array = []
	for target_value in _effect_targets(context, effect):
		var target := Dictionary(target_value)
		if composition.status_service.remove(target, EffectVocabularyScript.status_id(effect), int(effect.get("stacks", 0))):
			applied_targets.append(target)
	return {"applied": not applied_targets.is_empty(), "targets": applied_targets}


func apply_stat_modifier(context: Dictionary, effect: Dictionary) -> Dictionary:
	var source := Dictionary(context["unit"])
	var applied_targets: Array = []
	for target_value in _effect_targets(context, effect):
		var target := Dictionary(target_value)
		var modifiers := Array(target.get("runtime_modifiers", [])).duplicate(true)
		var modifier := effect.duplicate(true)
		modifier.erase(EffectVocabularyScript.FIELD_TYPE)
		modifier[EffectVocabularyScript.FIELD_STAT] = EffectVocabularyScript.stat_id(effect)
		modifier[EffectVocabularyScript.FIELD_OPERATION] = EffectVocabularyScript.operation_id(effect)
		modifier["phase"] = String(effect.get("phase", "runtime"))
		modifier["source_type"] = String(context.get("source_kind", EffectHookIdsScript.SKILL))
		modifier["source_id"] = String(Dictionary(context.get("definition", {})).get("id", source.get("id", "")))
		modifier["instance_id"] = "%s:%s:%d" % [String(modifier["source_id"]), EffectVocabularyScript.stat_id(modifier), modifiers.size()]
		modifiers.append(modifier)
		target["runtime_modifiers"] = modifiers
		applied_targets.append(target)
	return {"applied": not applied_targets.is_empty(), "targets": applied_targets}


func finish_skill(context: Dictionary) -> void:
	var unit := Dictionary(context["unit"])
	var definition := Dictionary(context["definition"])
	var option := Dictionary(context["option"])
	var targets := Array(context["targets"])
	var source_kind := String(context.get("source_kind", EffectHookIdsScript.SKILL))
	_append_trait_trace(context)
	if source_kind == EffectHookIdsScript.COMBO:
		_authority.call("_log", "%s 触发技能组合【%s】。" % [String(unit.get("name", "宠物")), String(definition.get("name", definition.get("id", "组合")))])
		for line in Array(context["logs"]):
			_authority.call("_log", String(line))
		for target_value in targets:
			var target := Dictionary(target_value)
			if int(target.get("hp", 0)) <= 0:
				_authority.call("_log", "%s 被击败。" % String(target.get("name", "敌人")))
		_finish_skill_timeline(unit, definition, source_kind, targets)
		_authority.call("_check_battle_end")
		return
	unit["has_attacked"] = true
	_append_logs(context, Array(_authority.call("_apply_quality_after_attack", unit, option, targets)))
	_append_logs(context, Array(_authority.call("_apply_mechanic_after_action", unit)))
	_authority.call("_log", "%s 触发第%d技能【%s】。" % [String(unit.get("name", "宠物")), int(context.get("order_index", 0)) + 1, String(definition.get("name", definition.get("id", "技能")))])
	for line in Array(context["logs"]):
		_authority.call("_log", String(line))
	for target_value in targets:
		var target := Dictionary(target_value)
		if int(target.get("hp", 0)) <= 0:
			_authority.call("_log", "%s 被击败。" % String(target.get("name", "敌人")))
	_finish_skill_timeline(unit, definition, source_kind, targets)
	_authority.call("_check_battle_end")


func _finish_skill_timeline(unit: Dictionary, definition: Dictionary, source_kind: String, targets: Array) -> void:
	if _authority.has_method(&"_advance_relic_time"):
		_authority.call(&"_advance_relic_time", max(0, int(definition.get("duration_ticks", 0))))
	if _authority.has_method(&"_publish_relic_event"):
		_authority.call(&"_publish_relic_event", "SKILL_COMBO_USED" if source_kind == EffectHookIdsScript.COMBO else "SKILL_USED", {
			"source_unit_id": String(unit.get("id", unit.get("pet_id", ""))),
			"source_side": String(unit.get("side", "")),
			"skill_id": String(definition.get("id", "")),
			"target_ids": targets.map(func(value: Variant) -> String: return String(Dictionary(value).get("id", ""))),
		})


func log(message: String) -> void:
	_authority.call("_log", message)


func skill_available(unit: Dictionary, definition: Dictionary) -> bool:
	var cooldowns := Dictionary(unit.get("skill_cooldowns", {}))
	return int(cooldowns.get(String(definition.get("id", "")), 0)) <= 0


func start_skill_cooldown(unit: Dictionary, definition: Dictionary) -> void:
	var base_ticks: int = max(0, int(definition.get("cooldown_ticks", 0)))
	if base_ticks <= 0:
		return
	var result := _apply_stat_semantics(EffectHookIdsScript.COOLDOWN, {"unit": unit, "ticks": base_ticks})
	var ticks: int = max(0, int(result.get("ticks", base_ticks)))
	if ticks <= 0:
		return
	var cooldowns := Dictionary(unit.get("skill_cooldowns", {}))
	cooldowns[String(definition.get("id", ""))] = ticks
	unit["skill_cooldowns"] = cooldowns


func condition_context(context: Dictionary, effect: Dictionary) -> Dictionary:
	var result := context.duplicate(true)
	var unit := Dictionary(context.get("unit", {}))
	var hook := String(context.get("source_kind", context.get(EffectVocabularyScript.FIELD_HOOK, EffectHookIdsScript.EFFECT)))
	result["unit"] = unit
	result[EffectVocabularyScript.FIELD_HOOK] = hook
	result["source_kind"] = String(context.get("source_kind", hook))
	result["definition"] = Dictionary(context.get("definition", {}))
	result["stat_value"] = Callable(self, "_condition_stat_value")
	if not unit.is_empty():
		var composition: RefCounted = _authority.get("_core_composition")
		var resolved := Dictionary(composition.stat_query_service.resolve_all(unit, game_data(), hook, {
			"definition": result["definition"],
			"source_kind": result["source_kind"],
			"round": int(_authority.get("battle_round")),
		}))
		result["resolved_stats"] = Dictionary(composition.stat_query_service.values_from_resolved(resolved))
	var targets := _effect_targets(context, effect)
	if not targets.is_empty():
		var target := Dictionary(targets[0])
		result[EffectVocabularyScript.FIELD_TARGET] = target
		if not target.is_empty():
			var composition: RefCounted = _authority.get("_core_composition")
			var target_resolved := Dictionary(composition.stat_query_service.resolve_all(target, game_data(), EffectHookIdsScript.EFFECT_TARGET, {
				"source": unit,
				"definition": result["definition"],
				"round": int(_authority.get("battle_round")),
			}))
			result["target_resolved_stats"] = Dictionary(composition.stat_query_service.values_from_resolved(target_resolved))
	return result


func effect_applied(context: Dictionary, effect: Dictionary, outcome: Dictionary) -> void:
	var source := Dictionary(context.get("unit", {}))
	var targets := Array(outcome.get("targets", []))
	if targets.is_empty():
		targets = _effect_targets(context, effect)
	if targets.is_empty():
		targets = [source]
	var payload := effect.duplicate(true)
	for key in Dictionary(outcome.get("payload", {})).keys():
		payload[key] = Dictionary(outcome.get("payload", {}))[key]
	for target_value in targets:
		_append_effect_trace(source, Dictionary(target_value), EffectVocabularyScript.text(effect, EffectVocabularyScript.FIELD_TYPE, EffectHookIdsScript.EFFECT), payload)
	_record_consumed_trait_modifiers(context, Array(outcome.get("consumed_stats", [])))
	if String(effect.get("source_type", "")) == "trait":
		var trait_id := String(effect.get("source_id", ""))
		var ids := Array(context.get("applied_trait_ids", []))
		if trait_id != "" and not ids.has(trait_id):
			ids.append(trait_id)
			context["applied_trait_ids"] = ids
			var definition := Dictionary(Dictionary(game_data().get("trait_catalog", {})).get(trait_id, {}))
			var names := Array(context.get("applied_trait_names", []))
			names.append(String(definition.get("name", trait_id)))
			context["applied_trait_names"] = names


func _record_consumed_trait_modifiers(context: Dictionary, consumed_stats: Array) -> void:
	if consumed_stats.is_empty():
		return
	var ids := Array(context.get("applied_trait_ids", []))
	var names := Array(context.get("applied_trait_names", []))
	var known_ids := Array(Dictionary(context.get("modifiers", {})).get("trait_ids", []))
	var known_names := Array(Dictionary(context.get("modifiers", {})).get("trait_names", []))
	var name_by_id := {}
	for index in range(min(known_ids.size(), known_names.size())):
		name_by_id[String(known_ids[index])] = String(known_names[index])
	for modifier_value in Array(Dictionary(context.get("modifiers", {})).get("modifiers", [])):
		var modifier := Dictionary(modifier_value)
		if String(modifier.get("source_type", "")) != "trait":
			continue
		if not consumed_stats.has(EffectVocabularyScript.stat_id(modifier)):
			continue
		var trait_id := String(modifier.get("source_id", ""))
		if trait_id == "" or ids.has(trait_id):
			continue
		ids.append(trait_id)
		names.append(String(name_by_id.get(trait_id, trait_id)))
	context["applied_trait_ids"] = ids
	context["applied_trait_names"] = names


func _skill_element(unit: Dictionary, definition: Dictionary, override_source: String = "") -> String:
	var source := override_source if override_source != "" else String(definition.get("element_source", "primary"))
	var elements := Array(unit.get("element_types", []))
	var primary := String(unit.get("element", elements[0] if not elements.is_empty() else "无"))
	if source == "secondary":
		if elements.size() > 1:
			return String(elements[1])
		var secondary := Array(unit.get("secondary_elements", []))
		if not secondary.is_empty():
			return String(secondary[0])
	return primary


func _append_logs(context: Dictionary, values: Array) -> void:
	var logs := Array(context["logs"])
	for value in values:
		logs.append(String(value))
	context["logs"] = logs


func _trait_modifiers(context: Dictionary) -> Array:
	return Array(Dictionary(context.get("modifiers", {})).get("modifiers", []))


func _stat_context(context: Dictionary) -> Dictionary:
	return {
		EffectVocabularyScript.FIELD_HOOK: String(context.get("source_kind", EffectHookIdsScript.SKILL)),
		"source_kind": String(context.get("source_kind", EffectHookIdsScript.SKILL)),
		"round": int(_authority.get("battle_round")),
		"definition": Dictionary(context.get("definition", {})),
		"stat_value": Callable(self, "_condition_stat_value"),
	}


func _resolved_stat(unit: Dictionary, stat_id: String, extra_modifiers: Array, context: Dictionary) -> int:
	var composition: RefCounted = _authority.get("_core_composition")
	var data := Dictionary(_authority.get("game_data"))
	return int(composition.stat_query_service.value(unit, data, stat_id, String(context.get(EffectVocabularyScript.FIELD_HOOK, EffectHookIdsScript.SKILL)), context, extra_modifiers))


func _condition_stat_value(unit: Dictionary, stat_id: String, context: Dictionary = {}) -> int:
	return _resolved_stat(unit, stat_id, [], context)


func _apply_stat_semantics(event_id: String, context: Dictionary) -> Dictionary:
	var composition: RefCounted = _authority.get("_core_composition")
	var effective := context.duplicate()
	effective["stat_value"] = Callable(self, "_condition_stat_value")
	return Dictionary(composition.stat_semantic_pipeline.apply(event_id, effective))


func _effect_event_seed(context: Dictionary, effect: Dictionary, target: Dictionary) -> String:
	return "%d:%d:%s:%s:%s:%s" % [
		int(_authority.get("battle_round")),
		int(_authority.get("state_version")),
		String(Dictionary(context.get("unit", {})).get("id", "")),
		String(target.get("id", "")),
		String(Dictionary(context.get("definition", {})).get("id", "")),
		EffectVocabularyScript.effect_type(effect),
	]


func _effect_targets(context: Dictionary, effect: Dictionary) -> Array:
	var composition: RefCounted = _authority.get("_core_composition")
	return composition.effect_target_resolver.targets(context, effect)


func _round_permille(value: int, permille: int) -> int:
	var product := value * permille
	return int((product + 500) / 1000) if product >= 0 else -int((-product + 500) / 1000)


func _append_effect_trace(source: Dictionary, target: Dictionary, effect_type: String, payload: Dictionary) -> void:
	var trace := Array(_authority.get("battle_trace"))
	trace.append(BattleTraceFactoryScript.effect_event(
		trace.size() + 1,
		int(_authority.get("battle_round")),
		String(_authority.get("phase")),
		source,
		target,
		effect_type,
		payload
	))
	_authority.set("battle_trace", trace)


func _append_trait_trace(context: Dictionary) -> void:
	var trait_ids := Array(context.get("applied_trait_ids", []))
	if trait_ids.is_empty() or bool(context.get("trait_trace_recorded", false)):
		return
	context["trait_trace_recorded"] = true
	var trace := Array(_authority.get("battle_trace"))
	trace.append(BattleTraceFactoryScript.trait_event(
		trace.size() + 1,
		int(_authority.get("battle_round")),
		String(_authority.get("phase")),
		Dictionary(context.get("unit", {})),
		{
			"trait_ids": trait_ids.duplicate(true),
			"trait_names": Array(context.get("applied_trait_names", [])).duplicate(true),
		},
		String(Dictionary(context.get("definition", {})).get("id", "")),
		String(context.get("source_kind", EffectHookIdsScript.SKILL))
	))
	_authority.set("battle_trace", trace)
