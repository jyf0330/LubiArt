extends SceneTree

const YsbzsStateScript := preload("res://core/state/game_state.gd")
const TEST_SEED := "ysbzs-test-play-20260715-v1"
const TEST_CONTEXT := "route:1:2:node_shop_fire"


func _initialize() -> void:
	var state := YsbzsStateScript.new()
	state.set_run_seed(TEST_SEED)
	if not state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "elem_火",
		"slots": 5,
		"seedContext": TEST_CONTEXT,
	}):
		push_error("Bazaar shop parity smoke could not enter the fixed fire shop.")
		quit(1)
		return
	if not _assert_unique_offer_pet_ids(state.snapshot(), "initial fixed-seed shop"):
		quit(1)
		return
	var offers := Array(state.snapshot().get("shop_offers", []))
	if offers.is_empty():
		push_error("Bazaar shop parity smoke needs at least one offer to test frozen rerolls.")
		quit(1)
		return
	var frozen_offer_id := String(Dictionary(offers[0]).get("offer_id", Dictionary(offers[0]).get("id", "")))
	if not state.dispatch({"type": "FREEZE_OFFER", "offerId": frozen_offer_id}):
		push_error("Bazaar shop parity smoke could not freeze the first offer.")
		quit(1)
		return
	if not state.dispatch({"type": "ROLL_SHOP", "free": true}):
		push_error("Bazaar shop parity smoke could not reroll with a frozen offer.")
		quit(1)
		return
	if not _assert_unique_offer_pet_ids(state.snapshot(), "frozen-offer reroll"):
		quit(1)
		return
	print("SMOKE_BAZAAR_SHOP_PARITY_OK seed=%s no_same_refresh_duplicates=true" % TEST_SEED)
	quit(0)


func _assert_unique_offer_pet_ids(snapshot: Dictionary, label: String) -> bool:
	var seen := {}
	for value in Array(snapshot.get("shop_offers", [])):
		var offer := Dictionary(value)
		var pet_id := String(offer.get("pet_id", offer.get("petId", "")))
		if pet_id == "":
			continue
		if seen.has(pet_id):
			push_error("%s repeats pet_id=%s in one shop refresh." % [label, pet_id])
			return false
		seen[pet_id] = true
	return true
