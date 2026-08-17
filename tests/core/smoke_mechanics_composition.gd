extends SceneTree

const CoreCompositionScript := preload("res://core/composition/core_composition.gd")
const ElementMechanicServiceScript := preload("res://core/battle/mechanics/element_mechanic_service.gd")
const UnitLifecycleMechanicServiceScript := preload("res://core/battle/mechanics/unit_lifecycle_mechanic_service.gd")

var failed := false


class FakeLifecyclePort extends RefCounted:
	var contract := &"ysbzs.unit-lifecycle-mechanic-port.v1"
	var units: Array = []
	var end_units: Array = []
	var discount := 0

	func contract_id() -> StringName: return contract
	func mechanic_ids(unit: Dictionary) -> Array: return Array(unit.get("mechanics", []))
	func mechanism(mechanism_id: String) -> Dictionary: return {"id": mechanism_id, "name": "规则-%s" % mechanism_id}
	func mechanic_param_int(unit: Dictionary, _definition: Dictionary, key: String, fallback: int) -> int: return int(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))
	func mechanic_param_float(unit: Dictionary, _definition: Dictionary, key: String, fallback: float) -> float: return float(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))
	func mechanic_param_string(unit: Dictionary, _definition: Dictionary, key: String, fallback: String) -> String: return String(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))
	func cross_damage(_unit: Dictionary, _source: Dictionary, _damage: int, _element: String, _label: String, _trace: Dictionary) -> Dictionary: return {"hit_count": 1, "logs": ["范围命中"]}
	func first_empty_near(unit: Dictionary, _include_origin: bool) -> Dictionary: return {"x": int(unit.get("x", 0)), "y": int(unit.get("y", 0))}
	func first_adjacent_empty(unit: Dictionary) -> Dictionary: return {"x": int(unit.get("x", 0)) + 1, "y": int(unit.get("y", 0))}
	func summon_unit(_caster: Dictionary, _definition: Dictionary, cell: Dictionary, _summon_id: String, name: String, hp: int, atk: int) -> Dictionary: return {"name": name, "x": int(cell.get("x", 0)), "y": int(cell.get("y", 0)), "hp": hp, "atk": atk}
	func summon_wall(_caster: Dictionary, cell: Dictionary, hp: int, duration: int) -> Dictionary: return {"name": "障碍", "x": int(cell.get("x", 0)), "y": int(cell.get("y", 0)), "hp": hp, "wall_duration": duration}
	func copy_weak_self(source: Dictionary, cell: Dictionary, hp_pct: float, atk_pct: float) -> Dictionary: return {"name": "弱化体", "x": int(cell.get("x", 0)), "y": int(cell.get("y", 0)), "hp": int(float(source.get("max_hp", 1)) * hp_pct), "atk": int(float(source.get("atk", 0)) * atk_pct)}
	func all_units() -> Array: return units
	func battle_end_units() -> Array: return end_units
	func battle_round() -> int: return 3
	func shop_next_discount() -> int: return discount
	func set_shop_next_discount(value: int) -> void: discount = value
	func enemy_side() -> String: return "enemy"


class FakeElementPort extends RefCounted:
	var contract := &"ysbzs.element-mechanic-port.v1"
	var cleared: Array[String] = []

	func contract_id() -> StringName: return contract
	func mechanic_ids(unit: Dictionary) -> Array: return Array(unit.get("mechanics", []))
	func mechanism(mechanism_id: String) -> Dictionary: return {"id": mechanism_id, "name": "规则-%s" % mechanism_id}
	func mechanic_param_int(unit: Dictionary, _definition: Dictionary, key: String, fallback: int) -> int: return int(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))
	func mechanic_param_string(unit: Dictionary, _definition: Dictionary, key: String, fallback: String) -> String: return String(Dictionary(unit.get("mechanic_params", {})).get(key, fallback))
	func mechanic_param_element(unit: Dictionary, definition: Dictionary, key: String, fallback: String) -> String: return mechanic_param_string(unit, definition, key, fallback)
	func heal_unit(unit: Dictionary, amount: int) -> int: unit["hp"] = int(unit.get("hp", 0)) + amount; return amount
	func summon_unit(_caster: Dictionary, _definition: Dictionary, cell: Dictionary) -> Dictionary: return {"x": int(cell.get("x", 0)), "y": int(cell.get("y", 0)), "hp": 6}
	func summon_wall(_caster: Dictionary, cell: Dictionary, hp: int, duration: int) -> Dictionary: return {"x": int(cell.get("x", 0)), "y": int(cell.get("y", 0)), "hp": hp, "wall_duration": duration}
	func inside(x: int, y: int) -> bool: return x >= 0 and y >= 0
	func apply_element_to_cell(_x: int, _y: int, _element: String, _layers: int) -> void: pass
	func set_board_trace(_x: int, _y: int, _trace: Dictionary) -> bool: return true
	func cell_elements_at(_x: int, _y: int) -> Dictionary: return {"火": 2, "水": 1}
	func clear_element_from_cell(_x: int, _y: int, element: String) -> void: cleared.append(element)


class FakeMechanicRegistry extends RefCounted:
	func is_valid() -> bool:
		return true

	func handler_for(_mechanism_id: String, _mechanism: Dictionary) -> RefCounted:
		return null

	func supports(_handler: RefCounted, _hook: StringName) -> bool:
		return false


