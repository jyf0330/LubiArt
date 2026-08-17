extends SceneTree

const ShopEffectRegistryScript := preload("res://core/shop/shop_effect_registry.gd")
const ShopEffectPortScript := preload("res://core/ports/shop_effect_port.gd")
const StateScript := preload("res://core/state/game_state.gd")

const HANDLER_PATHS: Array[String] = [
	"res://core/shop/handlers/party_stat_effect_handler.gd",
	"res://core/shop/handlers/hero_vitality_effect_handler.gd",
	"res://core/shop/handlers/upgrade_pet_effect_handler.gd",
	"res://core/shop/handlers/duplicate_pet_effect_handler.gd",
	"res://core/shop/handlers/free_refresh_effect_handler.gd",
	"res://core/shop/handlers/next_discount_effect_handler.gd",
]
const LEGACY_PARTY_CASES := {
	"party_attack": {"stat": "atk", "base_stat": "base_atk", "modifier_stat": "atk", "label": "攻击", "value": 2},
	"party_defense": {"stat": "def", "base_stat": "base_def", "modifier_stat": "def", "label": "防御", "value": 2},
	"party_vitality": {"stat": "max_hp", "base_stat": "base_max_hp", "modifier_stat": "max_hp", "label": "生命上限", "value": 2},
	"party_shield": {"stat": "shield", "base_stat": "base_shield", "modifier_stat": "starting_shield", "label": "护盾", "value": 2},
}

var _failed := false


class InvalidPort extends RefCounted:
	func contract_id() -> StringName:
		return &"invalid.shop-effect-port.v2"


class FailingAuthority extends RefCounted:
	var roster: Array = [
		{"id": "first", "base_atk": 1, "atk": 1, "permanent_modifiers": []},
		{"id": "second", "base_atk": 2, "atk": 2, "permanent_modifiers": []},
	]
	var progression_calls := 0

	func _progressed_unit(pet: Dictionary, _materialize: bool) -> Dictionary:
		progression_calls += 1
		return {"ok": progression_calls == 1, "unit": pet.duplicate(true)}


func _initialize() -> void:
	_verify_registry_contract()
	_verify_wrong_port_and_caller_boundary()
	_verify_legacy_and_canonical_party_parity()
	_verify_atomic_rejection()
	_verify_non_party_state_mutations()
	_verify_catalog_schema()
	if _failed:
		quit(1)
		return
	print("SMOKE_SHOP_EFFECT_REGISTRY_OK effects=10 aliases=4 canonical=6")
	quit(0)


func _verify_registry_contract() -> void:
	var registry: RefCounted = ShopEffectRegistryScript.new()
	_expect(registry.is_valid(), "production shop effect registry is valid")
	_expect(registry.validation_errors().is_empty(), "valid registry reports no errors")
	var expected: Array[String] = [
		"duplicate_pet", "free_refresh", "hero_vitality", "next_discount",
		"party_attack", "party_defense", "party_shield", "party_stat",
		"party_vitality", "upgrade_pet",
	]
	_expect(registry.registered_effects() == expected, "registry exposes stable canonical and compatibility IDs")
	for effect_type in ["party_attack", "party_defense", "party_vitality", "party_shield", "hero_vitality", "upgrade_pet", "duplicate_pet", "free_refresh", "next_discount"]:
		_expect(registry.handler_for(effect_type) != null, "registry covers legacy runtime type %s" % effect_type)
	_expect(registry.handler_for("party_stat") != null, "registry covers canonical party_stat")
	_expect(registry.handler_for("unknown") == null, "unknown effect fails closed")
	for handler_path in HANDLER_PATHS:
		var source := FileAccess.get_file_as_string(handler_path)
		_expect(source.contains("func plugin_id() -> String"), "%s declares one canonical plugin ID" % handler_path)
		_expect(not source.contains("func effect_types()"), "%s has no multi-type registration" % handler_path)
		_expect(not source.contains("func execute(core"), "%s never receives the complete core" % handler_path)
		_expect(not source.contains("core."), "%s cannot probe or mutate the complete core" % handler_path)


func _verify_wrong_port_and_caller_boundary() -> void:
	var registry: RefCounted = ShopEffectRegistryScript.new()
	var handler: RefCounted = registry.handler_for("free_refresh")
	_expect(Dictionary(handler.execute(InvalidPort.new(), {}, {"type": "free_refresh", "value": 2})).is_empty(), "shop handler rejects the wrong v2 Port")
	var run_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	_expect(run_source.contains('handler.call("execute", ShopEffectPortScript.new(self), offer, effect)'), "run core keeps the existing two-line shop dispatch")
	_expect(not run_source.contains('handler.call("execute", self, offer, effect)'), "run core never exposes complete authority to shop handlers")


