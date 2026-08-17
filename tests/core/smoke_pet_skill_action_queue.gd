extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const SkillQueueServiceScript := preload("res://core/battle/skills/skill_queue_service.gd")
const SkillComboServiceScript := preload("res://core/battle/skills/skill_combo_service.gd")
const TraitServiceScript := preload("res://core/battle/traits/trait_service.gd")

const TWO_SKILLS := ["skill_vanguard", "skill_flank"]
const SLOT_SEQUENCE := ["a", "b", "a", "b", "a", "b", "a", "b"]

var failed := false


func _initialize() -> void:
	_verify_pure_party_bar_rules()
	_verify_trait_and_combo_rules()
	_verify_authoritative_reorder_command()
	_verify_player_party_execution_in_exact_bar_order()
	_verify_player_party_execution_and_dead_skip()
	_verify_enemy_party_execution_and_dead_skip()
	if failed:
		quit(1)
		return
	print("SMOKE_PET_SKILL_ACTION_QUEUE_OK")
	quit(0)


func _verify_pure_party_bar_rules() -> void:
	var service := SkillQueueServiceScript.new()
	_expect(service.unit_skill_ids({
		"id": "pet_cap",
		"skills": ["skill_01", "skill_02", "skill_03"]
	}) == ["skill_01", "skill_02"], "each pet exposes only its declared A/B skills")
	_expect(service.unit_skill_ids({"id": "pet_legacy", "skill": "guard"}) == ["basic_attack", "guard"], "legacy pets without a catalog retain basic attack plus legacy skill")
	var fallback_catalog := {
		"skill_b": {"order_index": 1},
		"skill_a": {"order_index": 0},
		"skill_c": {"order_index": 2},
	}
	var fallback_ids := service.catalog_skill_ids(fallback_catalog)
	_expect(fallback_ids == ["skill_a", "skill_b"], "catalog fallback deterministically exposes only A/B")
	_expect(service.unit_skill_ids({"id": "saved_pet"}, fallback_ids) == fallback_ids, "historical units without skills receive current A/B fallback")

	var units := _fixture_units()
	var entries := service.control_entries(units, [], Callable(), TWO_SKILLS)
	_expect(entries.size() == 8, "four pets create one eight-entry control bar")
	_expect(_entry_ids(entries).size() == 8, "every shared-bar entry has a distinct stable identity")
	_expect(_unit_ids(entries).size() == 4, "the control bar contains four distinct pets")
	_expect(_skill_slots(entries) == SLOT_SEQUENCE, "each pet contributes A then B")
	_expect(service.skill_ids(entries) == [
		"skill_vanguard", "skill_flank", "skill_vanguard", "skill_flank",
		"skill_vanguard", "skill_flank", "skill_vanguard", "skill_flank"
	], "different pet entries may safely reference the same skill definitions")

	var reordered := _all_b_then_all_a(_entry_ids(entries))
	_expect(service.is_exact_reorder(entries, reordered), "a complete permutation of all eight stable entries is accepted")
	var missing := reordered.duplicate()
	missing.pop_back()
	_expect(not service.is_exact_reorder(entries, missing), "an incomplete shared-bar order is rejected")
	var duplicate := reordered.duplicate()
	duplicate[7] = duplicate[0]
	_expect(not service.is_exact_reorder(entries, duplicate), "a duplicate shared-bar entry is rejected")


