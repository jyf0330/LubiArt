extends RefCounted

var _handler: RefCounted
var _compatibility: RefCounted


func _init(handler: RefCounted, compatibility: RefCounted) -> void:
	_handler = handler
	_compatibility = compatibility


func execute(port: RefCounted, offer: Dictionary, effect: Dictionary) -> Dictionary:
	if _handler == null or _compatibility == null:
		return {}
	var original_type := String(effect.get("type", ""))
	var normalized := Dictionary(_compatibility.normalize(effect))
	var result := Dictionary(_handler.execute(port, offer, normalized))
	if result.is_empty():
		return {}
	if String(normalized.get("type", "")) != original_type:
		result["type"] = original_type
	return result
