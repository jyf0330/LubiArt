extends RefCounted

var _modifier_collector: RefCounted
var _effect_interpreter: RefCounted


func configure(modifier_collector: RefCounted, effect_interpreter: RefCounted) -> RefCounted:
	_modifier_collector = modifier_collector
	_effect_interpreter = effect_interpreter
	return self


func collect(unit: Dictionary, data: Dictionary, hook: String, context: Dictionary = {}) -> Dictionary:
	return Dictionary(_modifier_collector.collect(unit, data, hook, context))


func execute(port: RefCounted, context: Dictionary, collected: Dictionary) -> bool:
	return bool(_effect_interpreter.execute(port, context, Array(collected.get("trigger_effects", []))))