func _verify_trait_and_combo_rules() -> void:
	var state := StateScript.new()
	var data := Dictionary(state.game_data)
	var skill_catalog := Dictionary(data.get("skill_catalog", {}))
	var combo_catalog := Dictionary(data.get("skill_combo_catalog", {}))
	var trait_catalog := Dictionary(data.get("trait_catalog", {}))
	var combo_service := SkillComboServiceScript.new()
	var party_skill_ids := [
		"skill_vanguard", "skill_flank", "skill_vanguard", "skill_flank",
		"skill_vanguard", "skill_flank", "skill_vanguard", "skill_flank"
	]
	var default_matches := combo_service.planned_matches(party_skill_ids, skill_catalog, combo_catalog)
	_expect(default_matches.is_empty(), "implicit ordered skill combos stay disabled")
	var reordered_ids := [
		"skill_flank", "skill_flank", "skill_flank", "skill_flank",
		"skill_vanguard", "skill_vanguard", "skill_vanguard", "skill_vanguard"
	]
	_expect(combo_service.planned_matches(reordered_ids, skill_catalog, combo_catalog).is_empty(), "party-wide reorder can break the A/B adjacent combo")
	var trait_service := TraitServiceScript.new()
	var skill_modifiers := trait_service.modifiers({"traits": ["trait_relentless"]}, trait_catalog, "skill")
	_expect(int(skill_modifiers.get("physical_power_bonus_permille", 0)) == 100, "skill-hook traits still aggregate per executing pet")


func _verify_authoritative_reorder_command() -> void:
	var state := StateScript.new()
	_prepare_four_player_roster(state)
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture can start battle")
	var before_snapshot := state.snapshot()
	var before_bar := Array(before_snapshot.get("skillControlBar", []))
	_expect(before_bar.size() == 8, "snapshot exposes the shared 4xA/B control bar")
	_expect(_unit_ids(before_bar).size() == 4, "snapshot control bar keeps four pet identities")
	_expect(_skill_slots(before_bar) == SLOT_SEQUENCE, "snapshot publishes stable A/B slots")
	for template_value in Array(state.battle_roster_templates.get(StateScript.PLAYER, [])):
		_expect(Array(Dictionary(template_value).get("skills", [])).size() == 2, "current player battle templates contain exactly two skills")

	var before_version := int(before_snapshot.get("stateVersion", -1))
	var before_hash := String(before_snapshot.get("stateHash", ""))
	var reordered := _all_b_then_all_a(_entry_ids(before_bar))
	var response: Dictionary = state.run_command({
		"type": "setSkillControlOrder",
		"orderedEntryIds": reordered,
		"baseStateVersion": before_version,
		"commandId": "smoke_party_skill_control_order"
	})
	_expect(bool(response.get("ok", false)), "setSkillControlOrder alias is accepted")
	_expect(int(response.get("stateVersion", -1)) == before_version + 1, "accepted shared-bar reorder increments authoritative version")
	var after_snapshot := state.snapshot()
	_expect(_entry_ids(Array(after_snapshot.get("skillControlBar", []))) == reordered, "snapshot projects the authoritative shared order")
	_expect(Array(state.skill_control_orders.get(StateScript.PLAYER, [])) == reordered, "the shared order is stored once on authoritative state")
	_expect(String(after_snapshot.get("stateHash", "")) != before_hash, "shared-bar order participates in authoritative hash")
	var last_result := Dictionary(after_snapshot.get("lastCommandResult", {}))
	_expect(_entry_ids(Array(last_result.get("skillControlBar", []))) == reordered, "command result returns the canonical shared bar")
	var last_command := Dictionary(Array(state.command_log).back())
	_expect(String(last_command.get("type", "")) == "SET_SKILL_CONTROL_ORDER", "reorder is recorded as the new replayable command")
	_expect(Array(Dictionary(last_command.get("command", {})).get("orderedEntryIds", [])) == reordered, "replay command preserves ordered entry ids")
	var save_state := Dictionary(Dictionary(state.save_document()).get("state", {}))
	_expect(Array(Dictionary(save_state.get("skill_control_orders", {})).get(StateScript.PLAYER, [])) == reordered, "save payload captures shared control order as canonical state")

	var stable_version := int(after_snapshot.get("stateVersion", -1))
	var stable_hash := String(after_snapshot.get("stateHash", ""))
	var missing := reordered.duplicate()
	missing.pop_back()
	var rejected: Dictionary = state.run_command({
		"type": "SET_SKILL_CONTROL_ORDER",
		"orderedEntryIds": missing,
		"baseStateVersion": stable_version
	})
	_expect(not bool(rejected.get("ok", true)), "an incomplete shared order is rejected")
	var rejected_snapshot := state.snapshot()
	_expect(int(rejected_snapshot.get("stateVersion", -1)) == stable_version, "rejected reorder preserves state version")
	_expect(String(rejected_snapshot.get("stateHash", "")) == stable_hash, "rejected reorder preserves authoritative hash")
	_expect(Array(state.skill_control_orders.get(StateScript.PLAYER, [])) == reordered, "rejected reorder preserves the prior shared order")
	var retired: Dictionary = state.run_command({
		"type": "SET_SKILL_ORDER",
		"unitId": String(Dictionary(before_bar[0]).get("unitId", "")),
		"orderedSkillIds": TWO_SKILLS,
	})
	_expect(not bool(retired.get("ok", true)), "the retired per-pet SET_SKILL_ORDER protocol is no longer public")


