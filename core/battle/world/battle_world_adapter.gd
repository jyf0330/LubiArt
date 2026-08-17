extends RefCounted

const BattleWorldScript := preload("res://core/battle/world/battle_world.gd")

## Compatibility seam for the current Dictionary-based authoritative state.
## Import and write-back are explicit so BattleWorld cannot silently become a
## parallel source of truth.


static func import_units(units: Array) -> RefCounted:
	var world := BattleWorldScript.new()
	for index in range(units.size()):
		if not units[index] is Dictionary:
			continue
		var unit := Dictionary(units[index])
		var source_id := String(unit.get("id", "entity_%d" % index))
		var entity_id: int = world.spawn(source_id)
		if entity_id == BattleWorldScript.INVALID_ENTITY:
			continue
		world.set_camp(entity_id, StringName(String(unit.get("side", unit.get("camp", "")))))
		if unit.has("x") or unit.has("y"):
			world.set_position(
				entity_id,
				int(unit.get("x", -1)),
				int(unit.get("y", -1))
			)
		var hp: int = max(0, int(unit.get("hp", 0)))
		world.set_vitals(
			entity_id,
			hp,
			int(unit.get("max_hp", unit.get("maxHp", hp))),
			int(unit.get("shield", 0)),
			int(unit.get("def", unit.get("defense", 0))),
			int(unit.get("round_damage_taken", unit.get("roundDamageTaken", 0)))
		)
		world.set_alive(
			entity_id,
			bool(unit.get("alive", hp > 0))
				and bool(unit.get("active", true))
				and hp > 0
		)
	return world


static func write_back_vitals(world: RefCounted, units: Array) -> int:
	var updated := 0
	for index in range(units.size()):
		if not units[index] is Dictionary:
			continue
		var unit := Dictionary(units[index])
		var entity_id: int = world.entity_for_source(String(unit.get("id", "")))
		if entity_id < 0:
			continue
		var vitals := Dictionary(world.vitals(entity_id))
		if vitals.is_empty():
			continue
		unit["hp"] = int(vitals.get("hp", 0))
		unit["shield"] = int(vitals.get("shield", 0))
		unit["roundDamageTaken"] = int(vitals.get("roundDamageTaken", 0))
		unit["round_damage_taken"] = int(vitals.get("roundDamageTaken", 0))
		unit["alive"] = bool(vitals.get("alive", false))
		updated += 1
	return updated
