extends RefCounted

## Deterministic enemy target priority shared by threat previews and execution.
## The policy owns no unit state; target Dictionaries remain authority-owned.


func select(
	enemy: Dictionary,
	living_players: Array,
	player_leader: Dictionary,
	taunt_candidates: Array
) -> Dictionary:
	if enemy.is_empty():
		return {}
	var taunt := _nearest_taunt(enemy, taunt_candidates)
	if not taunt.is_empty():
		return taunt
	var best: Dictionary = {}
	var best_distance := 999
	for target_value in living_players:
		var target := Dictionary(target_value)
		var distance := _distance(enemy, target)
		if distance < best_distance:
			best = target
			best_distance = distance
	if bool(player_leader.get("alive", false)):
		var leader_distance := _distance(enemy, player_leader)
		if leader_distance < best_distance:
			best = player_leader
	return {"target": best, "redirect": {}}


func _nearest_taunt(enemy: Dictionary, candidates: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_redirect: Dictionary = {}
	var best_distance := 999
	for candidate_value in candidates:
		var candidate := Dictionary(candidate_value)
		var target := Dictionary(candidate.get("target", {}))
		if target.is_empty():
			continue
		var distance := _distance(enemy, target)
		if distance > max(1, int(candidate.get("range", 1))) or distance >= best_distance:
			continue
		best = target
		best_distance = distance
		best_redirect = {
			"mechanic_id": String(candidate.get("mechanic_id", "")),
			"mechanic_name": String(candidate.get("mechanic_name", "")),
			"target_id": String(target.get("id", "")),
		}
	return {"target": best, "redirect": best_redirect} if not best.is_empty() else {}


func _distance(left: Dictionary, right: Dictionary) -> int:
	return (
		abs(int(left.get("x", 0)) - int(right.get("x", 0)))
		+ abs(int(left.get("y", 0)) - int(right.get("y", 0)))
	)