func _verify_player_party_execution_and_dead_skip() -> void:
	var state := StateScript.new()
	_prepare_four_player_roster(state)
	_expect(state.dispatch({"type": "START_BATTLE"}), "player execution fixture can start battle")
	var control_bar := Array(state.snapshot().get("skillControlBar", []))
	var dead_unit_id := String(Dictionary(control_bar[2]).get("unitId", ""))
	var dead_unit := state.unit_by_id(dead_unit_id)
	dead_unit["hp"] = 0
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			unit["hp"] = 9999
			unit["max_hp"] = 9999
			unit["shield"] = 0
	state.battle_trace = []
	state.ap = 3
	state.run_player_all_out()
	var triggered := _trace_events(state.battle_trace, "SKILL_TRIGGERED")
	var combo_triggered := _trace_events(state.battle_trace, "SKILL_COMBO_TRIGGERED")
	var expected_live_entries := control_bar.filter(func(entry_value: Variant) -> bool:
		return String(Dictionary(entry_value).get("unitId", "")) != dead_unit_id
	)
	_expect(triggered.size() == 6, "one defeated pet skips its two entries while the other three pets execute A/B")
	_expect(not _trace_actor_ids(triggered).has(dead_unit_id), "defeated-pet entries never execute through another pet")
	_expect(_resolved_trace_entry_ids(triggered, control_bar) == _entry_ids(expected_live_entries), "dead-pet skip preserves the exact remaining entry order")
	_expect(_resolved_trace_skill_slots(triggered, control_bar) == _skill_slots(expected_live_entries), "dead-pet skip preserves each remaining A/B identity")
	_expect(_trace_order_indexes(triggered) == _entry_order_indexes(expected_live_entries), "dead-pet skip does not renumber later control-bar positions")
	_expect(_trace_skill_ids(triggered) == [
		"skill_vanguard", "skill_flank", "skill_vanguard", "skill_flank", "skill_vanguard", "skill_flank"
	], "actual executed skill sequence excludes only the dead pet entries")
	_expect(combo_triggered.is_empty(), "player execution does not trigger disabled implicit combos")
	_expect(Array(state.snapshot().get("skillControlBar", [])).size() == 8, "dead-pet entries remain stable in the projected control bar")
	_expect(int(state.ap) == 0, "the shared skill phase consumes the round action budget")


