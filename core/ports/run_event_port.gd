extends RefCounted

## Narrow transactional adapter used by structured run-event operations.
## The authority reference never leaves this Port, and every mutation is
## rejected unless a non-nested transaction is active.

const CONTRACT_ID := &"ysbzs.run-event-port.v1"
const TRANSACTION_FIELDS: Array[StringName] = [
	&"coins",
	&"hero_hp",
	&"roster",
	&"shop_free_rolls",
	&"shop_next_discount",
	&"shop_offers",
	&"active_shop_pool",
	&"active_stall",
	&"shop_event_effects",
	&"battle_prep_effects",
	&"outer_run_effects",
	&"shop_roll_count",
	&"shop_context_roll_count",
	&"shop_seen_pet_ids_by_day",
	&"shop_seed_audit",
]

const _SUMMARY_LIMIT := 20
const _BATTLE_PREP_TYPES := [&"shield", &"trap_damage_bonus"]
const _OUTER_RUN_TYPE := &"reward_gold_multiplier"

var _authority: Object
var _transaction_active := false
var _transaction_backup: Dictionary = {}


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func begin_transaction() -> bool:
	if _transaction_active or not is_instance_valid(_authority):
		return false
	for field in TRANSACTION_FIELDS:
		if not _has_authority_property(field):
			return false
	var backup: Dictionary = {}
	for field in TRANSACTION_FIELDS:
		backup[field] = _deep_copy(_authority.get(field))
	_transaction_backup = backup
	_transaction_active = true
	return true


func commit_transaction() -> bool:
	if not _transaction_active:
		return false
	_transaction_backup.clear()
	_transaction_active = false
	return true


func rollback_transaction() -> bool:
	if not _transaction_active:
		return false
	for field in TRANSACTION_FIELDS:
		_authority.set(field, _deep_copy(_transaction_backup[field]))
	_transaction_backup.clear()
	_transaction_active = false
	return true


func current_coins() -> int:
	if not is_instance_valid(_authority) or not _has_authority_property(&"coins"):
		return 0
	return int(_authority.get(&"coins"))


func spend_coins(amount: int) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if amount < 0:
		return _failure("invalid_amount")
	var before := current_coins()
	if before < amount:
		return _failure("insufficient_coins")
	var after := before - amount
	_authority.set(&"coins", after)
	return {
		"ok": true,
		"code": "ok",
		"coins_from": before,
		"coins_to": after,
	}


func add_coins(amount: int) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if amount < 0:
		return _failure("invalid_amount")
	var before := current_coins()
	var after := before + amount
	_authority.set(&"coins", after)
	return {
		"ok": true,
		"code": "ok",
		"coins_from": before,
		"coins_to": after,
	}


func heal_hero(amount: int) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if amount < 0:
		return _failure("invalid_amount")
	if not _has_authority_property(&"hero_max_hp"):
		return _failure("missing_authority_capability")
	var before := int(_authority.get(&"hero_hp"))
	var maximum := int(_authority.get(&"hero_max_hp"))
	var after := mini(maximum, before + amount)
	_authority.set(&"hero_hp", after)
	return {
		"ok": true,
		"code": "ok",
		"hero_hp_from": before,
		"hero_hp_to": after,
	}


func queue_battle_prep(event: Dictionary, context: Dictionary, effect_type: String, value: int) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if value < 0:
		return _failure("invalid_amount")
	if not _BATTLE_PREP_TYPES.has(StringName(effect_type)):
		return _failure("invalid_effect_type")
	var event_id := String(event.get("id", ""))
	if event_id == "":
		return _failure("invalid_event")
	if not _has_authority_properties([&"day", &"node_index"]):
		return _failure("missing_authority_capability")
	var current_day := int(_authority.get(&"day"))
	var current_step := int(_authority.get(&"node_index"))
	var effect := {
		"effect_id": "prep_%d_%d_%s" % [current_day, current_step, event_id],
		"event_id": event_id,
		"name": String(event.get("name", "")),
		"source": _context_source(context),
		"node_id": _context_node_id(context),
		"type": effect_type,
		"shield": value if effect_type == "shield" else 0,
		"bonus_damage": value if effect_type == "trap_damage_bonus" else 0,
		"status": "pending",
		"day_queued": current_day,
		"step_queued": current_step,
		"uses_remaining": 1,
	}
	var effects := Array(_authority.get(&"battle_prep_effects")).duplicate(true)
	effects.append(effect.duplicate(true))
	_authority.set(&"battle_prep_effects", effects)
	return {
		"ok": true,
		"code": "ok",
		"battle_prep_effect": effect.duplicate(true),
	}