func _verify_legacy_and_canonical_party_parity() -> void:
	for legacy_type_value in LEGACY_PARTY_CASES.keys():
		var legacy_type := String(legacy_type_value)
		var case := Dictionary(LEGACY_PARTY_CASES[legacy_type]).duplicate(true)
		var legacy_effect := {"type": legacy_type, "value": int(case["value"])}
		var canonical_effect := case.duplicate(true)
		canonical_effect["type"] = "party_stat"
		canonical_effect["source_id"] = legacy_type
		var legacy_state: RefCounted = StateScript.new()
		var canonical_state: RefCounted = StateScript.new()
		var legacy_result := Dictionary(legacy_state._apply_non_pet_shop_item({"effect": legacy_effect}))
		var canonical_result := Dictionary(canonical_state._apply_non_pet_shop_item({"effect": canonical_effect}))
		_expect(String(legacy_result.get("type", "")) == legacy_type, "%s preserves its legacy result type" % legacy_type)
		_expect(String(canonical_result.get("type", "")) == "party_stat", "%s canonical result uses party_stat" % legacy_type)
		_expect(String(legacy_result.get("text", "")) == String(canonical_result.get("text", "")), "%s canonical and alias text match" % legacy_type)
		_expect(Array(legacy_state.roster) == Array(canonical_state.roster), "%s canonical and alias roster/modifiers match field-for-field" % legacy_type)

	var canonical_state: RefCounted = StateScript.new()
	var default_source_effect := {
		"type": "party_stat", "stat": "atk", "base_stat": "base_atk",
		"modifier_stat": "atk", "label": "攻击", "value": 1,
	}
	var result := Dictionary(canonical_state._apply_non_pet_shop_item({"effect": default_source_effect}))
	_expect(not result.is_empty(), "canonical descriptor executes without a compatibility source override")
	var modifiers := Array(Dictionary(canonical_state.roster[0]).get("permanent_modifiers", []))
	var last_modifier := Dictionary(modifiers.back()) if not modifiers.is_empty() else {}
	_expect(String(last_modifier.get("source_id", "")) == "party_stat:atk", "new canonical input receives the generic source ID")


func _verify_atomic_rejection() -> void:
	var invalid_state: RefCounted = StateScript.new()
	var roster_before := Array(invalid_state.roster).duplicate(true)
	var invalid_result := Dictionary(invalid_state._apply_non_pet_shop_item({
		"effect": {
			"type": "party_stat", "stat": "atk", "base_stat": "base_def",
			"modifier_stat": "atk", "label": "攻击", "value": 3,
		},
	}))
	_expect(invalid_result.is_empty(), "mixed canonical descriptor is rejected")
	_expect(Array(invalid_state.roster) == roster_before, "invalid descriptor cannot partially mutate roster")

	var authority := FailingAuthority.new()
	var failing_before := authority.roster.duplicate(true)
	var port: RefCounted = ShopEffectPortScript.new(authority)
	var applied: bool = port.apply_party_modifier(
		{"stat": "atk", "base_stat": "base_atk", "modifier_stat": "atk"},
		2,
		"atomic_fixture"
	)
	_expect(not applied, "progression failure rejects the party mutation")
	_expect(authority.roster == failing_before, "progression failure commits no partial roster")


func _verify_non_party_state_mutations() -> void:
	var state: RefCounted = StateScript.new()
	var hp_before := int(state.hero_max_hp)
	state._apply_non_pet_shop_item({"effect": {"type": "hero_vitality", "value": 3}})
	_expect(int(state.hero_max_hp) == hp_before + 3, "hero vitality executes")
	state._apply_non_pet_shop_item({"effect": {"type": "free_refresh", "value": 2}})
	_expect(int(state.shop_free_rolls) == 2, "free refresh executes")
	var hash_before := String(state.snapshot().get("stateHash", ""))
	_expect(Dictionary(state._apply_non_pet_shop_item({"effect": {"type": "unknown"}})).is_empty(), "unknown effect is rejected")
	_expect(String(state.snapshot().get("stateHash", "")) == hash_before, "unknown effect has no authority side effect")


func _verify_catalog_schema() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bazaar_day1_shop_catalog.json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "canonical Bazaar supplement parses")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var expected_sources := {
		"skill_party_attack_1": "party_attack",
		"skill_party_defense_1": "party_defense",
		"skill_party_vitality_1": "party_vitality",
		"skill_party_shield_1": "party_shield",
	}
	var seen: Array[String] = []
	for value in Array(Dictionary(parsed).get("items", [])):
		var item := Dictionary(value)
		var item_id := String(item.get("id", ""))
		if not expected_sources.has(item_id):
			continue
		seen.append(item_id)
		var effect := Dictionary(item.get("effect", {}))
		_expect(String(effect.get("type", "")) == "party_stat", "%s uses canonical party_stat" % item_id)
		_expect(String(effect.get("source_id", "")) == String(expected_sources[item_id]), "%s freezes the legacy modifier source ID" % item_id)
		for field in ["stat", "base_stat", "modifier_stat", "label", "value"]:
			_expect(effect.has(field), "%s explicitly declares %s" % [item_id, field])
	seen.sort()
	var expected_ids: Array[String] = []
	for item_id in expected_sources.keys():
		expected_ids.append(String(item_id))
	expected_ids.sort()
	_expect(seen == expected_ids, "all four party catalog entries migrated to canonical descriptors")


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_SHOP_EFFECT_REGISTRY_FAIL: %s" % label)
