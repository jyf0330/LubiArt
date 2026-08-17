extends SceneTree

const SummonServiceScript := preload("res://core/battle/summons/summon_service.gd")

var failed := false


class FakeSummonPort extends RefCounted:
	var contract := &"ysbzs.summon-port.v1"
	var units: Array = []
	var occupied := {}

	func contract_id() -> StringName:
		return contract

	func inside(x: int, y: int) -> bool:
		return x >= 0 and x < 8 and y >= 0 and y < 8

	func unit_at(x: int, y: int) -> Dictionary:
		return Dictionary(occupied.get("%d,%d" % [x, y], {}))

	func mechanic_param_int(unit: Dictionary, _definition: Dictionary, key: String, fallback: int) -> int:
		return int(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))

	func mechanic_param_string(unit: Dictionary, _definition: Dictionary, key: String, fallback: String) -> String:
		return String(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))

	func apply_summon_semantics(_unit: Dictionary, values: Dictionary) -> Dictionary:
		var result := values.duplicate(true)
		result["hp"] = int(result.get("hp", 0)) + 1
		return result

	func player_side() -> String:
		return "player"

	func unit_count() -> int:
		return units.size()

	func append_unit(unit: Dictionary) -> void:
		units.append(unit)


func _initialize() -> void:
	var service := SummonServiceScript.new()
	var port := FakeSummonPort.new()
	var caster := {"id": "caster", "name": "召唤者", "x": 2, "y": 2, "element": "水", "side": "player", "mechanic_params": {"summon": "sprite", "hp": 5, "atk": 2}}
	_expect(service.first_empty_near(port, caster, true) == {"x": 2, "y": 2}, "near-cell order keeps origin first")
	_expect(service.first_adjacent_empty(port, caster) == {"x": 3, "y": 2}, "adjacent-cell order keeps right first")
	var summon := service.summon_unit_on_cell(port, caster, {}, {"x": 3, "y": 2})
	_expect(String(summon.get("id", "")) == "sprite_caster_1", "summon id is derived from authoritative unit count")
	_expect(int(summon.get("hp", 0)) == 6 and int(summon.get("atk", 0)) == 2, "summon semantics are applied through the port")
	_expect(port.units.size() == 1 and Dictionary(port.units[0]) == summon, "summon is appended to the single authoritative array")
	var wall := service.summon_wall_on_cell(port, caster, {"x": 4, "y": 2}, 9, 3)
	_expect(bool(wall.get("is_wall", false)) and String(wall.get("id", "")) == "wall_caster_2", "wall creation shares deterministic authority ids")
	var copied := service.copy_weak_self_on_cell(port, {"id": "source", "name": "本体", "x": 1, "y": 1, "max_hp": 10, "atk": 5, "side": "enemy", "mechanics": ["ignored"]}, {"x": 1, "y": 2}, 0.5, 0.5)
	_expect(int(copied.get("hp", 0)) == 5 and int(copied.get("atk", 0)) == 3, "weak copy preserves ceil scaling")
	_expect(Array(copied.get("mechanics", ["unexpected"])).is_empty(), "weak copy cannot recursively copy mechanics")
	port.contract = &"ysbzs.summon-port.v2"
	var count_before := port.units.size()
	_expect(service.summon_unit_on_cell(port, caster, {}, {"x": 5, "y": 2}).is_empty(), "unknown port versions fail closed")
	_expect(port.units.size() == count_before, "rejected ports do not append units")
	if failed:
		quit(1)
		return
	print("SMOKE_SUMMON_SERVICE_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
