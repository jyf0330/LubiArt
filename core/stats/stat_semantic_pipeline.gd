extends RefCounted

const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")
const CONSUMER_DIRECTORY := "res://core/stats/consumers"

var _registry: RefCounted = ScriptPluginRegistryScript.new().configure(CONSUMER_DIRECTORY)


func apply(event_id: String, context: Dictionary) -> Dictionary:
	var result := context.duplicate()
	var consumers: Array = []
	for plugin_value in _registry.plugins():
		var plugin := plugin_value as RefCounted
		if plugin != null and plugin.has_method(&"event_id") and String(plugin.call(&"event_id")) == event_id:
			consumers.append(plugin)
	consumers.sort_custom(func(left: RefCounted, right: RefCounted) -> bool:
		var left_order := int(left.call(&"order")) if left.has_method(&"order") else 100
		var right_order := int(right.call(&"order")) if right.has_method(&"order") else 100
		if left_order != right_order:
			return left_order < right_order
		return String(left.call(&"plugin_id")) < String(right.call(&"plugin_id"))
	)
	for consumer in consumers:
		var next: Variant = consumer.call(&"apply", result)
		if next is Dictionary:
			result = Dictionary(next)
	return result


func consumed_stat_ids(event_id: String = "") -> Array[String]:
	var result: Array[String] = []
	for plugin_value in _registry.plugins():
		var plugin := plugin_value as RefCounted
		if plugin == null or not plugin.has_method(&"consumed_stats"):
			continue
		if event_id != "" and (not plugin.has_method(&"event_id") or String(plugin.call(&"event_id")) != event_id):
			continue
		for value in Array(plugin.call(&"consumed_stats")):
			var stat_id := String(value)
			if stat_id != "" and not result.has(stat_id):
				result.append(stat_id)
	result.sort()
	return result


func is_valid() -> bool:
	return bool(_registry.call(&"is_valid"))
