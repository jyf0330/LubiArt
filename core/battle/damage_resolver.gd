extends RefCounted

const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const DamageResultScript := preload("res://core/battle/damage_result.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")

## Deterministic unified damage pipeline. One versioned port supplies the
## surrounding authority capabilities; orthogonal props alter only their
## declared stages. Death resolution deliberately happens after this primitive.

const PORT_CONTRACT_ID := &"ysbzs.damage-resolution-port.v2"
const PREVIEW_PORT_CONTRACT_ID := &"ysbzs.damage-preview-port.v1"
const CALCULATION_PHYSICAL := "physical"
const CALCULATION_ELEMENTAL := "elemental"
const REQUIRED_PORT_METHODS: Array[StringName] = [
	&"contract_id",
	&"leader_guard_active",
	&"leader_guarded_damage_packet",
	&"before_damage",
	&"stat_value",
	&"apply_stat_semantics",
	&"is_boss",
	&"heal_source",
	&"sync_leader_hp",
	&"record_trace",
	&"on_shield_break",
	&"after_damage",
	&"after_hit",
]
const REQUIRED_PREVIEW_PORT_METHODS: Array[StringName] = [
	&"contract_id",
	&"leader_guard_active",
	&"leader_guarded_damage_packet",
	&"stat_value",
	&"apply_stat_semantics",
	&"is_boss",
]


