extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "two-player battle starts")
	_expect(int(state.snapshot().get("maxRounds", 0)) == 12, "battle ends on round 12")
	_expect(Dictionary(state.snapshot().get("active_wave", {})).is_empty(), "runtime battle has no active wave")
	_expect(_living_count(state, StateScript.PLAYER) <= 4, "player deploys at most four fixed pets")
	_expect(_living_count(state, StateScript.ENEMY) == 4, "enemy deploys four fixed pets instead of waves")
	var charge_state := StateScript.new()
	charge_state.start_battle()
	_expect(int(charge_state.pet_reset_charges.get(StateScript.PLAYER, -1)) == 0, "battle starts without a reset charge")
	_expect(int(charge_state.pet_reset_charges.get(StateScript.ENEMY, -1)) == 0, "enemy also starts without a reset charge")
	_expect(int(charge_state.pet_reset_next_charge_round.get(StateScript.PLAYER, 0)) == 5, "first reset charge arrives on round 5")
	charge_state.call("_grant_pet_reset_charges_for_round", 4)
	_expect(int(charge_state.pet_reset_charges.get(StateScript.PLAYER, -1)) == 0, "round 4 still has no reset charge")
	charge_state.call("_grant_pet_reset_charges_for_round", 5)
	charge_state.call("_grant_pet_reset_charges_for_round", 10)
	_expect(int(charge_state.pet_reset_charges.get(StateScript.PLAYER, 0)) == 2, "rounds 5 and 10 total two reset charges")
	charge_state.call("_grant_pet_reset_charges_for_round", 10)
	_expect(int(charge_state.pet_reset_charges.get(StateScript.PLAYER, 0)) == 2, "charge grant is idempotent within the same round")

	var enemy_hp_before := int(state.enemy_hero_hp)
	var guard_result: Dictionary = state.call("_deal_damage", _first_side(state, StateScript.PLAYER), state.call("_leader_unit", false), 99, "火", false)
	_expect(int(guard_result.get("final", 0)) == 4, "pet guard caps one hero damage packet at four")
	_expect(int(state.enemy_hero_hp) == enemy_hp_before - 4, "capped damage persists to enemy hero HP")

	_keep_living_count(state, StateScript.PLAYER, 2)
	_silence_side(state, StateScript.ENEMY)
	state.end_player_turn()
	var reset_status := Dictionary(Dictionary(state.snapshot().get("pet_reset", {})).get("player", {}))
	_expect(not bool(reset_status.get("eligible", false)), "player is not reset-eligible before round 5")
	_expect(int(state.pet_reset_counts.get(StateScript.PLAYER, -1)) == 0, "player pets do not auto-reset")

	var trap_y: int = state.board_height - 2
	state.call("_apply_element_to_cell", 1, trap_y, "火", 3)
	var expanded_cells: Array = state.call("_side_reset_cells", StateScript.PLAYER, 1)
	var player_leader := Dictionary(state.call("_leader_unit", true))
	var enemy_leader := Dictionary(state.call("_leader_unit", false))
	_expect(expanded_cells.size() > 7, "a 3x3 trap expands the safe reset zone beyond the seven non-hero cells")
	_expect(not expanded_cells.has(Vector2i(1, trap_y)), "expanded reset candidates exclude element traps")
	_expect(not expanded_cells.has(_unit_cell(player_leader)), "expanded player reset candidates exclude the player hero cell")
	_expect(not expanded_cells.has(_unit_cell(enemy_leader)), "expanded player reset candidates exclude the enemy hero cell")
	var compact_state := StateScript.new()
	_expect(compact_state.set_board_dimensions(4, 4), "compact reset-overlap fixture accepts a 4x4 board")
	compact_state.start_battle()
	var compact_player_leader := Dictionary(compact_state.call("_leader_unit", true))
	var compact_enemy_leader := Dictionary(compact_state.call("_leader_unit", false))
	for side in [StateScript.PLAYER, StateScript.ENEMY]:
		var compact_candidates: Array = compact_state.call("_side_reset_cells", side, 1)
		_expect(not compact_candidates.has(_unit_cell(compact_player_leader)), "%s compact reset candidates exclude the player hero cell" % side)
		_expect(not compact_candidates.has(_unit_cell(compact_enemy_leader)), "%s compact reset candidates exclude the enemy hero cell" % side)
	_expect(not state.dispatch({"type": "RESET_PETS"}), "player reset is rejected before the first round-5 charge")
	state.battle_round = 5
	state.call("_grant_pet_reset_charges_for_round", 5)
	state.call("_reset_eligible_sides_after_round")
	_expect(state.dispatch({"type": "RESET_PETS"}), "player reset is accepted after the round-5 charge")
	_expect(_living_count(state, StateScript.PLAYER) == Array(state.battle_roster_templates.get(StateScript.PLAYER, [])).size(), "player reset restores the original battle roster")
	_expect(int(state.pet_reset_counts.get(StateScript.PLAYER, 0)) == 1, "first reset count is recorded")
	_expect(int(state.pet_reset_charges.get(StateScript.PLAYER, -1)) == 0, "first reset consumes the round-5 charge")
	_expect(int(state.pet_reset_next_charge_round.get(StateScript.PLAYER, 0)) == 10, "next reset charge arrives on round 10")
	_expect(not state.dispatch({"type": "RESET_PETS"}), "player cannot reset again during cooldown")
	_expect(_event_count(state.battle_trace, "PETS_RESET") >= 1, "reset emits PETS_RESET trace")
	_expect(_event_count(state.battle_trace, "WAVE_SUMMONED") == 0, "battle emits no wave trace")

	state.battle_round = 10
	state.call("_grant_pet_reset_charges_for_round", 10)
	_keep_living_count(state, StateScript.PLAYER, 1)
	state.call("_reset_eligible_sides_after_round")
	_expect(state.dispatch({"type": "RESET_PETS"}), "second player reset is accepted when ready")
	_expect(int(state.pet_reset_counts.get(StateScript.PLAYER, 0)) == 2, "second reset count is recorded")
	_expect(int(state.pet_reset_charges.get(StateScript.PLAYER, -1)) == 0, "second reset consumes the round-10 charge")
	_expect(int(state.pet_reset_next_charge_round.get(StateScript.PLAYER, 0)) == 15, "third reset charge arrives on round 15")
	_expect(int(state.call("_pet_reset_alive_threshold", StateScript.PLAYER)) == 0, "third reset requires zero living pets")

	var enemy_reset_state := StateScript.new()
	enemy_reset_state.start_battle()
	_keep_living_count(enemy_reset_state, StateScript.ENEMY, 0)
	enemy_reset_state.end_player_turn()
	_expect(int(enemy_reset_state.pet_reset_counts.get(StateScript.ENEMY, 0)) == 0, "enemy cannot reset before round 5")
	_expect(_living_count(enemy_reset_state, StateScript.ENEMY) == 0, "enemy remains cleared before receiving a reset charge")
	_expect(_event_count(enemy_reset_state.battle_trace, "PETS_RESET") == 0, "no enemy reset trace is emitted before round 5")
	enemy_reset_state.battle_round = 5
	enemy_reset_state.call("_grant_pet_reset_charges_for_round", 5)
	enemy_reset_state.call("_reset_eligible_sides_after_round")
	_expect(int(enemy_reset_state.pet_reset_counts.get(StateScript.ENEMY, 0)) == 1, "enemy round-5 reset triggers automatically after its pets are cleared")
	_expect(int(enemy_reset_state.pet_reset_charges.get(StateScript.ENEMY, -1)) == 0, "enemy round-5 reset consumes its first charge")
	_expect(_living_count(enemy_reset_state, StateScript.ENEMY) == Array(enemy_reset_state.battle_roster_templates.get(StateScript.ENEMY, [])).size(), "enemy round-5 reset restores its fixed roster")
	_expect(_event_count(enemy_reset_state.battle_trace, "PETS_RESET") == 1, "enemy round-5 reset emits one PETS_RESET trace")

	var battle_scene := BattleScene.instantiate()
	root.add_child(battle_scene)
	await process_frame
	var panel := battle_scene.get_node("Hud/BattleActionPanel")
	state.battle_round = 15
	state.call("_grant_pet_reset_charges_for_round", 15)
	state.pet_reset_eligible[StateScript.PLAYER] = true
	panel.call("render_snapshot", state.snapshot())
	var reset_button := panel.get_node("Margin/Content/ResetPetsButton") as Button
	_expect(reset_button != null and not reset_button.disabled, "existing action panel exposes enabled reset button")
	battle_scene.queue_free()
	await process_frame

	var hero_kill_state := StateScript.new()
	hero_kill_state.start_battle()
	_remove_side(hero_kill_state, StateScript.ENEMY)
	var lethal_result: Dictionary = hero_kill_state.call("_deal_damage", _first_side(hero_kill_state, StateScript.PLAYER), hero_kill_state.call("_leader_unit", false), 999, "火", false)
	_expect(int(lethal_result.get("final", 0)) > 4, "hero damage cap is removed when no guarding pets remain")
	hero_kill_state.call("_check_battle_end")
	_expect(String(hero_kill_state.phase) == "battle_end" and bool(hero_kill_state.battle_result.get("win", false)), "enemy hero death ends battle immediately")

	var round_limit_state := StateScript.new()
	round_limit_state.start_battle()
	round_limit_state.battle_round = 12
	round_limit_state.hero_hp = 50
	round_limit_state.enemy_hero_hp = 40
	round_limit_state.call("_check_battle_end", true)
	_expect(bool(round_limit_state.battle_result.get("win", false)) and String(round_limit_state.battle_result.get("reason", "")) == "hero_hp_higher", "round 12 higher hero HP wins")

	var tie_state := StateScript.new()
	tie_state.start_battle()
	tie_state.battle_round = 12
	tie_state.hero_hp = 40
	tie_state.enemy_hero_hp = 40
	tie_state.call("_check_battle_end", true)
	_expect(bool(tie_state.battle_result.get("draw", false)) and String(tie_state.battle_result.get("code", "")) == "DRAW", "round 12 equal hero HP is a draw")

	var saved := state.save_document("pet-reset-smoke")
	var loaded := StateScript.new()
	_expect(loaded.load_document(saved), "pet reset battle save loads")
	_expect(int(loaded.enemy_hero_hp) == int(state.enemy_hero_hp), "enemy hero HP survives save/load")
	_expect(loaded.pet_reset_counts == state.pet_reset_counts, "reset counts survive save/load")
	_expect(loaded.pet_reset_charges == state.pet_reset_charges, "reset charges survive save/load")
	_expect(loaded.pet_reset_next_charge_round == state.pet_reset_next_charge_round, "next charge rounds survive save/load")

	print("SMOKE_TWO_PLAYER_PET_RESET_BATTLE_%s" % ["FAIL" if failed else "OK"])
	quit(1 if failed else 0)


