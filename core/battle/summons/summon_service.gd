extends RefCounted

## Creates summoned units directly in the single authoritative units array via
## SummonPort. No secondary roster or battle store is introduced.

const PORT_CONTRACT_ID := &"ysbzs.summon-port.v1"
const REQUIRED_PORT_METHODS: Array[StringName] = [
	&"contract_id",
	&"inside",
	&"unit_at",
	&"mechanic_param_int",
	&"mechanic_param_string",
	&"apply_summon_semantics",
	&"player_side",
	&"unit_count",
	&"append_unit",
]


func first_empty_near(port: RefCounted, unit: Dictionary, include_origin: bool = true) -> Dictionary:
	if not _accepts(port) or unit.is_empty():
		return {}
	var origin_x := int(unit.get("x", -1))
	var origin_y := int(unit.get("y", -1))
	var offsets: Array = []
	if include_origin:
		offsets.append(Vector2i.ZERO)
	offsets.append_array([Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP])
	for offset_value in offsets:
		var offset := Vector2i(offset_value)
		var x := origin_x + offset.x
		var y := origin_y + offset.y
		if bool(port.inside(x, y)) and Dictionary(port.unit_at(x, y)).is_empty():
			return {"x": x, "y": y}
	return {}


func first_adjacent_empty(port: RefCounted, unit: Dictionary) -> Dictionary:
	return first_empty_near(port, unit, false)


func summon_unit_on_cell(
	port: RefCounted,
	caster: Dictionary,
	mechanism: Dictionary,
	cell: Dictionary,
	default_summon_id: String = "ally_sprite",
	display_name: String = "小灵",
	default_hp: int = 6,
	default_atk: int = 1
) -> Dictionary:
	if not _valid_empty_cell(port, caster, cell):
		return {}
	var x := int(cell.get("x", -1))
	var y := int(cell.get("y", -1))
	var summon_id := String(port.mechanic_param_string(caster, mechanism, "summon", default_summon_id))
	var hp: int = max(1, int(port.mechanic_param_int(caster, mechanism, "hp", default_hp)))
	var atk: int = max(0, int(port.mechanic_param_int(caster, mechanism, "atk", default_atk)))
	var summon_stats := Dictionary(port.apply_summon_semantics(caster, {"hp": hp, "atk": atk, "shield": 0}))
	hp = max(1, int(summon_stats.get("hp", hp)))
	atk = max(0, int(summon_stats.get("atk", atk)))
	var side := String(caster.get("side", port.player_side()))
	var unit_id := "%s_%s_%d" % [summon_id, String(caster.get("id", "unit")), int(port.unit_count()) + 1]
	var summon := {
		"id": unit_id, "pet_id": unit_id, "summon_id": summon_id, "name": display_name,
		"element": String(caster.get("element", "")), "role": "召唤", "quality": "",
		"max_hp": hp, "hp": hp, "atk": atk, "def": 0, "shield": 0, "ap": 3,
		"skill": "", "shape": "", "range": "", "x": x, "y": y, "side": side,
		"summoned": true, "mechanics": []
	}
	port.append_unit(summon)
	return summon


func summon_wall_on_cell(port: RefCounted, caster: Dictionary, cell: Dictionary, hp: int, duration: int) -> Dictionary:
	if not _valid_empty_cell(port, caster, cell):
		return {}
	var x := int(cell.get("x", -1))
	var y := int(cell.get("y", -1))
	var caster_id := String(caster.get("id", "unit"))
	var wall_id := "wall_%s_%d" % [caster_id, int(port.unit_count()) + 1]
	var wall := {
		"id": wall_id, "pet_id": wall_id, "summon_id": "wall", "name": "障碍",
		"element": String(caster.get("element", "")), "role": "障碍", "quality": "",
		"max_hp": hp, "hp": hp, "atk": 0, "def": 0, "shield": 0, "ap": 0,
		"skill": "", "shape": "", "range": "", "x": x, "y": y,
		"side": String(caster.get("side", port.player_side())), "summoned": true,
		"is_wall": true, "wall_duration": duration, "mechanics": []
	}
	port.append_unit(wall)
	return wall


func copy_weak_self_on_cell(port: RefCounted, source: Dictionary, cell: Dictionary, hp_pct: float, atk_pct: float) -> Dictionary:
	if not _valid_empty_cell(port, source, cell):
		return {}
	var x := int(cell.get("x", -1))
	var y := int(cell.get("y", -1))
	var source_max_hp: int = max(1, int(source.get("max_hp", source.get("maxHp", source.get("hp", 1)))))
	var source_atk: int = max(0, int(source.get("atk", source.get("attack", 0))))
	var copy_hp: int = max(1, int(ceil(float(source_max_hp) * hp_pct)))
	var copy_atk: int = max(0, int(ceil(float(source_atk) * atk_pct)))
	var source_id := String(source.get("id", "unit"))
	var copy_id := "%s_copy_%d" % [source_id, int(port.unit_count()) + 1]
	var copied: Dictionary = source.duplicate(true)
	copied.merge({
		"id": copy_id, "pet_id": copy_id, "copy_source_id": source_id,
		"name": "%s弱化体" % String(source.get("name", "单位")),
		"max_hp": copy_hp, "hp": copy_hp, "atk": copy_atk, "shield": 0, "ap": 3,
		"x": x, "y": y, "side": String(source.get("side", port.player_side())),
		"summoned": true, "mechanics": [], "flags": {}, "action_slots_used": {}, "has_attacked": false
	}, true)
	port.append_unit(copied)
	return copied


func _valid_empty_cell(port: RefCounted, source: Dictionary, cell: Dictionary) -> bool:
	if not _accepts(port) or source.is_empty() or cell.is_empty():
		return false
	var x := int(cell.get("x", -1))
	var y := int(cell.get("y", -1))
	return bool(port.inside(x, y)) and Dictionary(port.unit_at(x, y)).is_empty()


func _accepts(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.call(&"contract_id")) == PORT_CONTRACT_ID