func queue_outer_run(event: Dictionary, context: Dictionary, effect_type: String, value: int) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if value < 0 or value > 99:
		return _failure("invalid_amount")
	if StringName(effect_type) != _OUTER_RUN_TYPE:
		return _failure("invalid_effect_type")
	if typeof(context.get("immediate_gold", null)) != TYPE_INT \
		or int(context.get("immediate_gold", 0)) < 0:
		return _failure("invalid_context")
	var event_id := String(event.get("id", ""))
	if event_id == "":
		return _failure("invalid_event")
	if not _has_authority_properties([&"day", &"node_index"]):
		return _failure("missing_authority_capability")
	var current_day := int(_authority.get(&"day"))
	var current_step := int(_authority.get(&"node_index"))
	var effect := {
		"effect_id": "run_%d_%d_%s" % [current_day, current_step, event_id],
		"event_id": event_id,
		"name": String(event.get("name", "")),
		"source": _context_source(context),
		"node_id": _context_node_id(context),
		"type": effect_type,
		"multiplier": value,
		"immediate_gold": int(context.get("immediate_gold", 0)),
		"status": "pending",
		"day_queued": current_day,
		"step_queued": current_step,
		"uses_remaining": 1,
	}
	var effects := Array(_authority.get(&"outer_run_effects")).duplicate(true)
	effects.append(effect.duplicate(true))
	_authority.set(&"outer_run_effects", effects)
	return {
		"ok": true,
		"code": "ok",
		"outer_run_effect": effect.duplicate(true),
	}


func add_free_refreshes(amount: int) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if amount <= 0:
		return _failure("invalid_amount")
	var before := int(_authority.get(&"shop_free_rolls"))
	var after := before + amount
	_authority.set(&"shop_free_rolls", after)
	return {
		"ok": true,
		"code": "ok",
		"free_rolls_from": before,
		"free_rolls_to": after,
	}


func set_next_discount(percent: int) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if percent < 1 or percent > 100:
		return _failure("invalid_amount")
	var before := int(_authority.get(&"shop_next_discount"))
	var after := maxi(before, percent)
	_authority.set(&"shop_next_discount", after)
	return {
		"ok": true,
		"code": "ok",
		"next_discount_from": before,
		"next_discount_to": after,
	}


func upgrade_first_eligible_pet(event: Dictionary) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if String(event.get("id", "")) == "":
		return _failure("invalid_event")
	if not _authority.has_method(&"_upgrade_roster_pet_for_event"):
		return _failure("missing_authority_capability")
	var value: Variant = _authority.call(&"_upgrade_roster_pet_for_event", event.duplicate(true))
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("invalid_authority_result")
	return {
		"ok": true,
		"code": "ok",
		"construction": Dictionary(value).duplicate(true),
	}


func duplicate_first_pet(event: Dictionary) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if String(event.get("id", "")) == "":
		return _failure("invalid_event")
	if not _authority.has_method(&"_duplicate_roster_pet_for_event"):
		return _failure("missing_authority_capability")
	var value: Variant = _authority.call(&"_duplicate_roster_pet_for_event", event.duplicate(true))
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("invalid_authority_result")
	return {
		"ok": true,
		"code": "ok",
		"construction": Dictionary(value).duplicate(true),
	}


