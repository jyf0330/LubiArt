extends RefCounted

const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")

var _stat_resolver: RefCounted
var _modifier_collector: RefCounted
var _cache: Dictionary = {}
var _cache_epoch := ""


func configure(stat_resolver: RefCounted, modifier_collector: RefCounted) -> RefCounted:
	_stat_resolver = stat_resolver
	_modifier_collector = modifier_collector
	return self


func value(unit: Dictionary, data: Dictionary, stat_id: String, hook: String, context: Dictionary = {}, extra_modifiers: Array = []) -> int:
	return int(resolve(unit, data, stat_id, hook, context, extra_modifiers).get("value", 0))


func resolve(unit: Dictionary, data: Dictionary, stat_id: String, hook: String, context: Dictionary = {}, extra_modifiers: Array = []) -> Dictionary:
	var effective_context := context.duplicate(true)
	effective_context["unit"] = unit
	effective_context[EffectVocabularyScript.FIELD_HOOK] = hook
	var cache_key := _cache_key(unit, hook, stat_id, effective_context, extra_modifiers)
	if cache_key != "" and _cache.has(cache_key):
		return Dictionary(_cache[cache_key]).duplicate(true)
	var modifiers := _merged_modifiers(unit, data, hook, effective_context, extra_modifiers)
	var result := Dictionary(_stat_resolver.resolve(unit, stat_id, Dictionary(data.get("stat_catalog", {})), modifiers, effective_context))
	if cache_key != "": _cache[cache_key] = result.duplicate(true)
	return result


func resolve_all(unit: Dictionary, data: Dictionary, hook: String, context: Dictionary = {}, extra_modifiers: Array = []) -> Dictionary:
	var effective_context := context.duplicate(true)
	effective_context["unit"] = unit
	effective_context[EffectVocabularyScript.FIELD_HOOK] = hook
	var cache_key := _cache_key(unit, hook, "*", effective_context, extra_modifiers)
	if cache_key != "" and _cache.has(cache_key):
		return Dictionary(_cache[cache_key]).duplicate(true)
	var modifiers := _merged_modifiers(unit, data, hook, effective_context, extra_modifiers)
	var result := Dictionary(_stat_resolver.resolve_all(unit, Dictionary(data.get("stat_catalog", {})), modifiers, effective_context))
	if cache_key != "": _cache[cache_key] = result.duplicate(true)
	return result


func values_from_resolved(resolved: Dictionary) -> Dictionary:
	return Dictionary(_stat_resolver.values_from_resolved(resolved))


func breakdown_from_resolved(resolved: Dictionary) -> Dictionary:
	return Dictionary(_stat_resolver.breakdown_from_resolved(resolved))


func _merged_modifiers(unit: Dictionary, data: Dictionary, hook: String, context: Dictionary, extras: Array) -> Array:
	var collected := Dictionary(_modifier_collector.collect(unit, data, hook, context))
	var result: Array = Array(collected.get("modifiers", [])).duplicate(true)
	var known := {}
	for value in result:
		var instance_id := String(Dictionary(value).get("instance_id", ""))
		if instance_id != "": known[instance_id] = true
	for value in extras:
		var modifier := Dictionary(value)
		var instance_id := String(modifier.get("instance_id", ""))
		if instance_id == "" or not known.has(instance_id): result.append(modifier)
	return result


func _cache_key(unit: Dictionary, hook: String, stat_id: String, context: Dictionary, extras: Array) -> String:
	if not extras.is_empty():
		return ""
	var epoch := String(context.get("cache_key", ""))
	if epoch == "":
		return ""
	if epoch != _cache_epoch:
		_cache_epoch = epoch
		_cache.clear()
	return "%s|%s|%s" % [String(unit.get("id", "")), hook, stat_id]


func cache_size() -> int:
	return _cache.size()
