extends RefCounted

const SkillActionRulesScript := preload("res://core/battle/skills/skill_action_rules.gd")

## Pure constructors for stable battle-trace events. Callers remain responsible
## for validating board targets and appending the returned event.


static func unit_ref(unit: Dictionary) -> Dictionary:
	if unit.is_empty():
		return {}
	return {
		"id": String(unit.get("id", unit.get("pet_id", ""))),
		"name": String(unit.get("name", unit.get("id", ""))),
		"side": String(unit.get("side", "")),
		"x": int(unit.get("x", -1)),
		"y": int(unit.get("y", -1))
	}


static func position_ref(x: int, y: int) -> Dictionary:
	return {"r": y, "c": x, "x": x, "y": y}


static func move_event(step: int, round_number: int, phase: String, event_type: String, unit: Dictionary, from_pos: Dictionary, to_pos: Dictionary, move_range: int, event_text: String) -> Dictionary:
	var event_id := _event_id(step)
	var actor := unit_ref(unit)
	var event := {
		"eventId": event_id,
		"kind": "movement",
		"type": event_type,
		"step": step,
		"round": round_number,
		"phase": phase,
		"actor": actor,
		"target": {},
		"unitId": String(actor.get("id", "")),
		"from": from_pos.duplicate(true),
		"to": to_pos.duplicate(true),
		"moveRange": move_range,
		"payload": {
			"unitId": String(actor.get("id", "")),
			"from": from_pos.duplicate(true),
			"to": to_pos.duplicate(true),
			"moveRange": move_range
		},
		"changes": [],
		"source": {"system": "ysbzs_state.gd", "function": "move_selected"},
		"reason": "move_resolution" if event_type == "MOVE_HERO" else "move_blocked",
		"tags": ["battle", "movement"],
		"text": event_text
	}
	event["protocol"] = "|%s|id=%s|round=%d|phase=%s|unit=%s|from=%d,%d|to=%d,%d" % [
		event_type,
		event_id,
		round_number,
		phase,
		String(actor.get("id", "")),
		int(from_pos.get("r", -1)),
		int(from_pos.get("c", -1)),
		int(to_pos.get("r", -1)),
		int(to_pos.get("c", -1))
	]
	return event


static func damage_event(step: int, round_number: int, phase: String, source: Dictionary, target: Dictionary, raw_damage: int, shield_damage: int, hp_damage: int, hp_before: int, hp_after: int, shield_before: int, shield_after: int, element: String, trace_context: Dictionary = {}) -> Dictionary:
	var final_damage := shield_damage + hp_damage
	if final_damage <= 0:
		return {}
	var event_id := _event_id(step)
	var actor := unit_ref(source)
	var target_ref := unit_ref(target)
	var source_type := String(trace_context.get("sourceType", "action"))
	var payload := {
		"rawDamage": raw_damage,
		"finalDamage": final_damage,
		"shieldDamage": shield_damage,
		"hpDamage": hp_damage,
		"hpFrom": hp_before,
		"hpTo": hp_after,
		"shieldFrom": shield_before,
		"shieldTo": shield_after,
		"element": element,
		"sourceType": source_type
	}
	if trace_context.has("strikeIndex"):
		payload["strikeIndex"] = int(trace_context.get("strikeIndex", 1))
	if trace_context.has("strikeCount"):
		payload["strikeCount"] = int(trace_context.get("strikeCount", 1))
	if trace_context.has("suppressProjectile"):
		payload["suppressProjectile"] = bool(trace_context.get("suppressProjectile", false))
	if trace_context.has("causedById"):
		payload["causedById"] = String(trace_context.get("causedById", ""))
	if trace_context.has("causedByName"):
		payload["causedByName"] = String(trace_context.get("causedByName", ""))
	var source_label := String(trace_context.get("sourceLabel", ""))
	if source_label == "":
		source_label = _damage_source_label(source_type)
	var event := {
		"eventId": event_id,
		"kind": "combat",
		"type": "DAMAGE_APPLIED",
		"step": step,
		"round": round_number,
		"phase": phase,
		"actor": actor,
		"target": target_ref,
		"payload": payload,
		"changes": [{
			"path": "units.%s" % String(target_ref.get("id", "")),
			"from": {"hp": hp_before, "shield": shield_before},
			"to": {"hp": hp_after, "shield": shield_after},
			"delta": -hp_damage,
			"damageType": source_type,
			"element": element,
			"packetId": event_id,
			"modifierId": null,
			"source": actor,
			"reason": "damage_resolution",
			"tags": ["battle", "damage"]
		}],
		"source": {"system": "ysbzs_state.gd", "function": "_deal_damage"},
		"reason": "%s_damage_resolution" % source_type,
		"tags": ["battle", "damage"],
		"text": "%s%s%s造成 %d 伤害（护盾 %d，生命 %d；HP %d→%d，护盾 %d→%d）。" % [
			String(actor.get("name", "环境")),
			source_label,
			String(target_ref.get("name", "目标")),
			final_damage,
			shield_damage,
			hp_damage,
			hp_before,
			hp_after,
			shield_before,
			shield_after
		]
	}
	event["protocol"] = damage_protocol(event)
	return event