func _verify_enemy_party_execution_and_dead_skip() -> void:
	var state := StateScript.new()
	_prepare_four_player_roster(state)
	_expect(state.dispatch({"type": "START_BATTLE"}), "enemy execution fixture can start battle")
	var enemy_bar: Array = state._skill_control_entries(StateScript.ENEMY)
	_expect(enemy_bar.size() == 8, "enemy side also owns one deterministic 4xA/B bar")
	var dead_enemy_id := String(Dictionary(enemy_bar[0]).get("unitId", ""))
	var dead_enemy := state.unit_by_id(dead_enemy_id)
	dead_enemy["hp"] = 0
	var player_index := 0
	var enemy_index := 0
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER:
			unit["hp"] = 9999
			unit["max_hp"] = 9999
			unit["def"] = 0
			unit["x"] = 3
			unit["y"] = player_index
			player_index += 1
		elif String(unit.get("side", "")) == StateScript.ENEMY:
			unit["x"] = 4
			unit["y"] = enemy_index
			enemy_index += 1
	state.hero_hp = 9999
	state.hero_max_hp = 9999
	state.battle_trace = []
	_expect(state.dispatch({"type": "RUN_MONSTER_TURN"}), "enemy phase command is accepted")
	var triggered := _trace_events(state.battle_trace, "SKILL_TRIGGERED")
	var combo_triggered := _trace_events(state.battle_trace, "SKILL_COMBO_TRIGGERED")
	var expected_live_entries := enemy_bar.filter(func(entry_value: Variant) -> bool:
		return String(Dictionary(entry_value).get("unitId", "")) != dead_enemy_id
	)
	_expect(triggered.size() == 6, "one defeated enemy skips two entries while the other three enemies execute A/B (got %d)" % triggered.size())
	_expect(not _trace_actor_ids(triggered).has(dead_enemy_id), "defeated enemy entries never execute through a living enemy")
	_expect(_resolved_trace_entry_ids(triggered, enemy_bar) == _entry_ids(expected_live_entries), "enemy execution preserves the exact remaining entry order")
	_expect(_resolved_trace_skill_slots(triggered, enemy_bar) == _skill_slots(expected_live_entries), "enemy execution preserves each remaining A/B identity")
	_expect(combo_triggered.is_empty(), "enemy execution does not trigger disabled implicit combos")
	for event_value in triggered:
		_expect(String(Dictionary(Dictionary(event_value).get("actor", {})).get("side", "")) == StateScript.ENEMY, "enemy shared-bar traces keep enemy ownership")


func _verify_player_party_execution_in_exact_bar_order() -> void:
	var state := StateScript.new()
	_prepare_four_player_roster(state)
	_expect(state.dispatch({"type": "START_BATTLE"}), "ordered execution fixture can start battle")
	var control_bar := Array(state.snapshot().get("skillControlBar", []))
	_make_enemy_side_durable(state)
	state.battle_trace = []
	state.run_player_all_out()
	var triggered := _trace_events(state.battle_trace, "SKILL_TRIGGERED")
	_expect(triggered.size() == 8, "four living pets execute exactly eight A/B skills")
	_expect(_resolved_trace_entry_ids(triggered, control_bar) == _entry_ids(control_bar), "default execution follows all eight authoritative entry ids exactly")
	_expect(_resolved_trace_skill_slots(triggered, control_bar) == SLOT_SEQUENCE, "default execution triggers A/B for every pet in control-bar order")
	_expect(_trace_order_indexes(triggered) == range(8), "default execution publishes stable order indexes 0 through 7")

	var reordered_state := StateScript.new()
	_prepare_four_player_roster(reordered_state)
	_expect(reordered_state.dispatch({"type": "START_BATTLE"}), "reordered execution fixture can start battle")
	var default_bar := Array(reordered_state.snapshot().get("skillControlBar", []))
	var reordered_ids := _all_b_then_all_a(_entry_ids(default_bar))
	_expect(reordered_state.set_skill_control_order(reordered_ids), "fixture accepts an exact eight-entry reorder")
	var reordered_bar := Array(reordered_state.snapshot().get("skillControlBar", []))
	_make_enemy_side_durable(reordered_state)
	reordered_state.battle_trace = []
	reordered_state.run_player_all_out()
	var reordered_triggered := _trace_events(reordered_state.battle_trace, "SKILL_TRIGGERED")
	_expect(reordered_triggered.size() == 8, "reordered four-pet bar still executes exactly eight skills")
	_expect(_resolved_trace_entry_ids(reordered_triggered, reordered_bar) == reordered_ids, "execution follows the reordered stable entry ids without regrouping by pet")
	_expect(_resolved_trace_skill_slots(reordered_triggered, reordered_bar) == _skill_slots(reordered_bar), "reordered execution keeps the declared A/B identity for every entry")
	_expect(_trace_order_indexes(reordered_triggered) == range(8), "reordered execution republishes canonical positions 0 through 7")


func _make_enemy_side_durable(state: RefCounted) -> void:
	state.enemy_hero_hp = 9999
	state.enemy_hero_max_hp = 9999
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != StateScript.ENEMY:
			continue
		unit["hp"] = 9999
		unit["max_hp"] = 9999
		unit["shield"] = 0


