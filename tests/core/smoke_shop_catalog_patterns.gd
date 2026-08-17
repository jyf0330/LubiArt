extends SceneTree

const CandidateSpecificationScript := preload("res://core/shop/shop_candidate_specification.gd")
const RollStrategyScript := preload("res://core/shop/shop_roll_strategy.gd")
const OfferFactoryScript := preload("res://core/shop/shop_offer_factory.gd")
const ShopCatalogServiceScript := preload("res://core/shop/shop_catalog_service.gd")
const ShopStallCatalogScript := preload("res://core/shop/shop_stall_catalog.gd")
const SeededSelectorScript := preload("res://core/run/seeded_selector.gd")

var failures := 0


func _initialize() -> void:
	_test_composed_candidate_specification()
	_test_deterministic_roll_strategies()
	_test_stall_catalog()
	_test_catalog_service_and_offer_factory()
	if failures > 0:
		push_error("SMOKE_SHOP_CATALOG_PATTERNS_FAILED count=%d" % failures)
		quit(1)
		return
	print("SMOKE_SHOP_CATALOG_PATTERNS_OK specification=true strategy=true stall_catalog=true factory=true source_enrichment=true frozen_unique=true")
	quit(0)


func _test_composed_candidate_specification() -> void:
	var specification := CandidateSpecificationScript.new()
	var store := {
		"id": "spec_store",
		"pool_id": "spec_store",
		"specification": {
			"item_types": ["宠物"],
			"qualities": ["白银", "黄金"],
			"elements_any": ["火"],
			"roles": ["输出"],
			"tags_all": ["多重攻击"],
			"traits_any": ["多重攻击"],
			"enchantments_any": ["Restorative"],
			"source_types": ["merchant_package"],
			"source_tiers": ["bronze"],
			"source_sizes": ["Small"],
			"source_tags_all": ["weapon", "aquatic"],
			"min_action_count": 3,
			"min_attack_target_count": 2,
			"enchanted": true,
		},
	}
	var eligible := _item("pal_a", "白银", "火", "输出", 3, 2, ["多重攻击"], 5)
	eligible["source_type"] = "merchant_package"
	eligible["source_tier"] = "bronze"
	eligible["source_size"] = "Small"
	eligible["source_tags"] = ["weapon", "aquatic"]
	eligible["source_stall_ids"] = ["merchant_aila"]
	eligible["primary_enchant"] = "Restorative"
	var wrong_quality := _item("pal_b", "青铜", "火", "输出", 3, 2, ["多重攻击"], 5)
	for key in ["source_type", "source_tier", "source_size", "source_tags", "source_stall_ids", "primary_enchant"]:
		wrong_quality[key] = eligible[key]
	var blocked := eligible.duplicate(true)
	blocked["pet_id"] = "pal_blocked"
	var context := {
		"day": 1,
		"source_stall_id": "merchant_aila",
		"weight_fn": func(row: Dictionary): return int(row.get("test_weight", 0)),
		"blocked_fn": func(row: Dictionary): return String(row.get("pet_id", "")) == "pal_blocked",
	}
	_expect(specification.matches(eligible, store, context), "composed specification accepts matching pet")
	_expect(not specification.matches(wrong_quality, store, context), "composed specification rejects wrong quality")
	_expect(not specification.matches(blocked, store, context), "composed specification applies runtime owned-diamond blocker")
	var wrong_stall_context := context.duplicate()
	wrong_stall_context["source_stall_id"] = "merchant_curio"
	_expect(not specification.matches(eligible, store, wrong_stall_context), "source stall specification prevents location-pool merging")


