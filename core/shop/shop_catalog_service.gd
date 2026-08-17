extends RefCounted

## Composition root for shop catalog filtering, rolling, and offer creation.
## All runtime state is supplied as a narrow context and returned to GameSession.

const CandidateSpecificationScript := preload("res://core/shop/shop_candidate_specification.gd")
const RollStrategyScript := preload("res://core/shop/shop_roll_strategy.gd")
const OfferFactoryScript := preload("res://core/shop/shop_offer_factory.gd")

var _candidate_specification := CandidateSpecificationScript.new()
var _roll_strategy := RollStrategyScript.new()
var _offer_factory := OfferFactoryScript.new()


func has_candidates(items: Array, store: Dictionary, context: Dictionary) -> bool:
	for value in _enriched_items(items, context):
		if _candidate_specification.matches(Dictionary(value), store, context):
			return true
	return false


func build_offers(
	items: Array,
	store: Dictionary,
	requested_slots: int,
	kept_offers: Array,
	context: Dictionary
) -> Dictionary:
	var max_offers: int = max(0, int(context.get("max_offers", requested_slots)))
	var offers: Array = []
	var offered_keys := {}
	var key_fn: Callable = context.get("key_fn", Callable())
	for value in kept_offers:
		if offers.size() >= max_offers:
			break
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var kept_offer := Dictionary(value).duplicate(true)
		offers.append(kept_offer)
		var kept_key := _key_for(kept_offer, key_fn)
		if kept_key != "":
			offered_keys[kept_key] = true
	var candidates: Array = _candidate_specification.filter(_enriched_items(items, context), store, context)
	for index in range(candidates.size() - 1, -1, -1):
		var candidate_key := _key_for(Dictionary(candidates[index]), key_fn)
		if candidate_key != "" and offered_keys.has(candidate_key):
			candidates.remove_at(index)
	var count: int = min(candidates.size(), max(0, requested_slots - offers.size()))
	var selected: Array = _roll_strategy.select(candidates, count, store, context)
	var slot_index: int = offers.size()
	for value in selected:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		slot_index += 1
		offers.append(_offer_factory.create(Dictionary(value), slot_index, store, context))
	return {
		"offers": offers,
		"kept_offer_count": offers.size() - selected.size(),
		"generated_offer_count": selected.size(),
	}


func _key_for(item: Dictionary, key_fn: Callable) -> String:
	if key_fn.is_valid():
		return String(key_fn.call(item))
	return String(item.get("pet_id", item.get("id", "")))


func _enriched_items(items: Array, context: Dictionary) -> Array:
	var key_fn: Callable = context.get("key_fn", Callable())
	var source_by_pet := {}
	for value in Array(context.get("source_objects", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var source := Dictionary(value)
		var pet_id := String(source.get("pet_id", ""))
		if pet_id != "":
			source_by_pet[pet_id] = source
	var enriched: Array = []
	for value in items:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var item := Dictionary(value).duplicate(true)
		var pet_id := _key_for(item, key_fn)
		if source_by_pet.has(pet_id):
			_apply_source_object(item, Dictionary(source_by_pet[pet_id]))
		enriched.append(item)
	return enriched


func _apply_source_object(item: Dictionary, source: Dictionary) -> void:
	item["bazaar_object"] = source.duplicate(true)
	item["source_object_id"] = String(source.get("id", ""))
	for field in [
		"source_type", "source_status", "source_slug", "source_name", "source_tier",
		"source_size", "source_tags", "source_relation_count", "source_stall_ids",
		"local_shop_count", "local_shop_ids", "primary_enchant", "source_url",
		"source_effect", "design_note",
	]:
		item[field] = source.get(field, item.get(field))
