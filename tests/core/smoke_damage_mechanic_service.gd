extends SceneTree

const DamageMechanicServiceScript := preload("res://core/battle/mechanics/damage_mechanic_service.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")

var failed := false


class FakeDamageMechanicPort extends RefCounted:
	var contract: StringName = &"ysbzs.damage-mechanic-port.v2"
	var occupied := {}
	var units: Array = []
	var damage_calls: Array = []
	var death_batches: Array = []

	func contract_id() -> StringName:
		return contract

	func mechanic_ids(unit: Dictionary) -> Array:
		return Array(unit.get("mechanics", []))

	func mechanism(mechanism_id: String) -> Dictionary:
		return {"id": mechanism_id, "name": "规则-%s" % mechanism_id}

	func mechanic_param_int(unit: Dictionary, _definition: Dictionary, key: String, fallback: int) -> int:
		return int(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))

	func mechanic_param_float(unit: Dictionary, _definition: Dictionary, key: String, fallback: float) -> float:
		return float(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))

	func mechanic_param_string(unit: Dictionary, _definition: Dictionary, key: String, fallback: String) -> String:
		return String(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))

	func battle_round() -> int:
		return 2

	func all_units() -> Array:
		return units

	func deal_damage(source: Dictionary, target: Dictionary, amount: int, element: String, trace_context: Dictionary = {}, damage_props: Variant = {}) -> Dictionary:
		var hp_before := int(target.get("hp", 0))
		target["hp"] = max(0, hp_before - amount)
		var result := {"mechanic_logs": [], "final": min(hp_before, amount), "pending_death": hp_before > 0 and int(target.get("hp", 0)) <= 0}
		damage_calls.append({"source": source, "target": target, "amount": amount, "element": element, "trace_context": trace_context.duplicate(true), "damage_props": damage_props, "result": result})
		return result

	func resolve_damage_deaths(candidates: Array) -> Array:
		death_batches.append(candidates.duplicate(true))
		return []

	func resolved_stat_value(unit: Dictionary, stat_id: String, _context: Dictionary) -> int:
		return int(unit.get(stat_id, 0))

	func first_adjacent_empty_cell(unit: Dictionary) -> Dictionary:
		return {"x": int(unit.get("x", 0)) + 1, "y": int(unit.get("y", 0))}

	func summon_unit_on_cell(_caster: Dictionary, _definition: Dictionary, cell: Dictionary, _summon_id: String, display_name: String, hp: int, atk: int) -> Dictionary:
		return {"name": display_name, "x": int(cell.get("x", 0)), "y": int(cell.get("y", 0)), "hp": hp, "atk": atk}

	func direction_delta(direction: String) -> Vector2i:
		return {"right": Vector2i.RIGHT, "left": Vector2i.LEFT, "up": Vector2i.UP, "down": Vector2i.DOWN}.get(direction, Vector2i.ZERO)

	func inside(x: int, y: int) -> bool:
		return x >= 0 and x < 8 and y >= 0 and y < 8

	func unit_at(x: int, y: int) -> Dictionary:
		return Dictionary(occupied.get("%d,%d" % [x, y], {}))


class IncompleteDamageMechanicPort extends RefCounted:
	func contract_id() -> StringName:
		return &"ysbzs.damage-mechanic-port.v2"


