extends RefCounted

## Pure battle-start preparation. It selects enemy templates and prepares player
## deployment entries through explicit callbacks without owning authoritative state.


func select_enemy_templates(
	battle_data: Dictionary,
	day: int,
	period: String,
	team_size: int
) -> Array:
	var selected: Array = []
	var seen_templates: Dictionary = {}
	var legacy_rows := Array(battle_data.get("waves", []))
	if legacy_rows.is_empty():
		legacy_rows = [Dictionary(battle_data.get("wave", {}))]
	for row_value in legacy_rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(row_value)
		if int(row.get("day", day)) != day or String(row.get("period", period)) != period:
			continue
		for enemy_value in Array(row.get("enemies", [])):
			if typeof(enemy_value) != TYPE_DICTIONARY:
				continue
			var enemy := Dictionary(enemy_value).duplicate(true)
			var template_key := String(enemy.get("source_pet_id", enemy.get("pet_id", enemy.get("id", ""))))
			if template_key == "" or seen_templates.has(template_key):
				continue
			seen_templates[template_key] = true
			selected.append(enemy)
			if selected.size() >= team_size:
				return selected
	if selected.is_empty():
		selected = Array(battle_data.get("enemies", [])).slice(0, team_size).duplicate(true)
	return selected


func prepare_player_deployment(
	active_roster: Array,
	placement: Array,
	team_size: int,
	callbacks: Dictionary
) -> Array:
	var entries: Array = []
	var used_cells := {}
	for index in range(min(active_roster.size(), placement.size(), team_size)):
		var pet: Dictionary = Dictionary(active_roster[index]).duplicate(true)
		var cell := Vector2i(_call(callbacks, &"deploy_cell", [pet, placement[index], used_cells], placement[index]))
		var cell_key := String(_call(callbacks, &"cell_key", [cell.x, cell.y], "%d,%d" % [cell.x, cell.y]))
		used_cells[cell_key] = true
		pet["x"] = cell.x
		pet["y"] = cell.y
		pet["hp"] = max(1, int(pet.get("hp", pet.get("max_hp", 1))))
		pet["side"] = String(callbacks.get("player_side", "player"))
		entries.append({
			"unit": pet,
			"logs": Array(_call(callbacks, &"battle_start_mechanics", [pet], [])),
		})
	return entries


func _call(callbacks: Dictionary, key: StringName, args: Array, fallback: Variant = null) -> Variant:
	var callback: Variant = callbacks.get(key)
	if callback is Callable and (callback as Callable).is_valid():
		return (callback as Callable).callv(args)
	return fallback