func refill_shop_pool(pool_id: String, minimum_slots: int, context: Dictionary) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	if pool_id.strip_edges() == "":
		return _failure("invalid_pool_id")
	if minimum_slots < 3 or minimum_slots > 10:
		return _failure("invalid_amount")
	var required_methods := [
		&"_shop_slot_count",
		&"_frozen_shop_offers",
		&"_shop_offers_for_pool",
	]
	for method_name in required_methods:
		if not _authority.has_method(method_name):
			return _failure("missing_authority_capability")
	var active_pool_before := String(_authority.get(&"active_shop_pool"))
	var offers_before := Array(_authority.get(&"shop_offers")).duplicate(true)
	var stall_before := Dictionary(_authority.get(&"active_stall")).duplicate(true)
	var slots := int(_authority.call(&"_shop_slot_count", minimum_slots))
	var kept_value: Variant = _authority.call(&"_frozen_shop_offers")
	if typeof(kept_value) != TYPE_ARRAY:
		return _failure("invalid_authority_result")
	var offers_value: Variant = _authority.call(
		&"_shop_offers_for_pool",
		pool_id,
		slots,
		Array(kept_value).duplicate(true)
	)
	if typeof(offers_value) != TYPE_ARRAY:
		return _failure("invalid_authority_result")
	var offers_after := Array(offers_value).duplicate(true)
	var stall_after := {
		"id": pool_id,
		"pool_id": pool_id,
		"name": _context_event_name(context, pool_id),
		"slots": slots,
	}
	_authority.set(&"shop_offers", offers_after.duplicate(true))
	_authority.set(&"active_shop_pool", pool_id)
	_authority.set(&"active_stall", stall_after.duplicate(true))
	return {
		"ok": true,
		"code": "ok",
		"active_shop_pool_from": active_pool_before,
		"active_shop_pool_to": pool_id,
		"shop_offers_from": offers_before,
		"shop_offers_to": offers_after.duplicate(true),
		"shop_offer_count_from": offers_before.size(),
		"shop_offer_count_to": offers_after.size(),
		"active_stall_from": stall_before,
		"active_stall_to": stall_after.duplicate(true),
	}


func select_reward_pool(pool_id: String) -> Dictionary:
	if pool_id.strip_edges() == "":
		return _failure("invalid_pool_id")
	return {
		"ok": true,
		"code": "ok",
		"reward_pool_id": pool_id,
	}


func append_shop_event_summary(summary: Dictionary) -> Dictionary:
	if not _transaction_active:
		return _failure("transaction_required")
	var construction_value: Variant = summary.get("construction", {})
	if typeof(construction_value) != TYPE_DICTIONARY:
		return _failure("invalid_summary")
	var shop_effect := {
		"event_id": String(summary.get("event_id", "")),
		"name": String(summary.get("name", "")),
		"source": String(summary.get("source", "")),
		"node_id": String(summary.get("node_id", "")),
		"free_rolls": int(summary.get("free_rolls", 0)),
		"next_discount": int(summary.get("next_discount", 0)),
		"targeted_pool_id": String(summary.get("targeted_pool_id", "")),
		"construction": Dictionary(construction_value).duplicate(true),
	}
	var effects := Array(_authority.get(&"shop_event_effects")).duplicate(true)
	var count_before := effects.size()
	effects.append(shop_effect.duplicate(true))
	while effects.size() > _SUMMARY_LIMIT:
		effects.pop_front()
	_authority.set(&"shop_event_effects", effects)
	return {
		"ok": true,
		"code": "ok",
		"shop_effect": shop_effect.duplicate(true),
		"summary_count_from": count_before,
		"summary_count_to": effects.size(),
	}


func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}


func _deep_copy(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		return Array(value).duplicate(true)
	if typeof(value) == TYPE_DICTIONARY:
		return Dictionary(value).duplicate(true)
	return value


func _has_authority_properties(properties: Array) -> bool:
	for property_name_value in properties:
		if not _has_authority_property(StringName(property_name_value)):
			return false
	return true


func _has_authority_property(property_name: StringName) -> bool:
	if not is_instance_valid(_authority):
		return false
	for property_info_value in _authority.get_property_list():
		if typeof(property_info_value) != TYPE_DICTIONARY:
			continue
		if StringName(Dictionary(property_info_value).get("name", "")) == property_name:
			return true
	return false


func _context_source(context: Dictionary) -> String:
	return String(context.get("context_kind", ""))


func _context_node_id(context: Dictionary) -> String:
	return String(context.get("node_id", ""))


func _context_event_name(context: Dictionary, fallback: String) -> String:
	var value := String(context.get("event_name", ""))
	return value if value != "" else fallback
