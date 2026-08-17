extends RefCounted

## Pure diff and damage-source projection for PREVIEW_MANUAL_FLOW.

const PreviewHorizonScript := preload("res://core/commands/preview_horizon.gd")


func cell_diffs(before_rows: Array, after_rows: Array) -> Array:
	var before_by_key := _rows_by_key(before_rows, Callable(self, "_cell_key"))
	var after_by_key := _rows_by_key(after_rows, Callable(self, "_cell_key"))
	var keys := _combined_keys(before_by_key, after_by_key, true)
	var result: Array = []
	for key in keys:
		var before_value: Variant = before_by_key.get(key, null)
		var after_value: Variant = after_by_key.get(key, null)
		if _stable_json(before_value) == _stable_json(after_value):
			continue
		var source := Dictionary(after_value) if after_value is Dictionary else (Dictionary(before_value) if before_value is Dictionary else {})
		result.append({
			"r": int(source.get("r", source.get("y", 0))),
			"c": int(source.get("c", source.get("x", 0))),
			"key": key,
			"before": before_value,
			"after": after_value,
		})
	return result


func unit_diffs(before_rows: Array, after_rows: Array, events: Array) -> Array:
	var before_by_key := _rows_by_key(before_rows, Callable(self, "_unit_key"))
	var after_by_key := _rows_by_key(after_rows, Callable(self, "_unit_key"))
	var threats_by_target := _threats_by_target(events)
	var result: Array = []
	for unit_id in _combined_keys(before_by_key, after_by_key, false):
		var before_value: Variant = before_by_key.get(unit_id, null)
		var after_value: Variant = after_by_key.get(unit_id, null)
		if _stable_json(before_value) == _stable_json(after_value):
			continue
		var row := {"id": unit_id, "before": before_value, "after": after_value}
		var threats: Array = Array(threats_by_target.get(unit_id, [])).duplicate(true)
		var enemy_ids: Array = []
		for threat_value in threats:
			var enemy_id := String(Dictionary(threat_value).get("enemyId", ""))
			if enemy_id != "" and not enemy_ids.has(enemy_id):
				enemy_ids.append(enemy_id)
		row["enemyIds"] = enemy_ids
		row["threats"] = threats
		if not threats.is_empty():
			row["damageSummary"] = _damage_summary(row, threats)
		result.append(row)
	return result


func damage_by_unit(unit_diff_rows: Array) -> Dictionary:
	var result := {}
	for diff_value in unit_diff_rows:
		if not diff_value is Dictionary:
			continue
		var diff := Dictionary(diff_value)
		var summary := Dictionary(diff.get("damageSummary", {}))
		var unit_id := String(diff.get("id", ""))
		if unit_id != "" and not summary.is_empty():
			result[unit_id] = summary.duplicate(true)
	return result


func _rows_by_key(rows: Array, key_fn: Callable) -> Dictionary:
	var result := {}
	for value in rows:
		if not value is Dictionary:
			continue
		var row := Dictionary(value)
		var key := String(key_fn.call(row))
		if key != "":
			result[key] = row
	return result


func _combined_keys(before_by_key: Dictionary, after_by_key: Dictionary, sort_keys: bool) -> Array:
	var keys: Array = []
	for key in before_by_key.keys():
		keys.append(key)
	for key in after_by_key.keys():
		if not keys.has(key):
			keys.append(key)
	if sort_keys:
		keys.sort()
	return keys


func _cell_key(row: Dictionary) -> String:
	if row.has("key"):
		return String(row.get("key", ""))
	return "%d,%d" % [int(row.get("r", row.get("y", 0))), int(row.get("c", row.get("x", 0)))]


func _unit_key(row: Dictionary) -> String:
	return String(row.get("id", ""))