static func _damage_source_label(source_type: String) -> String:
	match source_type:
		"action":
			return "攻击"
		"skill":
			return "施放技能攻击"
		"skill_combo":
			return "触发技能组合攻击"
		"relic":
			return "通过场下遗物对"
		"element_settlement":
			return "元素结算伤害"
		"element_trap":
			return "元素陷阱伤害"
		_:
			return "对"


static func element_event(step: int, round_number: int, phase: String, source: Dictionary, targets: Array, element: String, layers: int, suppress_projectile: bool = false) -> Dictionary:
	if source.is_empty() or element == "" or targets.is_empty():
		return {}
	var event_id := _event_id(step)
	var actor := unit_ref(source)
	var applied_layers: int = max(1, layers)
	var changes: Array = []
	for target_value in targets:
		var target := Dictionary(target_value)
		var x := int(target.get("x", target.get("c", -1)))
		var y := int(target.get("y", target.get("r", -1)))
		changes.append({
			"path": "cell_elements.%d,%d.%s" % [x, y, element],
			"delta": applied_layers,
			"element": element,
			"source": actor,
			"reason": "action_area_element_application",
			"tags": ["battle", "element", "area"]
		})
	var event := {
		"eventId": event_id,
		"kind": "element_application",
		"type": "ELEMENT_APPLIED",
		"step": step,
		"round": round_number,
		"phase": phase,
		"actor": actor,
		"target": Dictionary(targets[0]),
		"payload": {
			"element": element,
			"layers": applied_layers,
			"targets": targets.duplicate(true),
			"cellCount": targets.size(),
			"sourceType": "action_area",
			"suppressProjectile": suppress_projectile,
			"deferToAttackStrike": suppress_projectile
		},
		"changes": changes,
		"source": {"system": "ysbzs_state.gd", "function": "_execute_selected_action_option"},
		"reason": "action_area_element_application",
		"tags": ["battle", "element", "area", "animation"],
		"text": "%s 同时向%d个作用格铺设%s%d层。" % [String(actor.get("name", "我方")), targets.size(), element, applied_layers]
	}
	event["protocol"] = "|ELEMENT_APPLIED|id=%s|round=%d|phase=%s|actor=%s|cells=%d|element=%s|layers=%d" % [
		event_id,
		round_number,
		phase,
		String(actor.get("id", "")),
		targets.size(),
		element,
		applied_layers
	]
	return event


static func attack_strike_event(step: int, round_number: int, phase: String, source: Dictionary, target_refs: Array, element: String, strike_index: int, strike_count: int) -> Dictionary:
	if source.is_empty() or target_refs.is_empty():
		return {}
	var event_id := _event_id(step)
	var actor := unit_ref(source)
	var event := {
		"eventId": event_id,
		"kind": "combat_animation",
		"type": "ATTACK_STRIKE",
		"step": step,
		"round": round_number,
		"phase": phase,
		"actor": actor,
		"target": Dictionary(target_refs[0]),
		"payload": {
			"element": element,
			"sourceType": "action",
			"strikeIndex": strike_index,
			"strikeCount": strike_count,
			"applyElementOnImpact": true,
			"targets": target_refs.duplicate(true),
			"cellCount": target_refs.size()
		},
		"changes": [],
		"source": {"system": "ysbzs_state.gd", "function": "_execute_selected_action_option"},
		"reason": "action_strike_animation",
		"tags": ["battle", "attack", "animation"],
		"text": "%s 第%d/%d次同时攻击%d个作用格。" % [
			String(actor.get("name", "我方")),
			strike_index,
			strike_count,
			target_refs.size()
		]
	}
	event["protocol"] = "|ATTACK_STRIKE|id=%s|round=%d|phase=%s|actor=%s|cells=%d|strike=%d/%d" % [
		event_id,
		round_number,
		phase,
		String(actor.get("id", "")),
		target_refs.size(),
		strike_index,
		strike_count
	]
	return event