func _test_deterministic_roll_strategies() -> void:
	var strategy := RollStrategyScript.new()
	var candidates := [
		_item("pal_c", "青铜", "水", "治疗", 2, 1, [], 20),
		_item("pal_a", "青铜", "火", "输出", 3, 2, [], 10),
		_item("pal_b", "青铜", "土", "坦克", 1, 1, [], 30),
	]
	var first := strategy.select(candidates, 2, {"roll_strategy": "weighted_unique"}, _roll_context("stable-seed"))
	var second := strategy.select(candidates, 2, {"roll_strategy": "weighted_unique"}, _roll_context("stable-seed"))
	_expect(_pet_ids(first) == _pet_ids(second), "weighted strategy is deterministic for the same seed")
	_expect(_pet_ids(first).size() == 2 and _pet_ids(first)[0] != _pet_ids(first)[1], "weighted strategy selects unique pet ids")
	var ordered := strategy.select(candidates, 3, {"roll_strategy": "catalog_order"}, _roll_context("ignored"))
	_expect(_pet_ids(ordered) == ["pal_a", "pal_b", "pal_c"], "catalog-order strategy follows stable pet id order")


func _test_stall_catalog() -> void:
	var catalog := ShopStallCatalogScript.new()
	var location := {"id": "night_base", "name": "寅将军", "default_slots": 3}
	var mappings := [
		_mapping("merchant_aila", "Aila", "night_base", 1, 0, 3),
		_mapping("merchant_herma", "Herma", "night_base", 4, 0, 3),
	]
	_expect(catalog.has_location(mappings, "night_base"), "stall catalog identifies a mapped Journey location")
	_expect(catalog.open_stalls(mappings, "night_base", 1).size() == 1, "day one only opens Aila at 寅将军")
	var day_one := Dictionary(catalog.resolve(location, mappings, 1, "stable-stall"))
	_expect(String(day_one.get("source_stall_id", "")) == "merchant_aila", "stall resolver returns the open source stall")
	_expect(int(day_one.get("slots", 0)) == 3 and int(day_one.get("free_rerolls", 0)) == 1, "stall Type Object carries slots and free rerolls")
	var unavailable := Dictionary(catalog.resolve(location, mappings, 1, "stable-stall", "merchant_herma"))
	_expect(not bool(unavailable.get("available", true)), "closed preferred stall cannot silently fall back to another merchant")
	var day_four := Dictionary(catalog.resolve(location, mappings, 4, "stable-stall", "merchant_herma"))
	_expect(bool(day_four.get("available", false)) and String(day_four.get("source_name", "")) == "Herma", "later-day preferred stall resolves independently")
	var deterministic_a := Dictionary(catalog.resolve(location, mappings, 4, "stable-stall"))
	var deterministic_b := Dictionary(catalog.resolve(location, mappings, 4, "stable-stall"))
	_expect(String(deterministic_a.get("id", "")) == String(deterministic_b.get("id", "")), "multi-stall selection is deterministic for the same seed")