func resolve(
	port: RefCounted,
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String = "",
	consume_incoming_bonus: bool = true,
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> Dictionary:
	var props := DamagePropsScript.normalize(damage_props)
	if target.is_empty() or amount <= 0 or not _accepts(port):
		return DamageResultScript.empty(props)
	var incoming_bonus: int = max(0, int(target.get("incoming_damage_bonus", 0))) if consume_incoming_bonus else 0
	var calculation_kind := _calculation_kind(trace_context, element)
	if incoming_bonus > 0:
		target["incoming_damage_bonus"] = 0
	var raw: int = max(0, amount + incoming_bonus)
	var phases := {
		"base": max(0, amount),
		"after_incoming_bonus": raw,
	}
	var fallback_event_seed := "%s:%s:%s:%s" % [
		_value_string(source.get("id")),
		_value_string(target.get("id")),
		_value_string(trace_context.get("sourceType"), "damage"),
		_value_string(trace_context.get("strikeIndex"), "0")
	]
	var raw_event_seed: Variant = trace_context.get("eventSeed")
	var event_seed: String = fallback_event_seed if raw_event_seed == null else String(raw_event_seed)
	var outgoing := {
		"source": source,
		"target": target,
		"target_is_boss": bool(port.is_boss(target)),
		"amount": raw,
		"element": element,
		"calculation_kind": calculation_kind,
		"event_seed": event_seed,
		"damage_props": props,
	}
	if DamagePropsScript.is_powered(props):
		outgoing = Dictionary(port.apply_stat_semantics(EffectHookIdsScript.DAMAGE_OUTGOING, outgoing))
	raw = max(0, int(outgoing.get("amount", raw)))
	phases["after_outgoing"] = raw
	var leader_guard_applied := bool(port.leader_guard_active(target)) and raw > 4
	if leader_guard_applied:
		raw = int(port.leader_guarded_damage_packet(target, raw))
	phases["after_leader_guard"] = raw
	var guard: int = max(0, int(target.get("guard_reduction", 0)))
	var after_guard: int = max(0, raw - guard)
	if guard > 0:
		target["guard_reduction"] = 0
	phases["after_guard_reduction"] = after_guard
	var mechanic_result := Dictionary(port.before_damage(target, source, after_guard, element, props))
	var after_mechanic: int = max(0, int(mechanic_result.get("damage", after_guard)))
	phases["after_mechanics"] = after_mechanic
	var defense_context := {
		"hook": EffectHookIdsScript.BEFORE_DAMAGE,
		"source": source,
		"target": target,
		"element": element,
		"calculation_kind": calculation_kind,
		"damage_props": props,
	}
	var defense: int = max(0, int(port.stat_value(target, "def", defense_context, int(target.get("def", 0)))))
	var pierce_flat: int = max(0, int(port.stat_value(source, "armor_pierce_flat", defense_context, 0)))
	var pierce_permille := clampi(int(port.stat_value(source, "armor_pierce_permille", defense_context, 0)), 0, 1000)
	var effective_defense: int = max(0, _round_permille(defense, 1000 - pierce_permille) - pierce_flat)
	var after_def: int = max(0, after_mechanic - effective_defense)
	after_def = _round_permille(after_def, max(0, int(port.stat_value(target, "damage_taken_permille", defense_context, 1000))))
	if calculation_kind == CALCULATION_PHYSICAL:
		after_def = _round_permille(after_def, max(0, int(port.stat_value(target, "physical_taken_permille", defense_context, 1000))))
	else:
		after_def = _round_permille(after_def, max(0, int(port.stat_value(target, "element_taken_permille", defense_context, 1000))))
		var resistance_id := _element_resistance_stat(element)
		if resistance_id != "":
			var resistance := clampi(int(port.stat_value(target, resistance_id, defense_context, 0)), -1000, 1000)
			after_def = _round_permille(after_def, 1000 - resistance)
	phases["after_defense"] = after_def
	var incoming := Dictionary(port.apply_stat_semantics(EffectHookIdsScript.DAMAGE_INCOMING, {
		"source": source,
		"target": target,
		"amount": after_def,
		"element": element,
		"event_seed": event_seed,
		"damage_props": props,
	}))
	after_def = max(0, int(incoming.get("amount", after_def)))
	phases["after_incoming"] = after_def
	var shield_before: int = max(0, int(target.get("shield", 0)))
	var shield_damage: int = min(shield_before, after_def) if DamagePropsScript.is_blockable(props) else 0
	target["shield"] = shield_before - shield_damage
	var unblocked_damage: int = max(0, after_def - shield_damage)
	var hp_before: int = max(0, int(target.get("hp", 0)))
	if unblocked_damage > 0:
		target["hp"] = max(0, hp_before - unblocked_damage)
		var round_damage_taken: int = max(0, int(target.get("roundDamageTaken", target.get("round_damage_taken", 0)))) + unblocked_damage
		target["roundDamageTaken"] = round_damage_taken
		target["round_damage_taken"] = round_damage_taken
	port.sync_leader_hp(target)
	phases["after_block"] = unblocked_damage
	phases["hp_after"] = int(target.get("hp", hp_before))
	var effective_trace_context := trace_context.duplicate(true)
	effective_trace_context["calculationKind"] = calculation_kind
	for key in ["critical", "critical_roll", "dodged", "dodge_roll", "blocked", "block_roll", "block_value_applied"]:
		if outgoing.has(key):
			effective_trace_context[key] = outgoing[key]
		if incoming.has(key):
			effective_trace_context[key] = incoming[key]
	port.record_trace(
		source,
		target,
		raw,
		shield_damage,
		unblocked_damage,
		hp_before,
		int(target.get("hp", hp_before)),
		shield_before,
		int(target.get("shield", 0)),
		element,
		effective_trace_context
	)
	var after_semantic := Dictionary(port.apply_stat_semantics(EffectHookIdsScript.DAMAGE_AFTER, {
		"source": source,
		"target": target,
		"hp_damage": unblocked_damage,
		"shield_damage": shield_damage,
		"event_seed": event_seed,
		"damage_props": props,
	}))
	var lifesteal_heal: int = max(0, int(after_semantic.get("lifesteal_heal", 0)))
	if lifesteal_heal > 0:
		port.heal_source(source, lifesteal_heal)
	var mechanic_logs: Array = Array(mechanic_result.get("logs", [])).duplicate()
	if leader_guard_applied:
		mechanic_logs.append("%s 的宠物护卫生效，本次伤害限制为4。" % String(target.get("name", "英雄")))
	if shield_before > 0 and shield_damage > 0 and int(target.get("shield", 0)) <= 0:
		_append_lines(mechanic_logs, port.on_shield_break(target, source))
	_append_lines(mechanic_logs, port.after_damage(target, source, unblocked_damage, props))
	_append_lines(mechanic_logs, port.after_hit(target, source, shield_damage + unblocked_damage, props))
	return DamageResultScript.build({
		"raw": raw,
		"modified_damage": after_def,
		"guard_reduction": guard,
		"shield_damage": shield_damage,
		"unblocked_damage": max(0, hp_before - int(target.get("hp", hp_before))),
		"hp_damage": unblocked_damage,
		"hp_before": hp_before,
		"hp_after": int(target.get("hp", hp_before)),
		"shield_before": shield_before,
		"shield_after": int(target.get("shield", 0)),
		"element": element,
		"incoming_bonus": incoming_bonus,
		"leader_guard_applied": leader_guard_applied,
		"mechanic_logs": mechanic_logs,
		"pending_death": hp_before > 0 and int(target.get("hp", 0)) <= 0,
		"receiver": _unit_ref(target),
		"props": props,
		"phases": phases,
		"final": shield_damage + unblocked_damage,
	})


func preview(
	port: RefCounted,
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String = "",
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> Dictionary:
	var props := DamagePropsScript.normalize(damage_props)
	if target.is_empty() or amount <= 0 or not _accepts_preview(port):
		return DamageResultScript.empty(props)
	var calculation_kind := _calculation_kind(trace_context, element)
	var fallback_event_seed := "%s:%s:%s:%s" % [
		_value_string(source.get("id")),
		_value_string(target.get("id")),
		_value_string(trace_context.get("sourceType"), "preview"),
		_value_string(trace_context.get("strikeIndex"), "0")
	]
	var raw_event_seed: Variant = trace_context.get("eventSeed")
	var event_seed: String = fallback_event_seed if raw_event_seed == null else String(raw_event_seed)
	var outgoing := {
		"source": source,
		"target": target,
		"target_is_boss": bool(port.is_boss(target)),
		"amount": max(0, amount),
		"element": element,
		"calculation_kind": calculation_kind,
		"event_seed": event_seed,
		"damage_props": props,
	}
	if DamagePropsScript.is_powered(props):
		outgoing = Dictionary(port.apply_stat_semantics(EffectHookIdsScript.DAMAGE_OUTGOING, outgoing))
	var raw: int = max(0, int(outgoing.get("amount", amount)))
	if bool(port.leader_guard_active(target)) and raw > 4:
		raw = int(port.leader_guarded_damage_packet(target, raw))
	var defense_context := {
		"hook": EffectHookIdsScript.DAMAGE_PREVIEW,
		"source": source,
		"target": target,
		"element": element,
		"calculation_kind": calculation_kind,
		"damage_props": props,
	}
	var defense: int = max(0, int(port.stat_value(target, "def", defense_context, int(target.get("def", 0)))))
	var pierce_flat: int = max(0, int(port.stat_value(source, "armor_pierce_flat", defense_context, 0)))
	var pierce_permille := clampi(int(port.stat_value(source, "armor_pierce_permille", defense_context, 0)), 0, 1000)
	var final: int = max(0, raw - max(0, _round_permille(defense, 1000 - pierce_permille) - pierce_flat))
	final = _round_permille(final, max(0, int(port.stat_value(target, "damage_taken_permille", defense_context, 1000))))
	if calculation_kind == CALCULATION_PHYSICAL:
		final = _round_permille(final, max(0, int(port.stat_value(target, "physical_taken_permille", defense_context, 1000))))
	else:
		final = _round_permille(final, max(0, int(port.stat_value(target, "element_taken_permille", defense_context, 1000))))
		var resistance_id := _element_resistance_stat(element)
		if resistance_id != "":
			final = _round_permille(final, 1000 - clampi(int(port.stat_value(target, resistance_id, defense_context, 0)), -1000, 1000))
	var incoming := Dictionary(port.apply_stat_semantics(EffectHookIdsScript.DAMAGE_INCOMING, {
		"source": source,
		"target": target,
		"amount": final,
		"element": element,
		"event_seed": event_seed,
		"damage_props": props,
	}))
	final = max(0, int(incoming.get("amount", final)))
	var shield_damage: int = min(max(0, int(target.get("shield", 0))), final) if DamagePropsScript.is_blockable(props) else 0
	var unblocked_damage: int = max(0, final - shield_damage)
	var hp_before: int = max(0, int(target.get("hp", 0)))
	var hp_after: int = max(0, hp_before - unblocked_damage)
	var result := DamageResultScript.build({
		"raw": raw,
		"modified_damage": final,
		"shield_damage": shield_damage,
		"unblocked_damage": max(0, hp_before - hp_after),
		"hp_damage": unblocked_damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"shield_before": max(0, int(target.get("shield", 0))),
		"shield_after": max(0, int(target.get("shield", 0)) - shield_damage),
		"receiver": _unit_ref(target),
		"props": props,
		"element": element,
		"final": shield_damage + unblocked_damage,
	})
	result["outgoing"] = outgoing
	result["incoming"] = incoming
	return result


func _accepts(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.call(&"contract_id")) == PORT_CONTRACT_ID


func _accepts_preview(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PREVIEW_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.call(&"contract_id")) == PREVIEW_PORT_CONTRACT_ID


func _append_lines(target_lines: Array, lines: Array) -> void:
	for line in lines:
		target_lines.append(String(line))


func _round_permille(value: int, permille: int) -> int:
	var product := value * permille
	return int((product + 500) / 1000) if product >= 0 else -int((-product + 500) / 1000)


func _element_resistance_stat(element: String) -> String:
	match element:
		"火": return "fire_resistance_permille"
		"水": return "water_resistance_permille"
		"雷": return "wind_resistance_permille"
		"地": return "earth_resistance_permille"
		"草": return "wood_resistance_permille"
		"冰": return "ice_resistance_permille"
		"暗": return "dark_resistance_permille"
		"龙": return "dragon_resistance_permille"
	return ""


func _calculation_kind(trace_context: Dictionary, element: String) -> String:
	var declared := String(trace_context.get("calculationKind", trace_context.get("calculation_kind", ""))).strip_edges().to_lower()
	if [CALCULATION_PHYSICAL, CALCULATION_ELEMENTAL].has(declared):
		return declared
	return CALCULATION_PHYSICAL if element == "" else CALCULATION_ELEMENTAL


func _unit_ref(unit: Dictionary) -> Dictionary:
	return {
		"id": String(unit.get("id", "")),
		"name": String(unit.get("name", unit.get("id", ""))),
		"side": String(unit.get("side", "")),
	}


func _value_string(value: Variant, fallback: String = "") -> String:
	if value == null:
		return fallback
	var text := str(value)
	return fallback if text == "" else text