func _initialize() -> void:
	var composition: RefCounted = CoreCompositionScript.new()
	var composed := Dictionary(composition.call(&"services"))
	for key in [
		"mechanic_handler_registry",
		"mechanic_projection_service",
		"round_lifecycle_service",
		"damage_mechanic_service",
		"damage_death_service",
		"summon_service",
		"unit_lifecycle_mechanic_service",
		"element_mechanic_service",
	]:
		_expect(composed.has(key) and composed.get(key) is RefCounted, "composition exposes %s" % key)
	_expect_shared_mechanic_registry(composition, "first composition")
	var second_composition: RefCounted = CoreCompositionScript.new()
	_expect(
		composition.get("mechanic_handler_registry") != second_composition.get("mechanic_handler_registry")
			and composition.get("mechanic_projection_service") != second_composition.get("mechanic_projection_service"),
		"separate compositions own separate mechanic registry and projection instances"
	)
	_expect_shared_mechanic_registry(second_composition, "second composition")
	var fake_registry := FakeMechanicRegistry.new()
	var overridden_composition: RefCounted = CoreCompositionScript.new({"mechanic_handler_registry": fake_registry})
	_expect(overridden_composition.get("mechanic_handler_registry") == fake_registry, "explicit mechanic registry override is retained")
	_expect_shared_mechanic_registry(overridden_composition, "overridden composition")

	var lifecycle := UnitLifecycleMechanicServiceScript.new()
	var lifecycle_port := FakeLifecyclePort.new()
	var defeated := {"id": "dead", "name": "爆裂兽", "hp": 0, "max_hp": 10, "x": 2, "y": 2, "element": "火", "mechanics": ["mech_death_explosion", "mech_death_summon"], "mechanic_params": {"damage": 7, "count": 1}}
	var death_logs := lifecycle.apply_on_death(lifecycle_port, defeated, {"id": "killer"})
	_expect(bool(Dictionary(defeated.get("flags", {})).get("onDeathMechanicsApplied", false)), "death hook is one-shot")
	_expect(death_logs.has("范围命中") and death_logs.has("爆裂兽 死亡后留下 1 个单位。"), "death explosion and summon preserve declared order")
	_expect(lifecycle.apply_on_death(lifecycle_port, defeated, {}).is_empty(), "second death hook performs no mutation")

	var revenge := {"id": "revenge", "name": "复仇者", "side": "player", "hp": 5, "atk": 2, "shield": 0, "mechanics": ["mech_revenge_buff"]}
	defeated["side"] = "player"
	lifecycle_port.units = [defeated, revenge]
	lifecycle.apply_after_ally_death(lifecycle_port, defeated)
	_expect(int(revenge.get("atk", 0)) == 3 and int(revenge.get("shield", 0)) == 2, "ally-death receiver mutates authority dictionaries")

	var living := {"id": "living", "name": "奖励兽", "hp": 5, "side": "player", "mechanics": ["mech_shop_discount_after_clear", "mech_bonus_reward_under_round5"]}
	var enemy := {"id": "enemy", "name": "守财怪", "hp": 5, "side": "enemy", "mechanics": ["mech_reduce_reward_if_alive"], "mechanic_params": {"reward_pct": -0.2}}
	var elite := {"id": "elite", "hp": 0, "mechanics": ["mech_elite_reward_bonus"], "mechanic_params": {"reward": "elite_chest"}}
	lifecycle_port.end_units = [living, enemy, elite]
	var rewards := lifecycle.apply_battle_end(lifecycle_port, true, 10)
	_expect(int(rewards.get("gold", -1)) == 8, "battle-end mechanics preserve unit order and ceil reward reduction")
	_expect(lifecycle_port.discount == 50 and Array(rewards.get("extra_rewards", [])).size() == 1, "battle-end discount and elite reward use the port")

	var element_service := ElementMechanicServiceScript.new()
	var element_port := FakeElementPort.new()
	var caster := {"name": "元素兽", "hp": 4, "atk": 2, "shield": 0, "x": 1, "y": 1, "mechanics": ["mech_water_heal_on_layer", "mech_earth_shield_on_layer", "mech_consume_layers_grow"], "mechanic_params": {"element": "any", "atk_per_layer": 1}}
	var element_logs := element_service.apply_after_element(element_port, caster, {"id": "target"}, "水", 2, {"x": 3, "y": 3})
	_expect(int(caster.get("hp", 0)) == 6 and int(caster.get("shield", 0)) == 2 and int(caster.get("atk", 0)) == 5, "element hook composes healing, shield and consumed-layer growth")
	_expect(element_port.cleared == ["火", "水"] and element_logs.size() == 3, "element settlement order comes from ElementRules")

	if failed:
		quit(1)
		return
	print("SMOKE_MECHANICS_COMPOSITION_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)


func _expect_shared_mechanic_registry(composition: RefCounted, label: String) -> void:
	var registry: RefCounted = composition.get("mechanic_handler_registry") as RefCounted
	_expect(registry != null, "%s owns a mechanic registry" % label)
	for service_name in [
		"round_lifecycle_service",
		"damage_mechanic_service",
		"unit_lifecycle_mechanic_service",
		"element_mechanic_service",
		"mechanic_projection_service",
	]:
		var service: RefCounted = composition.get(service_name) as RefCounted
		_expect(
			service != null and service.get("_handler_registry") == registry,
			"%s injects one mechanic registry into %s" % [label, service_name]
		)
