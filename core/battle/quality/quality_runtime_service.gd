extends RefCounted

## Deterministic runtime rules for quality modes and board marks. The caller
## owns the authoritative unit Dictionary; this service only validates and
## mutates that explicit value through one configured strategy registry.

var _registry: RefCounted = null


func configure(registry: RefCounted) -> RefCounted:
	_registry = registry
	return self


func mode_options(unit: Dictionary) -> Array:
	var effect := _effect_for_unit(unit)
	return Array(effect.mode_options).duplicate() if effect != null else []


func supports_mode(unit: Dictionary) -> bool:
	return not mode_options(unit).is_empty()


func stored_mode(unit: Dictionary) -> String:
	if unit.is_empty():
		return ""
	return String(Dictionary(unit.get("quality_runtime", {})).get("mode", ""))


func display_mode(unit: Dictionary) -> String:
	var stored := stored_mode(unit)
	if stored != "":
		return stored
	var options := mode_options(unit)
	return String(options[0]) if not options.is_empty() else ""


func normalize_mode(upgrade_id: String, raw_mode: String) -> String:
	var effect := _effect_for_id(upgrade_id)
	if effect == null:
		return ""
	return effect.normalize_mode(raw_mode)


func try_set_mode(unit: Dictionary, raw_mode: String) -> Dictionary:
	if unit.is_empty() or not supports_mode(unit):
		return {"ok": false, "code": "unsupported"}
	var upgrade_id := String(Dictionary(unit.get("quality_upgrade", {})).get("id", ""))
	var normalized := normalize_mode(upgrade_id, raw_mode)
	if normalized == "":
		return {"ok": false, "code": "unknown_mode"}
	var runtime := Dictionary(unit.get("quality_runtime", {}))
	runtime["mode"] = normalized
	runtime["mode_explicit"] = true
	unit["quality_runtime"] = runtime
	return {"ok": true, "mode": normalized}


func supports_mark(unit: Dictionary) -> bool:
	var effect := _effect_for_unit(unit)
	return bool(effect.supports_mark) if effect != null else false


func mark_for_unit(unit: Dictionary) -> Dictionary:
	if unit.is_empty():
		return {}
	return Dictionary(Dictionary(unit.get("quality_runtime", {})).get("marked_cell", {})).duplicate(true)


func mark_matches_cell(marked_cell: Dictionary, x: int, y: int) -> bool:
	if marked_cell.is_empty():
		return false
	return (
		int(marked_cell.get("x", marked_cell.get("c", -1))) == x
		and int(marked_cell.get("y", marked_cell.get("r", -1))) == y
	)


func mark_matches_unit(marked_cell: Dictionary, unit: Dictionary) -> bool:
	return mark_matches_cell(marked_cell, int(unit.get("x", -2)), int(unit.get("y", -2)))


func try_set_mark(unit: Dictionary, x: int, y: int, slot_index: int, round_number: int) -> Dictionary:
	if unit.is_empty() or not supports_mark(unit):
		return {"ok": false, "code": "unsupported"}
	var normalized := {
		"x": x,
		"y": y,
		"c": x,
		"r": y,
		"key": "%d,%d" % [x, y],
		"slot_index": slot_index,
		"round": round_number,
	}
	var runtime := Dictionary(unit.get("quality_runtime", {}))
	runtime["marked_cell"] = normalized
	unit["quality_runtime"] = runtime
	return {"ok": true, "mark": normalized.duplicate(true)}


func clear_mark(unit: Dictionary) -> bool:
	if unit.is_empty():
		return false
	var runtime := Dictionary(unit.get("quality_runtime", {}))
	if not runtime.has("marked_cell"):
		return false
	runtime.erase("marked_cell")
	unit["quality_runtime"] = runtime
	return true


func _effect_for_unit(unit: Dictionary) -> QualityEffectStrategy:
	if _registry == null or not _registry.has_method(&"effect_for_unit"):
		return null
	return _registry.call(&"effect_for_unit", unit) as QualityEffectStrategy


func _effect_for_id(effect_id: String) -> QualityEffectStrategy:
	if _registry == null or not _registry.has_method(&"effect_for_id"):
		return null
	return _registry.call(&"effect_for_id", effect_id) as QualityEffectStrategy