static func skill_event(step: int, round_number: int, phase: String, source: Dictionary, definition: Dictionary, order_index: int, cells: Array) -> Dictionary:
	var event_id := _event_id(step)
	var actor := unit_ref(source)
	var skill_id := String(definition.get("id", ""))
	var skill_name := String(definition.get("name", skill_id))
	var event := {
		"eventId": event_id,
		"kind": "skill",
		"type": "SKILL_TRIGGERED",
		"step": step,
		"round": round_number,
		"phase": phase,
		"actor": actor,
		"target": {},
		"payload": {
			"skillId": skill_id,
			"skillName": skill_name,
			"orderIndex": order_index,
			"shapeSlot": SkillActionRulesScript.action_slot_index(definition),
			"cells": cells.duplicate(true),
		},
		"changes": [],
		"source": {"system": "skill_execution_service.gd", "function": "execute"},
		"reason": "ordered_skill_queue",
		"tags": ["battle", "skill", "animation"],
		"text": "%s 触发第%d技能【%s】。" % [String(actor.get("name", "宠物")), order_index + 1, skill_name],
	}
	event["protocol"] = "|SKILL_TRIGGERED|id=%s|round=%d|phase=%s|actor=%s|skill=%s|order=%d" % [
		event_id,
		round_number,
		phase,
		String(actor.get("id", "")),
		skill_id,
		order_index,
	]
	return event


static func skill_combo_event(step: int, round_number: int, phase: String, source: Dictionary, definition: Dictionary, cells: Array) -> Dictionary:
	var event_id := _event_id(step)
	var actor := unit_ref(source)
	var combo_id := String(definition.get("id", ""))
	var combo_name := String(definition.get("name", combo_id))
	var matched_skill_ids := Array(definition.get("matched_skill_ids", [])).duplicate(true)
	var event := {
		"eventId": event_id,
		"kind": "skill_combo",
		"type": "SKILL_COMBO_TRIGGERED",
		"step": step,
		"round": round_number,
		"phase": phase,
		"actor": actor,
		"target": {},
		"payload": {
			"comboId": combo_id,
			"comboName": combo_name,
			"matchType": String(definition.get("match_type", "skill_ids")),
			"pattern": Array(definition.get("pattern", [])).duplicate(true),
			"matchedSkillIds": matched_skill_ids,
			"startIndex": int(definition.get("start_index", -1)),
			"endIndex": int(definition.get("end_index", -1)),
			"shapeSlot": SkillActionRulesScript.action_slot_index(definition),
			"cells": cells.duplicate(true),
		},
		"changes": [],
		"source": {"system": "skill_execution_service.gd", "function": "execute"},
		"reason": "ordered_skill_combo",
		"tags": ["battle", "skill", "combo", "animation"],
		"text": "%s 触发技能组合【%s】。" % [String(actor.get("name", "宠物")), combo_name],
	}
	event["protocol"] = "|SKILL_COMBO_TRIGGERED|id=%s|round=%d|phase=%s|actor=%s|combo=%s|skills=%s" % [
		event_id,
		round_number,
		phase,
		String(actor.get("id", "")),
		combo_id,
		",".join(PackedStringArray(matched_skill_ids)),
	]
	return event


static func trait_event(step: int, round_number: int, phase: String, source: Dictionary, modifiers: Dictionary, caused_by_id: String, hook: String) -> Dictionary:
	var event_id := _event_id(step)
	var actor := unit_ref(source)
	var trait_ids := Array(modifiers.get("trait_ids", [])).duplicate(true)
	var trait_names := Array(modifiers.get("trait_names", [])).duplicate(true)
	var event := {
		"eventId": event_id,
		"kind": "trait",
		"type": "TRAIT_TRIGGERED",
		"step": step,
		"round": round_number,
		"phase": phase,
		"actor": actor,
		"target": {},
		"payload": {
			"traitIds": trait_ids,
			"traitNames": trait_names,
			"hook": hook,
			"causedById": caused_by_id,
			"physicalPowerBonusPermille": int(modifiers.get("physical_power_bonus_permille", 0)),
			"elementLayerBonus": int(modifiers.get("element_layer_bonus", 0)),
		},
		"changes": [],
		"source": {"system": "trait_service.gd", "function": "modifiers"},
		"reason": "trait_effect_modifier",
		"tags": ["battle", "trait", hook],
		"text": "%s 的特性【%s】生效。" % [String(actor.get("name", "宠物")), "、".join(PackedStringArray(trait_names))],
	}
	event["protocol"] = "|TRAIT_TRIGGERED|id=%s|round=%d|phase=%s|actor=%s|traits=%s|hook=%s|causedBy=%s" % [
		event_id,
		round_number,
		phase,
		String(actor.get("id", "")),
		",".join(PackedStringArray(trait_ids)),
		hook,
		caused_by_id,
	]
	return event


