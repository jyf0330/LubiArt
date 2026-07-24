extends RefCounted

## Maps trace event types (and optional kinds) to controller callables. The
## queue remains the sequencing authority; this registry only selects behavior.

var _sequence_handlers: Dictionary = {}
var _instant_handlers: Dictionary = {}


func register_sequence(event_type: String, handler: Callable) -> bool:
	return _register(_sequence_handlers, event_type, handler)


func register_sequence_kind(kind: String, handler: Callable) -> bool:
	return _register(_sequence_handlers, _kind_key(kind), handler)


func register_instant(event_type: String, handler: Callable) -> bool:
	return _register(_instant_handlers, event_type, handler)


func register_instant_kind(kind: String, handler: Callable) -> bool:
	return _register(_instant_handlers, _kind_key(kind), handler)


func sequence_handler(event_type: String, kind: String = "") -> Callable:
	return _resolve(_sequence_handlers, event_type, kind)


func instant_handler(event_type: String, kind: String = "") -> Callable:
	return _resolve(_instant_handlers, event_type, kind)


func sequence_event_types() -> Array[String]:
	return _event_type_keys(_sequence_handlers)


func instant_event_types() -> Array[String]:
	return _event_type_keys(_instant_handlers)


func _register(target: Dictionary, key: String, handler: Callable) -> bool:
	if key.is_empty() or not handler.is_valid() or target.has(key):
		return false
	target[key] = handler
	return true


func _resolve(target: Dictionary, event_type: String, kind: String) -> Callable:
	if target.has(event_type):
		return target[event_type] as Callable
	var kind_key := _kind_key(kind)
	if not kind.is_empty() and target.has(kind_key):
		return target[kind_key] as Callable
	return Callable()


func _event_type_keys(target: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key_value in target.keys():
		var key := String(key_value)
		if not key.begins_with("kind:"):
			keys.append(key)
	keys.sort()
	return keys


func _kind_key(kind: String) -> String:
	return "kind:%s" % kind
