extends RefCounted

## Canonical authoritative-state capture/restore registry.
##
## Save, load, history checkpoints, and state hashes must use this one registry
## so a field cannot silently participate in continuation without persistence.

const FIELD_SPECS := [
	{"property": "phase", "key": "phase", "default": "route", "hash": true},
	{"property": "state_version", "key": "stateVersion", "aliases": ["state_version"], "default": 0, "hash": true},
	{"property": "day", "key": "day", "default": 1, "hash": true},
	{"property": "node_index", "key": "node_index", "default": 1, "hash": true},
	{"property": "coins", "key": "coins", "aliases": ["gold"], "default": 0, "hash": true},
	{"property": "hero_hp", "key": "hero_hp", "default": 0, "hash": true},
	{"property": "hero_max_hp", "key": "hero_max_hp", "aliases": ["heroMaxHp"], "default": 1, "hash": true},
	{"property": "enemy_hero_hp", "key": "enemy_hero_hp", "aliases": ["enemyHeroHp"], "default": 0, "hash": true},
	{"property": "enemy_hero_max_hp", "key": "enemy_hero_max_hp", "aliases": ["enemyHeroMaxHp"], "default": 1, "hash": true},
	{"property": "castle_line", "key": "castle_line", "aliases": ["castleLine"], "default": 10, "hash": true},
	{"property": "economy_multiplier", "key": "economy_multiplier", "aliases": ["economyMultiplier"], "default": 1.0, "hash": true},
	{"property": "ap", "key": "ap", "default": 3, "hash": true},
	{"property": "battle_round", "key": "battle_round", "aliases": ["round"], "default": 1, "hash": true},
	{"property": "battle_round_start_checkpoints", "key": "battle_round_start_checkpoints", "aliases": ["battleRoundStartCheckpoints"], "default": [], "hash": true},
	{"property": "battle_period", "key": "battle_period", "aliases": ["period"], "default": "上午", "hash": true},
	{"property": "difficulty", "key": "difficulty", "default": "normal", "hash": true},
	{"property": "board_width", "key": "board_width", "aliases": ["boardWidth"], "default": 8, "hash": true},
	{"property": "board_height", "key": "board_height", "aliases": ["boardHeight"], "default": 7, "hash": true},
	{"property": "selected_unit_id", "key": "selected_unit_id", "default": "", "hash": true},
	{"property": "selected_action_slot_index", "key": "selected_action_slot_index", "default": 0, "hash": true},
	{"property": "active_wave", "key": "active_wave", "default": {}, "hash": true},
	{"property": "active_schedule", "key": "active_schedule", "default": {}, "hash": true},
	{"property": "active_encounter", "key": "active_encounter", "default": {}, "hash": true},
	{"property": "scenario_provenance", "key": "scenario_provenance", "aliases": ["scenarioProvenance"], "default": {}, "hash": true},
	{"property": "active_stall", "key": "active_stall", "default": {}, "hash": true},
	{"property": "active_shop_pool", "key": "active_shop_pool", "default": "night_base", "hash": true},
	{"property": "active_shop_seed_context", "key": "active_shop_seed_context", "default": "", "hash": true},
	{"property": "run_seed", "key": "run_seed", "default": "ysbzs-local", "hash": true},
	{"property": "run_plan", "key": "run_plan", "default": {}, "hash": true},
	{"property": "action_ap_choices", "key": "action_ap_choices", "default": {}, "hash": true},
	{"property": "shop_roll_count", "key": "shop_roll_count", "default": 0, "hash": true},
	{"property": "shop_context_roll_count", "key": "shop_context_roll_count", "default": 0, "hash": true},
	{"property": "shop_free_rolls", "key": "shop_free_rolls", "default": 0, "hash": true},
	{"property": "shop_paid_refreshes", "key": "shop_paid_refreshes", "default": 0, "hash": true},
	{"property": "shop_next_discount", "key": "shop_next_discount", "default": 0, "hash": true},
	{"property": "shop_event_effects", "key": "shop_event_effects", "default": [], "hash": true},
	{"property": "shop_seen_pet_ids_by_day", "key": "shop_seen_pet_ids_by_day", "default": {}, "hash": true},
	{"property": "shop_seed_audit", "key": "shop_seed_audit", "default": [], "hash": false},
	{"property": "reward_fallback_audit", "key": "reward_fallback_audit", "default": [], "hash": false},
	{"property": "battle_prep_effects", "key": "battle_prep_effects", "default": [], "hash": true},
	{"property": "outer_run_effects", "key": "outer_run_effects", "default": [], "hash": true},
	{"property": "team_placement_preview", "key": "team_placement_preview", "aliases": ["teamPlacementPreview"], "default": {"activeUnitId": null, "movedUnitIds": []}, "hash": true},
	{"property": "placement_damage_by_unit", "key": "placement_damage_by_unit", "default": {}, "hash": false},
	{"property": "route_options", "key": "route_options", "default": [], "hash": true},
	{"property": "roster", "key": "roster", "default": [], "hash": true},
	{"property": "shop_offers", "key": "shop_offers", "default": [], "hash": true},
	{"property": "reward_options", "key": "reward_options", "default": [], "hash": true},
	{"property": "relic_inventory", "key": "relic_inventory", "default": [], "hash": true},
	{"property": "relic_combat_state", "key": "relic_combat_state", "default": {}, "hash": true},
	{"property": "units", "key": "units", "default": [], "hash": true},
	{"property": "defeated_units", "key": "defeated_units", "default": [], "hash": true},
	{"property": "battle_roster_templates", "key": "battle_roster_templates", "default": {}, "hash": true},
	{"property": "skill_control_orders", "key": "skill_control_orders", "aliases": ["skillControlOrders"], "default": {"player": [], "enemy": []}, "hash": true},
	{"property": "pet_reset_counts", "key": "pet_reset_counts", "default": {}, "hash": true},
	{"property": "pet_reset_charges", "key": "pet_reset_charges", "default": {}, "hash": true},
	{"property": "pet_reset_next_charge_round", "key": "pet_reset_next_charge_round", "default": {}, "hash": true},
	{"property": "pet_reset_eligible", "key": "pet_reset_eligible", "default": {}, "hash": true},
	{"property": "battle_result", "key": "battle_result", "default": {}, "hash": true},
	{"property": "cell_elements", "key": "cell_elements", "default": {}, "hash": true},
	{"property": "board_traces", "key": "board_traces", "default": {}, "hash": true},
	{"property": "action_dirs", "key": "action_dirs", "default": {}, "hash": true},
	{"property": "auto_position_action_plan", "key": "auto_position_action_plan", "default": [], "hash": true},
	{"property": "auto_position_applied_result", "key": "auto_position_applied_result", "default": {}, "hash": true},
	{"property": "player_elements_settled_this_round", "key": "player_elements_settled_this_round", "default": false, "hash": true},
	{"property": "log_lines", "key": "log_lines", "default": [], "hash": false},
	{"property": "battle_trace", "key": "battle_trace", "default": [], "hash": true},
	{"property": "command_log", "key": "command_log", "default": [], "hash": false},
	{"property": "replay_debug_timeline", "key": "replay_debug_timeline", "default": [], "hash": false},
]