func _initialize() -> void:
	var service := DamageMechanicServiceScript.new()
	var port := FakeDamageMechanicPort.new()
	var opener := {"name": "守卫", "shield": 1, "mechanics": ["mech_shield_flat"], "mechanic_params": {"shield": 6}}
	var opening_logs := service.apply_battle_start(port, opener)
	_expect(int(opener.get("shield", 0)) == 7, "battle-start shield mutation is owned by service")
	_expect(opening_logs == ["守卫 触发开场护盾：护盾 1→7。"], "battle-start log contract is preserved")

	var armored := {"name": "甲兽", "element": "火", "mechanics": ["mech_armor_flat", "mech_damage_reduce_pct"], "mechanic_params": {"armor": 2, "rate": 0.25, "min_damage": 1}}
	var guarded := Dictionary(service.apply_before_damage(port, armored, {}, 10, "水"))
	_expect(int(guarded.get("damage", -1)) == 6, "before-damage mechanics preserve declaration order")
	_expect(Array(guarded.get("logs", [])).size() == 2, "before-damage returns both mechanic logs")

	var immune := {"name": "灵体", "mechanics": ["mech_first_hit_immunity"]}
	_expect(int(service.apply_before_damage(port, immune, {}, 9).get("damage", -1)) == 0, "first hit immunity consumes the first packet")
	_expect(int(service.apply_before_damage(port, immune, {}, 9).get("damage", -1)) == 9, "first hit immunity is one-shot")

	var enraged := {"name": "首领", "hp": 4, "max_hp": 10, "atk": 3, "shield": 0, "mechanics": ["mech_last_stand_shield", "mech_rage_low_hp", "mech_second_phase"]}
	var after_logs := service.apply_after_damage(port, enraged, {}, 2)
	_expect(int(enraged.get("atk", 0)) == 6 and int(enraged.get("shield", 0)) == 3, "after-damage threshold mechanics mutate the supplied authority dictionaries")
	_expect(after_logs.size() == 2, "only thresholds satisfied at 40 percent hp fire")

	var attacker := {"name": "风兽", "hp": 5, "mechanics": ["mech_wind_push_on_hit", "mech_wind_slow_ap"], "mechanic_params": {"distance": 1, "ap_delta": -1}}
	var target := {"name": "目标", "x": 2, "y": 2, "ap": 3}
	var attacker_logs := service.apply_attacker_after_hit(port, attacker, target, 4, "雷", "right")
	_expect(Vector2i(int(target.get("x", -1)), int(target.get("y", -1))) == Vector2i(3, 2), "attacker push uses only board capabilities exposed by the port")
	_expect(int(target.get("ap", -1)) == 2 and attacker_logs.size() == 2, "attacker post-hit mechanics keep deterministic declaration order")

	var source := {"name": "攻击者", "hp": 10}
	var defender := {"name": "荆棘兽", "hp": 8, "def": 1, "mechanics": ["mech_harden_when_hit", "mech_reflect_first_hit"], "mechanic_params": {"reflect": 3}}
	var defender_logs := service.apply_after_hit(port, defender, source, 4, DamagePropsScript.move_damage())
	_expect(int(defender.get("def", 0)) == 2 and int(source.get("hp", 0)) == 7, "defender after-hit harden and reflection run in declaration order")
	_expect(defender_logs.size() == 2, "defender after-hit returns both logs")
	_expect(port.damage_calls.size() == 1 and bool(Dictionary(Dictionary(port.damage_calls[0]).get("damage_props", {})).get("unpowered", false)) and not bool(Dictionary(Dictionary(port.damage_calls[0]).get("damage_props", {})).get("move", true)), "reflection routes through the port as non-move unpowered damage")
	service.apply_after_hit(port, defender, source, 4, DamagePropsScript.move_damage())
	_expect(int(source.get("hp", 0)) == 7, "first-hit reflection remains one-shot")
	var non_move_defender := {"name": "非攻击目标", "hp": 8, "def": 1, "mechanics": ["mech_harden_when_hit"]}
	_expect(service.apply_after_hit(port, non_move_defender, source, 4, DamagePropsScript.non_move_unpowered()).is_empty() and int(non_move_defender.get("def", 0)) == 1, "non-move damage does not trigger attack-only after-hit mechanics")
	var explosion_source := {"id": "explosion", "name": "爆裂兽", "side": "enemy", "x": 2, "y": 2, "hp": 0}
	var adjacent := {"id": "adjacent", "name": "相邻目标", "side": "player", "x": 3, "y": 2, "hp": 9}
	var distant := {"id": "distant", "side": "player", "x": 5, "y": 2, "hp": 9}
	port.units = [explosion_source, adjacent, distant]
	var cross_result := service.apply_cross_damage(port, explosion_source, {"id": "killer", "name": "击杀者"}, 4, "火", "爆炸", {"sourceType": "test"})
	_expect(int(cross_result.get("hit_count", 0)) == 1 and int(adjacent.get("hp", 0)) == 5 and int(distant.get("hp", 0)) == 9, "cross damage owns adjacency and authority damage routing")

	port.contract = &"ysbzs.damage-mechanic-port.v3"
	var rejected := {"shield": 1, "mechanics": ["mech_shield_flat"]}
	_expect(service.apply_battle_start(port, rejected).is_empty(), "unknown port versions fail closed")
	_expect(int(rejected.get("shield", 0)) == 1, "rejected ports perform no partial mutation")
	_expect(service.apply_battle_start(IncompleteDamageMechanicPort.new(), rejected).is_empty(), "matching version without required capabilities fails closed")

	if failed:
		quit(1)
		return
	print("SMOKE_DAMAGE_MECHANIC_SERVICE_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