func _stable_json(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _threats_by_target(events: Array) -> Dictionary:
	var result := {}
	for value in events:
		if not value is Dictionary:
			continue
		var threat := _damage_threat(Dictionary(value))
		var target_id := String(threat.get("targetId", ""))
		if target_id == "":
			continue
		var rows: Array = Array(result.get(target_id, []))
		rows.append(threat)
		result[target_id] = rows
	return result


func _damage_threat(event: Dictionary) -> Dictionary:
	if not ["DAMAGE", "DAMAGE_APPLIED"].has(String(event.get("type", ""))):
		return {}
	var payload := Dictionary(event.get("payload", {}))
	var actor := Dictionary(event.get("actor", {}))
	var target := Dictionary(event.get("target", {}))
	var target_id := String(event.get("targetId", target.get("id", "")))
	if target_id == "":
		return {}
	var shield_damage: int = max(0, int(payload.get("shieldDamage", payload.get("shield_damage", 0))))
	var hp_damage: int = max(0, int(payload.get("hpDamage", payload.get("hp_damage", 0))))
	var damage := shield_damage + hp_damage
	if damage <= 0:
		damage = max(0, int(payload.get("finalDamage", payload.get("final", payload.get("damage", 0)))))
	if damage <= 0:
		return {}
	var enemy_id := String(event.get("sourceId", actor.get("id", "")))
	var enemy_name := String(actor.get("name", enemy_id))
	return {
		"enemyId": enemy_id,
		"enemyName": enemy_name,
		"unitId": enemy_id,
		"unitName": enemy_name,
		"targetId": target_id,
		"damage": damage,
		"shieldDamage": shield_damage,
		"hpDamage": hp_damage,
		"raw": int(payload.get("rawDamage", payload.get("raw", damage))),
		"final": damage,
		"element": payload.get("element", event.get("element", null)),
		"slotId": event.get("slotId", null),
		"slotLabel": event.get("slotLabel", null),
		"shapeId": event.get("shapeId", null),
		"shapeName": event.get("shapeName", null),
		"direction": event.get("direction", null),
		"cells": Array(event.get("cells", [])).duplicate(true),
		"actionEventId": event.get("actionEventId", null),
		"damageEventId": event.get("eventId", null),
		"step": event.get("step", null),
	}


func _damage_summary(unit_diff: Dictionary, threats: Array) -> Dictionary:
	var before := Dictionary(unit_diff.get("before", {})) if unit_diff.get("before") is Dictionary else {}
	var after := Dictionary(unit_diff.get("after", {})) if unit_diff.get("after") is Dictionary else {}
	var total_damage := 0
	var raw_damage := 0
	var hp_damage := 0
	var shield_damage := 0
	for threat_value in threats:
		var threat := Dictionary(threat_value)
		total_damage += max(0, int(threat.get("final", threat.get("damage", 0))))
		raw_damage += max(0, int(threat.get("raw", threat.get("damage", 0))))
		hp_damage += max(0, int(threat.get("hpDamage", 0)))
		shield_damage += max(0, int(threat.get("shieldDamage", 0)))
	var hp_from: int = max(0, int(before.get("hp", 0)))
	var hp_to: int = max(0, int(after.get("hp", 0))) if not after.is_empty() else 0
	var shield_from: int = max(0, int(before.get("shield", 0)))
	var shield_to: int = max(0, int(after.get("shield", 0))) if not after.is_empty() else 0
	return {
		"source": "manual_flow_preview",
		"previewHorizon": PreviewHorizonScript.MANUAL_ROUND_FLOW,
		"unitId": String(unit_diff.get("id", "")),
		"totalDamage": total_damage,
		"damage": total_damage,
		"threat": total_damage,
		"rawDamage": raw_damage,
		"hpDamage": hp_damage,
		"shieldDamage": shield_damage,
		"hpFrom": hp_from,
		"hpTo": hp_to,
		"shieldFrom": shield_from,
		"shieldTo": shield_to,
		"lethal": hp_from > 0 and hp_to <= 0,
		"hits": threats.duplicate(true),
	}