func _first_side(state: RefCounted, side: String) -> Dictionary:
	for value in state.units:
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == side and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _living_count(state: RefCounted, side: String) -> int:
	return int(state.call("_living_unit_count", side))


func _unit_cell(unit: Dictionary) -> Vector2i:
	return Vector2i(int(unit.get("x", -1)), int(unit.get("y", -1)))


func _keep_living_count(state: RefCounted, side: String, count: int) -> void:
	var kept := 0
	for value in state.units:
		var unit := Dictionary(value)
		if String(unit.get("side", "")) != side:
			continue
		if kept < count:
			unit["hp"] = max(1, int(unit.get("hp", 1)))
			kept += 1
		else:
			unit["hp"] = 0


func _remove_side(state: RefCounted, side: String) -> void:
	for value in state.units:
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == side:
			unit["hp"] = 0


func _silence_side(state: RefCounted, side: String) -> void:
	for value in state.units:
		var unit := Dictionary(value)
		if String(unit.get("side", "")) != side:
			continue
		unit["atk"] = 0
		unit["mechanics"] = ["none"]
		unit["mechanism_id"] = "none"
		unit["mechanism_params"] = ""


func _event_count(events: Array, event_type: String) -> int:
	var count := 0
	for value in events:
		if String(Dictionary(value).get("type", "")) == event_type:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_TWO_PLAYER_PET_RESET_BATTLE_FAIL: %s" % message)
