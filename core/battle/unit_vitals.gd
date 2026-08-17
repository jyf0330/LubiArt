extends RefCounted

## Pure mutations for isolated unit vitality fields.


static func add_incoming_damage_bonus(unit: Dictionary, amount: int) -> int:
	if unit.is_empty() or amount <= 0 or int(unit.get("hp", 0)) <= 0:
		return max(0, int(unit.get("incoming_damage_bonus", 0)))
	var next_bonus: int = max(0, int(unit.get("incoming_damage_bonus", 0))) + amount
	unit["incoming_damage_bonus"] = next_bonus
	return next_bonus


static func heal(unit: Dictionary, amount: int) -> int:
	if unit.is_empty() or amount <= 0:
		return 0
	var before := int(unit.get("hp", 0))
	var after: int = min(int(unit.get("max_hp", before)), before + amount)
	unit["hp"] = after
	return after - before