static func capture(core: Object, include_aliases: bool = true) -> Dictionary:
	var payload := {}
	for spec_value in FIELD_SPECS:
		var spec := Dictionary(spec_value)
		var value: Variant = _clone(core.get(StringName(spec["property"])))
		payload[String(spec["key"])] = value
		if include_aliases:
			for alias_value in Array(spec.get("aliases", [])):
				payload[String(alias_value)] = _clone(value)
	return payload


static func capture_properties(core: Object, properties: Array) -> Dictionary:
	var requested := {}
	for property_value in properties:
		requested[String(property_value)] = true
	var payload := {}
	for spec_value in FIELD_SPECS:
		var spec := Dictionary(spec_value)
		var property := String(spec["property"])
		if not requested.has(property):
			continue
		payload[String(spec["key"])] = _clone(core.get(StringName(property)))
	return payload


static func capture_hash(core: Object) -> Dictionary:
	var payload := {}
	for spec_value in FIELD_SPECS:
		var spec := Dictionary(spec_value)
		if not bool(spec.get("hash", false)):
			continue
		payload[String(spec["key"])] = _clone(core.get(StringName(spec["property"])))
	return payload


static func capture_checkpoint(core: Object) -> Dictionary:
	var payload := capture(core, false)
	# The run plan is a pure function of the pinned content revision, seed, and
	# rules version. Rebuild it on restore instead of repeating it every day.
	payload["run_plan"] = {}
	# These projections and audits are not gameplay inputs and do not belong in
	# every direct-recovery point.
	payload["shop_seed_audit"] = []
	payload["reward_fallback_audit"] = []
	payload["placement_damage_by_unit"] = {}
	return payload


static func capture_round_start_checkpoint(core: Object) -> Dictionary:
	var payload := {}
	for spec_value in FIELD_SPECS:
		var spec := Dictionary(spec_value)
		if not bool(spec.get("hash", false)) or String(spec.get("property", "")) == "battle_round_start_checkpoints":
			continue
		payload[String(spec["key"])] = _clone(core.get(StringName(spec["property"])))
	return payload


static func restore(core: Object, payload: Dictionary) -> void:
	for spec_value in FIELD_SPECS:
		var spec := Dictionary(spec_value)
		var value: Variant = _payload_value(payload, spec, core.get(StringName(spec["property"])))
		core.set(StringName(spec["property"]), _clone(value))


static func restore_changed(core: Object, payload: Dictionary) -> void:
	for spec_value in FIELD_SPECS:
		var spec := Dictionary(spec_value)
		var property := StringName(spec["property"])
		var current_value: Variant = core.get(property)
		var restored_value: Variant = _payload_value(payload, spec, current_value)
		if current_value == restored_value:
			continue
		core.set(property, _clone(restored_value))


static func field_keys() -> Array[String]:
	var keys: Array[String] = []
	for spec_value in FIELD_SPECS:
		keys.append(String(Dictionary(spec_value).get("key", "")))
	return keys


static func _payload_value(payload: Dictionary, spec: Dictionary, current_value: Variant) -> Variant:
	var key := String(spec["key"])
	if payload.has(key):
		return payload[key]
	for alias_value in Array(spec.get("aliases", [])):
		var alias := String(alias_value)
		if payload.has(alias):
			return payload[alias]
	return current_value if current_value != null else spec.get("default")


static func _clone(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return Dictionary(value).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return Array(value).duplicate(true)
	return value