static func effect_event(step: int, round_number: int, phase: String, source: Dictionary, target: Dictionary, effect_type: String, payload: Dictionary) -> Dictionary:
	var event_id := _event_id(step)
	var actor := unit_ref(source)
	var target_ref := unit_ref(target)
	var event := {
		"eventId": event_id,
		"kind": "effect",
		"type": "EFFECT_APPLIED",
		"step": step,
		"round": round_number,
		"phase": phase,
		"actor": actor,
		"target": target_ref,
		"payload": payload.duplicate(true),
		"changes": [],
		"source": {"system": "effect_interpreter.gd", "function": "execute"},
		"reason": effect_type,
		"tags": ["battle", "effect", effect_type],
		"text": "%s 对 %s 施加效果 %s。" % [String(actor.get("name", "宠物")), String(target_ref.get("name", "宠物")), effect_type],
	}
	event["protocol"] = "|EFFECT_APPLIED|id=%s|round=%d|phase=%s|actor=%s|target=%s|effect=%s" % [
		event_id,
		round_number,
		phase,
		String(actor.get("id", "")),
		String(target_ref.get("id", "")),
		effect_type,
	]
	return event


static func relic_event(step: int, round_number: int, phase: String, event_type: String, instance: Dictionary, time_tick: int, trigger: Dictionary) -> Dictionary:
	var event_id := _event_id(step)
	var definition := Dictionary(instance.get("definition", {}))
	var relic_id := String(instance.get("relic_id", definition.get("id", "")))
	var instance_id := String(instance.get("instance_id", ""))
	var relic_name := String(definition.get("name", relic_id if relic_id != "" else "遗物时间轴"))
	var trigger_type := String(trigger.get("event_type", ""))
	var payload := {
		"relicId": relic_id,
		"relicName": relic_name,
		"instanceId": instance_id,
		"side": String(instance.get("side", "")),
		"timeTick": time_tick,
		"triggerType": trigger_type,
		"triggerPayload": Dictionary(trigger.get("payload", {})).duplicate(true),
	}
	var event := {
		"eventId": event_id,
		"kind": "relic",
		"type": event_type,
		"step": step,
		"round": round_number,
		"phase": phase,
		"actor": {"id": instance_id, "name": relic_name, "side": String(instance.get("side", "")), "offBoard": true},
		"target": {},
		"payload": payload,
		"changes": [],
		"source": {"system": "relic_combat_service.gd", "function": "_resolve"},
		"reason": trigger_type,
		"tags": ["battle", "relic", "timeline"],
		"text": "【%s】在逻辑时刻 %d 触发。" % [relic_name, time_tick] if event_type == "RELIC_TRIGGERED" else "遗物事件链保护已触发：%s。" % trigger_type,
	}
	event["protocol"] = "|%s|id=%s|round=%d|phase=%s|time=%d|instance=%s|relic=%s|trigger=%s" % [
		event_type, event_id, round_number, phase, time_tick, instance_id, relic_id, trigger_type
	]
	return event


static func damage_protocol(event: Dictionary) -> String:
	var actor := Dictionary(event.get("actor", {}))
	var target := Dictionary(event.get("target", {}))
	var payload := Dictionary(event.get("payload", {}))
	return "|DAMAGE_APPLIED|id=%s|round=%d|phase=%s|actor=%s|target=%s|hp=%d|shield=%d|element=%s" % [
		String(event.get("eventId", "")),
		int(event.get("round", 0)),
		String(event.get("phase", "")),
		String(actor.get("id", "")),
		String(target.get("id", "")),
		int(payload.get("hpDamage", 0)),
		int(payload.get("shieldDamage", 0)),
		String(payload.get("element", ""))
	]


static func _event_id(step: int) -> String:
	return "bt_%06d" % step
