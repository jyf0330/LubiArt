extends RefCounted

## Battle-only data world. Component columns are stored separately and indexed by
## stable EntityId values. This is never a second long-lived authority: adapters
## import a command-local slice and explicitly write the accepted result back.

const INVALID_ENTITY := -1

const COMPONENT_IDENTITY := 1 << 0
const COMPONENT_POSITION := 1 << 1
const COMPONENT_CAMP := 1 << 2
const COMPONENT_VITALS := 1 << 3
const COMPONENT_ALIVE := 1 << 4

var _component_masks := PackedInt32Array()
var _source_ids: Array[String] = []
var _source_to_entity: Dictionary = {}

var _position_x := PackedInt32Array()
var _position_y := PackedInt32Array()
var _camps: Array[StringName] = []

var _hp := PackedInt32Array()
var _max_hp := PackedInt32Array()
var _shield := PackedInt32Array()
var _defense := PackedInt32Array()
var _round_damage_taken := PackedInt32Array()

var _pending_damage_packets: Array[Dictionary] = []
var _pending_defeat_candidates: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _revision := 0


func spawn(source_id: String) -> int:
	var normalized_id := source_id.strip_edges()
	if normalized_id.is_empty() or _source_to_entity.has(normalized_id):
		return INVALID_ENTITY
	var entity_id := _component_masks.size()
	_component_masks.append(COMPONENT_IDENTITY)
	_source_ids.append(normalized_id)
	_position_x.append(-1)
	_position_y.append(-1)
	_camps.append(&"")
	_hp.append(0)
	_max_hp.append(0)
	_shield.append(0)
	_defense.append(0)
	_round_damage_taken.append(0)
	_source_to_entity[normalized_id] = entity_id
	_revision += 1
	return entity_id


func entity_count() -> int:
	return _component_masks.size()


func revision() -> int:
	return _revision


func is_valid(entity_id: int) -> bool:
	return entity_id >= 0 and entity_id < _component_masks.size() \
		and (_component_masks[entity_id] & COMPONENT_IDENTITY) != 0


func entity_for_source(source_id: String) -> int:
	return int(_source_to_entity.get(source_id, INVALID_ENTITY))


func source_id(entity_id: int) -> String:
	if not is_valid(entity_id):
		return ""
	return _source_ids[entity_id]


func component_mask(entity_id: int) -> int:
	if not is_valid(entity_id):
		return 0
	return _component_masks[entity_id]


func has_components(entity_id: int, required_mask: int) -> bool:
	return is_valid(entity_id) \
		and (_component_masks[entity_id] & required_mask) == required_mask


func query(required_mask: int) -> Array[int]:
	var matches: Array[int] = []
	for entity_id in range(_component_masks.size()):
		if has_components(entity_id, required_mask):
			matches.append(entity_id)
	return matches


func set_position(entity_id: int, x: int, y: int) -> bool:
	if not is_valid(entity_id):
		return false
	_position_x[entity_id] = x
	_position_y[entity_id] = y
	_component_masks[entity_id] |= COMPONENT_POSITION
	_revision += 1
	return true


func position(entity_id: int) -> Vector2i:
	if not has_components(entity_id, COMPONENT_POSITION):
		return Vector2i(-1, -1)
	return Vector2i(_position_x[entity_id], _position_y[entity_id])


func set_camp(entity_id: int, camp: StringName) -> bool:
	if not is_valid(entity_id):
		return false
	_camps[entity_id] = camp
	_component_masks[entity_id] |= COMPONENT_CAMP
	_revision += 1
	return true


func camp(entity_id: int) -> StringName:
	if not has_components(entity_id, COMPONENT_CAMP):
		return &""
	return _camps[entity_id]


func set_vitals(
	entity_id: int,
	hp: int,
	max_hp: int,
	shield: int,
	defense: int,
	round_damage_taken: int = 0
) -> bool:
	if not is_valid(entity_id):
		return false
	_hp[entity_id] = max(0, hp)
	_max_hp[entity_id] = max(_hp[entity_id], max_hp)
	_shield[entity_id] = max(0, shield)
	_defense[entity_id] = max(0, defense)
	_round_damage_taken[entity_id] = max(0, round_damage_taken)
	_component_masks[entity_id] |= COMPONENT_VITALS
	_revision += 1
	return true