func _fixture_units() -> Array:
	return [
		{"id": "pet_1", "name": "一号", "skills": TWO_SKILLS.duplicate()},
		{"id": "pet_2", "name": "二号", "skills": TWO_SKILLS.duplicate()},
		{"id": "pet_3", "name": "三号", "skills": TWO_SKILLS.duplicate()},
		{"id": "pet_4", "name": "四号", "skills": TWO_SKILLS.duplicate()},
	]


func _prepare_four_player_roster(state: RefCounted) -> void:
	var source := Dictionary(Array(state.roster)[0]).duplicate(true)
	var prepared: Array = []
	for index in range(4):
		var unit := source.duplicate(true)
		unit["id"] = "fixture_pet_%d" % (index + 1)
		unit["pet_id"] = "fixture_pet_%d" % (index + 1)
		unit["name"] = "测试宠物%d" % (index + 1)
		unit["active"] = true
		unit["slot"] = index + 1
		unit["skills"] = TWO_SKILLS.duplicate()
		prepared.append(unit)
	state.roster = prepared


func _all_b_then_all_a(default_ids: Array) -> Array:
	var result: Array = []
	for index in range(1, default_ids.size(), 2):
		result.append(default_ids[index])
	for index in range(0, default_ids.size(), 2):
		result.append(default_ids[index])
	return result


func _entry_ids(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		result.append(String(Dictionary(entry_value).get("entryId", "")))
	return result


func _unit_ids(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		var unit_id := String(Dictionary(entry_value).get("unitId", ""))
		if unit_id != "" and not result.has(unit_id):
			result.append(unit_id)
	return result


func _skill_slots(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		result.append(String(Dictionary(entry_value).get("skillSlot", "")))
	return result


func _entry_order_indexes(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		result.append(int(Dictionary(entry_value).get("orderIndex", -1)))
	return result


func _trace_events(events: Array, event_type: String) -> Array:
	var result: Array = []
	for event_value in events:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) == event_type:
			result.append(event)
	return result


func _trace_skill_ids(events: Array) -> Array:
	var result: Array = []
	for event_value in events:
		result.append(String(Dictionary(Dictionary(event_value).get("payload", {})).get("skillId", "")))
	return result


func _resolved_trace_entries(events: Array, control_bar: Array) -> Array:
	var result: Array = []
	for event_value in events:
		var event := Dictionary(event_value)
		var payload := Dictionary(event.get("payload", {}))
		var order_index := int(payload.get("orderIndex", -1))
		if order_index < 0 or order_index >= control_bar.size():
			result.append({})
			continue
		var entry := Dictionary(control_bar[order_index])
		var actor_id := String(Dictionary(event.get("actor", {})).get("id", ""))
		var skill_id := String(payload.get("skillId", ""))
		if actor_id != String(entry.get("unitId", "")) or skill_id != String(entry.get("skillId", "")):
			result.append({})
			continue
		result.append(entry)
	return result


func _resolved_trace_entry_ids(events: Array, control_bar: Array) -> Array:
	return _entry_ids(_resolved_trace_entries(events, control_bar))


func _resolved_trace_skill_slots(events: Array, control_bar: Array) -> Array:
	return _skill_slots(_resolved_trace_entries(events, control_bar))


func _trace_order_indexes(events: Array) -> Array:
	var result: Array = []
	for event_value in events:
		result.append(int(Dictionary(Dictionary(event_value).get("payload", {})).get("orderIndex", -1)))
	return result


func _trace_actor_ids(events: Array) -> Array:
	var result: Array = []
	for event_value in events:
		result.append(String(Dictionary(Dictionary(event_value).get("actor", {})).get("id", "")))
	return result


func _definition_ids(definitions: Array) -> Array:
	var result: Array = []
	for value in definitions:
		result.append(String(Dictionary(value).get("id", "")))
	return result


func _definition_ids_from_trace(events: Array) -> Array:
	var result: Array = []
	for value in events:
		result.append(String(Dictionary(Dictionary(value).get("payload", {})).get("comboId", "")))
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("Smoke failed: %s" % message)
