extends RefCounted

const BattleBoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const SeededSelectorScript := preload("res://core/run/seeded_selector.gd")

## Pure policy for the complete pet-reset rule: charges, eligibility, and
## deterministic placement. It owns no units or battle state, so alternate
## battle modes can replace it through CoreComposition.


func initial_state(rules: Dictionary, player_side: String, enemy_side: String, default_interval: int, default_initial: int) -> Dictionary:
	var interval := charge_interval(rules, default_interval)
	var initial := initial_charges(rules, default_initial)
	return {
		"counts": {player_side: 0, enemy_side: 0},
		"charges": {player_side: initial, enemy_side: initial},
		"next_charge_round": {player_side: interval, enemy_side: interval},
		"eligible": {player_side: false, enemy_side: false},
	}


func charge_interval(rules: Dictionary, fallback: int) -> int:
	return maxi(1, int(rules.get("pet_reset_charge_interval", fallback)))


func initial_charges(rules: Dictionary, fallback: int) -> int:
	return maxi(0, int(rules.get("pet_reset_initial_charges", fallback)))


func alive_threshold(base_threshold: int, reset_count: int) -> int:
	return maxi(0, base_threshold - reset_count)


func grant_for_round(
	sides: Array,
	round_number: int,
	interval: int,
	charges: Dictionary,
	next_charge_round: Dictionary
) -> Array:
	var grants: Array = []
	for side_value in sides:
		var side := String(side_value)
		var next_round := int(next_charge_round.get(side, interval))
		while next_round <= round_number:
			charges[side] = int(charges.get(side, 0)) + 1
			grants.append({
				"side": side,
				"round": round_number,
				"charges": int(charges.get(side, 0)),
				"interval": interval,
			})
			next_round += interval
		next_charge_round[side] = next_round
	return grants


func is_eligible(alive_count: int, reset_count: int, charges: int, base_threshold: int) -> bool:
	return charges > 0 and alive_count <= alive_threshold(base_threshold, reset_count)


func select_cells(
	dimensions: Vector2i,
	player_side: bool,
	required_count: int,
	occupied_cells: Dictionary,
	trapped_cells: Dictionary,
	seed: String,
	zone_sizes: Array = [3, 4, 5]
) -> Array:
	var candidates: Array = []
	var leader_cell := BattleBoardDimensionsScript.leader_cell(dimensions, player_side)
	for zone_size_value in zone_sizes:
		var zone_size := int(zone_size_value)
		var zone_has_trap := false
		candidates = []
		for cell in BattleBoardDimensionsScript.side_spawn_region_cells(dimensions, player_side, zone_size):
			var key := _cell_key(cell)
			if bool(trapped_cells.get(key, false)):
				zone_has_trap = true
			if cell == leader_cell or bool(occupied_cells.get(key, false)) or bool(trapped_cells.get(key, false)):
				continue
			candidates.append(cell)
		var safe_zone := zone_size > 3 or not zone_has_trap
		if candidates.size() >= required_count and safe_zone:
			break
	_shuffle(candidates, seed)
	return candidates


func _shuffle(cells: Array, seed: String) -> void:
	var random := SeededSelectorScript.rng(seed)
	for index in range(cells.size() - 1, 0, -1):
		var swap_index := int(floor(SeededSelectorScript.next(random) * float(index + 1))) % (index + 1)
		var swap_value: Variant = cells[index]
		cells[index] = cells[swap_index]
		cells[swap_index] = swap_value


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