func vitals(entity_id: int) -> Dictionary:
	if not has_components(entity_id, COMPONENT_VITALS):
		return {}
	return {
		"hp": _hp[entity_id],
		"maxHp": _max_hp[entity_id],
		"shield": _shield[entity_id],
		"defense": _defense[entity_id],
		"roundDamageTaken": _round_damage_taken[entity_id],
		"alive": is_alive(entity_id)
	}


func write_vitals(
	entity_id: int,
	hp: int,
	shield: int,
	round_damage_taken: int
) -> bool:
	if not has_components(entity_id, COMPONENT_VITALS):
		return false
	_hp[entity_id] = clampi(hp, 0, _max_hp[entity_id])
	_shield[entity_id] = max(0, shield)
	_round_damage_taken[entity_id] = max(0, round_damage_taken)
	_revision += 1
	return true


func set_alive(entity_id: int, value: bool) -> bool:
	if not has_components(entity_id, COMPONENT_VITALS):
		return false
	var was_alive := is_alive(entity_id)
	if value:
		_component_masks[entity_id] |= COMPONENT_ALIVE
	else:
		_component_masks[entity_id] &= ~COMPONENT_ALIVE
	if was_alive != value:
		_revision += 1
	return true


func is_alive(entity_id: int) -> bool:
	return has_components(entity_id, COMPONENT_VITALS | COMPONENT_ALIVE)


func queue_resolved_damage(
	source_entity: int,
	target_entity: int,
	resolved_amount: int,
	element: String = "",
	context: Dictionary = {}
) -> bool:
	if not has_components(target_entity, COMPONENT_VITALS) or resolved_amount <= 0:
		return false
	_pending_damage_packets.append({
		"sourceEntity": source_entity,
		"targetEntity": target_entity,
		"resolvedAmount": resolved_amount,
		"element": element,
		"context": context.duplicate(true)
	})
	return true


func take_pending_damage_packets() -> Array[Dictionary]:
	var packets := _pending_damage_packets
	_pending_damage_packets = []
	return packets


func pending_damage_count() -> int:
	return _pending_damage_packets.size()


func queue_defeat_candidate(
	source_entity: int,
	target_entity: int,
	context: Dictionary = {}
) -> bool:
	if not has_components(target_entity, COMPONENT_VITALS):
		return false
	_pending_defeat_candidates.append({
		"sourceEntity": source_entity,
		"targetEntity": target_entity,
		"context": context.duplicate(true)
	})
	return true


func take_defeat_candidates() -> Array[Dictionary]:
	var candidates := _pending_defeat_candidates
	_pending_defeat_candidates = []
	return candidates


func emit_event(event: Dictionary) -> void:
	var entry := event.duplicate(true)
	entry["sequence"] = _events.size() + 1
	_events.append(entry)


func event_count() -> int:
	return _events.size()


func events_since(index: int = 0) -> Array:
	var start := clampi(index, 0, _events.size())
	var result: Array = []
	for event_index in range(start, _events.size()):
		result.append(_events[event_index].duplicate(true))
	return result


func data_snapshot() -> Dictionary:
	var entities: Array = []
	for entity_id in range(_component_masks.size()):
		if not is_valid(entity_id):
			continue
		var row := {
			"entityId": entity_id,
			"sourceId": source_id(entity_id),
			"componentMask": component_mask(entity_id)
		}
		if has_components(entity_id, COMPONENT_POSITION):
			row["position"] = {
				"x": _position_x[entity_id],
				"y": _position_y[entity_id]
			}
		if has_components(entity_id, COMPONENT_CAMP):
			row["camp"] = String(_camps[entity_id])
		if has_components(entity_id, COMPONENT_VITALS):
			row["vitals"] = vitals(entity_id)
		entities.append(row)
	return {
		"revision": _revision,
		"entities": entities
	}