func _test_catalog_service_and_offer_factory() -> void:
	var service := ShopCatalogServiceScript.new()
	var factory := OfferFactoryScript.new()
	var store := {
		"id": "merchant_aila",
		"stall_id": "merchant_aila",
		"source_stall_id": "merchant_aila",
		"location_id": "night_base",
		"pool_id": "night_base",
		"roll_strategy": "catalog_order",
	}
	var pet_a := _item("pal_a", "青铜", "火", "输出", 3, 2, [], 10)
	var pet_a_duplicate := pet_a.duplicate(true)
	pet_a_duplicate["id"] = "pal_a_duplicate_row"
	var pet_b := _item("pal_b", "白银", "水", "治疗", 2, 1, [], 10)
	var pet_c := _item("pal_c", "黄金", "土", "坦克", 1, 3, [], 10)
	var pet_other_stall := _item("pal_other", "青铜", "风", "机动", 2, 1, [], 10)
	var kept := factory.create(pet_a, 1, store, {"discount": 0})
	kept["frozen"] = true
	var context := _roll_context("catalog-service")
	context["day"] = 1
	context["discount"] = 25
	context["max_offers"] = 5
	context["source_stall_id"] = "merchant_aila"
	context["source_objects"] = [
		_source_object("pal_a", "item", "bronze", "small", ["weapon"], ["merchant_aila"], "Deadly"),
		_source_object("pal_b", "merchant_package", "silver", "Medium", ["aquatic"], ["merchant_aila"], "Restorative"),
		_source_object("pal_c", "skill", "gold", "", ["skill"], ["merchant_aila"], "Turbo"),
		_source_object("pal_other", "item", "bronze", "small", ["weapon"], ["merchant_curio"], "Fiery"),
	]
	context["blocked_fn"] = func(_row: Dictionary): return false
	var result := Dictionary(service.build_offers(
		[pet_a, pet_a_duplicate, pet_b, pet_c, pet_other_stall],
		store,
		3,
		[kept],
		context
	))
	var offers := Array(result.get("offers", []))
	_expect(offers.size() == 3, "catalog service keeps frozen offer and fills requested slots")
	_expect(_pet_ids(offers) == ["pal_a", "pal_b", "pal_c"], "catalog service removes frozen-pet duplicates")
	_expect(int(result.get("kept_offer_count", -1)) == 1, "catalog service reports kept offer count")
	_expect(int(result.get("generated_offer_count", -1)) == 2, "catalog service reports generated offer count")
	var generated := Dictionary(offers[1])
	_expect(String(generated.get("offer_id", "")) == "shop_002", "offer factory assigns slot-stable offer id")
	_expect(String(generated.get("source_store_id", "")) == "night_base", "offer factory preserves the Journey store id")
	_expect(String(generated.get("source_stall_id", "")) == "merchant_aila", "offer factory exposes source stall id")
	_expect(String(generated.get("source_location_id", "")) == "night_base", "offer factory exposes Journey location id")
	_expect(String(generated.get("source_type", "")) == "merchant_package", "catalog service enriches offers from Bazaar objects")
	_expect(String(generated.get("primary_enchant", "")) == "Restorative", "catalog service keeps the source object's primary enchantment")
	_expect(not _pet_ids(offers).has("pal_other"), "catalog service does not merge a second stall's objects into the active stall")
	_expect(int(generated.get("base_price", 0)) == 4 and int(generated.get("price", 0)) == 3, "offer factory applies configured discount")
	_expect(not bool(generated.get("sold", true)), "offer factory creates an unsold snapshot")


func _item(
	pet_id: String,
	quality: String,
	element: String,
	role: String,
	slot_count: int,
	hit_cells: int,
	tags: Array,
	weight: int
) -> Dictionary:
	return {
		"id": pet_id,
		"pet_id": pet_id,
		"name": pet_id,
		"item_type": "宠物",
		"quality": quality,
		"element": element,
		"element_types": [element],
		"role": role,
		"slot_count": slot_count,
		"hit_cells": hit_cells,
		"tags": tags,
		"unlock_day": 1,
		"shop_pools": ["night_base", "spec_store"],
		"price": 4,
		"test_weight": weight,
	}


func _roll_context(seed: String) -> Dictionary:
	return {
		"random": SeededSelectorScript.rng(seed),
		"weight_fn": func(row: Dictionary): return int(row.get("test_weight", 0)),
		"key_fn": func(row: Dictionary): return String(row.get("pet_id", row.get("id", ""))),
	}


func _mapping(
	stall_id: String,
	source_name: String,
	location_id: String,
	unlock_day: int,
	close_day: int,
	slots: int
) -> Dictionary:
	return {
		"id": stall_id,
		"source_name": source_name,
		"source_node_type": "merchant",
		"local_shop_id": location_id,
		"unlock_day": unlock_day,
		"close_day": close_day,
		"offer_slots": slots,
		"free_rerolls": 1,
	}


func _source_object(
	pet_id: String,
	source_type: String,
	source_tier: String,
	source_size: String,
	source_tags: Array,
	source_stall_ids: Array,
	primary_enchant: String
) -> Dictionary:
	return {
		"id": "source_%s" % pet_id,
		"pet_id": pet_id,
		"source_type": source_type,
		"source_tier": source_tier,
		"source_size": source_size,
		"source_tags": source_tags,
		"source_stall_ids": source_stall_ids,
		"primary_enchant": primary_enchant,
	}


func _pet_ids(items: Array) -> Array:
	var ids: Array = []
	for value in items:
		ids.append(String(Dictionary(value).get("pet_id", "")))
	return ids


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
