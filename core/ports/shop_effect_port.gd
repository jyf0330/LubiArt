extends RefCounted

const CONTRACT_ID := &"ysbzs.shop-effect-port.v2"
const PARTY_MODIFIER_DESCRIPTORS := [
	{"stat": "atk", "base_stat": "base_atk", "modifier_stat": "atk"},
	{"stat": "def", "base_stat": "base_def", "modifier_stat": "def"},
	{"stat": "max_hp", "base_stat": "base_max_hp", "modifier_stat": "max_hp"},
	{"stat": "shield", "base_stat": "base_shield", "modifier_stat": "starting_shield"},
]

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func has_roster() -> bool:
	return not Array(_authority.get("roster")).is_empty()


func apply_party_modifier(descriptor: Dictionary, value: int, source_id: String) -> bool:
	if not _is_allowed_party_modifier(descriptor) or source_id == "" or not has_roster():
		return false
	var amount: int = max(1, value)
	var stat_key := String(descriptor.get("stat", ""))
	var base_key := String(descriptor.get("base_stat", ""))
	var modifier_stat := String(descriptor.get("modifier_stat", ""))
	var roster := Array(_authority.get("roster")).duplicate(true)
	for index in range(roster.size()):
		var pet := Dictionary(roster[index]).duplicate(true)
		pet[base_key] = max(0, int(pet.get(base_key, pet.get(stat_key, 0)))) + amount
		var modifiers := Array(pet.get("permanent_modifiers", [])).duplicate(true)
		modifiers.append({
			"stat": modifier_stat,
			"operation": "flat_add",
			"value": amount,
			"phase": "permanent",
			"source_type": "shop",
			"source_id": source_id,
			"instance_id": "%s:%d:%d" % [source_id, index, modifiers.size()],
			"materialized": true,
		})
		pet["permanent_modifiers"] = modifiers
		var progression_result := Dictionary(_authority.call("_progressed_unit", pet, true))
		if not bool(progression_result.get("ok", false)):
			return false
		roster[index] = Dictionary(progression_result.get("unit", {}))
	_authority.set("roster", roster)
	return true


func increase_hero_vitality(value: int) -> void:
	var maximum := int(_authority.get("hero_max_hp")) + value
	_authority.set("hero_max_hp", maximum)
	_authority.set("hero_hp", min(maximum, int(_authority.get("hero_hp")) + value))


func upgrade_pet(offer_id: String) -> Dictionary:
	return Dictionary(_authority.call("_upgrade_roster_pet_for_event", {"id": offer_id}))


func duplicate_pet(offer_id: String) -> Dictionary:
	return Dictionary(_authority.call("_duplicate_roster_pet_for_event", {"id": offer_id}))


func add_free_refreshes(value: int) -> int:
	var updated := int(_authority.get("shop_free_rolls")) + value
	_authority.set("shop_free_rolls", updated)
	return updated


func set_next_discount(value: int) -> int:
	var updated: int = max(int(_authority.get("shop_next_discount")), clampi(value, 1, 100))
	_authority.set("shop_next_discount", updated)
	return updated


func _is_allowed_party_modifier(descriptor: Dictionary) -> bool:
	var candidate := {
		"stat": String(descriptor.get("stat", "")),
		"base_stat": String(descriptor.get("base_stat", "")),
		"modifier_stat": String(descriptor.get("modifier_stat", "")),
	}
	return PARTY_MODIFIER_DESCRIPTORS.has(candidate)
