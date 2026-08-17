extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failures := 0


func _initialize() -> void:
	_test_formal_stall_slots_and_refresh_costs()
	_test_curio_ten_slot_catalog()
	_test_closed_stall_rejected()
	_test_day_two_stall_rotation()
	_test_daily_seen_pool()
	_test_daily_seen_pool_persistence()
	_test_owned_diamond_filter()
	_test_same_quality_merge_and_acquisition_history()
	if failures > 0:
		push_error("SMOKE_BAZAAR_SHOP_RULES_FAILED count=%d" % failures)
		quit(1)
		return
	print("SMOKE_BAZAAR_SHOP_RULES_OK ordinary_slots=3 curio_slots=10 free_refresh=1 paid_refresh=2/4/6/8 daily_seen=true cross_shop_unique=true next_day_reset=true daily_seen_saved=true diamond_filtered=true same_quality_merge=true acquisition_history_saved=true")
	quit(0)


func _test_formal_stall_slots_and_refresh_costs() -> void:
	var state := StateScript.new()
	state.coins = 999
	_expect(state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "night_base",
		"stallId": "merchant_aila",
		"slots": 99,
		"seedContext": "bazaar-rules-aila",
	}), "can enter formal Aila stall")
	var snapshot := state.snapshot()
	var active_stall := Dictionary(snapshot.get("active_stall", {}))
	_expect(String(active_stall.get("source_stall_id", "")) == "merchant_aila", "active stall records Aila rather than the aggregate location")
	_expect(Array(snapshot.get("shop_offers", [])).size() == 3, "ordinary formal stall exposes exactly three offers")
	_expect(int(active_stall.get("slots", 0)) == 3, "formal stall slots override caller-supplied slot count")
	_expect(int(Dictionary(snapshot.get("shop_refresh", {})).get("free_rolls", -1)) == 1, "formal stall starts with one free refresh")
	_expect(int(Dictionary(snapshot.get("shop_refresh", {})).get("next_refresh_cost", -1)) == 0, "free refresh is projected as zero cost")
	_expect(state.dispatch({"type": "ROLL_SHOP"}), "first refresh consumes the formal free reroll")
	var after_free := Dictionary(state.snapshot().get("shop_refresh", {}))
	_expect(int(after_free.get("free_rolls", -1)) == 0, "free refresh count is consumed")
	_expect(int(after_free.get("paid_refreshes", -1)) == 0, "free refresh does not increment paid refresh count")
	var expected_costs := [2, 4, 6, 8, 8]
	for expected_cost in expected_costs:
		var refresh := Dictionary(state.snapshot().get("shop_refresh", {}))
		_expect(int(refresh.get("next_refresh_cost", -1)) == expected_cost, "next paid refresh cost is %d" % expected_cost)
		_expect(state.dispatch({"type": "ROLL_SHOP"}), "paid refresh costing %d succeeds" % expected_cost)


func _test_curio_ten_slot_catalog() -> void:
	var state := StateScript.new()
	_expect(state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "elem_草",
		"stallId": "merchant_curio",
		"slots": 3,
		"seedContext": "bazaar-rules-curio",
	}), "can enter formal Curio stall")
	var snapshot := state.snapshot()
	var active_stall := Dictionary(snapshot.get("active_stall", {}))
	var offers := Array(snapshot.get("shop_offers", []))
	_expect(int(active_stall.get("slots", 0)) == 10, "Curio mapping overrides caller slots with ten")
	_expect(offers.size() == 10, "Curio exposes ten source-accurate offers")
	for value in offers:
		var offer := Dictionary(value)
		_expect(String(offer.get("source_stall_id", "")) == "merchant_curio", "Curio offer exposes its source stall")
		_expect(Array(offer.get("source_stall_ids", [])).has("merchant_curio"), "Curio offer belongs to Curio's source relation")


func _test_closed_stall_rejected() -> void:
	var state := StateScript.new()
	_expect(not state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "night_base",
		"stallId": "merchant_herma",
		"seedContext": "bazaar-rules-closed-herma",
	}), "day-one entry rejects the later Herma stall")


func _test_day_two_stall_rotation() -> void:
	var kina_state := StateScript.new()
	kina_state.day = 2
	_expect(not kina_state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "elem_冰",
		"stallId": "merchant_kina",
		"seedContext": "bazaar-rules-day2-kina",
	}), "day two rejects Kina after departure")
	var mittel_state := StateScript.new()
	mittel_state.day = 2
	_expect(mittel_state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "elem_无",
		"stallId": "merchant_mittel",
		"seedContext": "bazaar-rules-day2-mittel",
	}), "day two opens Mittel")
	_expect(String(Dictionary(mittel_state.snapshot().get("active_stall", {})).get("source_stall_id", "")) == "merchant_mittel", "Mittel remains an independent active stall")
	var quixel_state := StateScript.new()
	quixel_state.day = 2
	_expect(quixel_state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "role_召唤",
		"stallId": "merchant_quixel",
		"seedContext": "bazaar-rules-day2-quixel",
	}), "day two opens Quixel")
	_expect(String(Dictionary(quixel_state.snapshot().get("active_stall", {})).get("source_stall_id", "")) == "merchant_quixel", "Quixel remains an independent active stall")


func _test_daily_seen_pool() -> void:
	var state = _daily_seen_fixture_state()
	_expect(state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "daily_seen_a",
		"slots": 3,
		"seedContext": "daily-seen-first",
	}), "daily-seen fixture enters its first shop")
	var first_ids := _offer_pet_ids(Array(state.snapshot().get("shop_offers", [])))
	_expect(first_ids.size() == 3, "first daily shop exposes three pets")
	_expect(Array(state.snapshot().get("shop_seen_pet_ids", [])).size() == 3, "first display records three pets in today's seen pool")
	_expect(state.dispatch({"type": "ROLL_SHOP", "free": true}), "daily-seen fixture rerolls the first shop")
	var second_ids := _offer_pet_ids(Array(state.snapshot().get("shop_offers", [])))
	_expect(not _arrays_overlap(first_ids, second_ids), "same-day reroll excludes every previously displayed pet")
	_expect(Array(state.snapshot().get("shop_seen_pet_ids", [])).size() == 6, "reroll extends today's seen pool")
	_expect(state.dispatch({"type": "EXIT_SHOP"}), "daily-seen fixture leaves the first shop")
	_expect(state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "daily_seen_b",
		"slots": 3,
		"seedContext": "daily-seen-second-shop",
	}), "daily-seen fixture enters a second shop")
	var third_ids := _offer_pet_ids(Array(state.snapshot().get("shop_offers", [])))
	var earlier_ids := first_ids + second_ids
	_expect(not _arrays_overlap(earlier_ids, third_ids), "second same-day shop excludes pets seen in the first shop and its reroll")
	_expect(Array(state.snapshot().get("shop_seen_pet_ids", [])).size() == 9, "cross-shop display records all nine unique daily pets")
	_expect(state.dispatch({"type": "ROLL_SHOP", "free": true}), "exhausted daily shop can still resolve a reroll command")
	_expect(Array(state.snapshot().get("shop_offers", [])).is_empty(), "exhausted same-day catalog returns no repeated fallback pets")
	_expect(state.dispatch({"type": "EXIT_SHOP"}), "daily-seen fixture leaves the exhausted shop")
	state.day = 2
	_expect(state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "daily_seen_a",
		"slots": 3,
		"seedContext": "daily-seen-day-two",
	}), "day two can enter the same source catalog")
	_expect(Array(state.snapshot().get("shop_offers", [])).size() == 3, "day two uses a fresh seen pool")
	_expect(Array(state.snapshot().get("shop_seen_pet_ids", [])).size() == 3, "day two tracks only its own displayed pets")


func _test_daily_seen_pool_persistence() -> void:
	var state := StateScript.new()
	_expect(state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "night_base",
		"stallId": "merchant_aila",
		"seedContext": "daily-seen-save",
	}), "daily-seen save fixture enters Aila")
	var seen_before := Array(state.snapshot().get("shop_seen_pet_ids", []))
	var checkpoint := state.save_document("daily-seen", {"historyCheckpoint": true})
	_expect(Dictionary(checkpoint.get("state", {})).has("shop_seen_pet_ids_by_day"), "history checkpoint stores the daily seen pool")
	var loaded := StateScript.new()
	_expect(loaded.load_document(checkpoint), "history checkpoint with daily seen pool loads")
	_expect(Array(loaded.snapshot().get("shop_seen_pet_ids", [])) == seen_before, "loaded checkpoint preserves today's seen pet ids")


func _test_owned_diamond_filter() -> void:
	var state := _test_state()
	var template := Dictionary(Array(state.snapshot().get("roster", []))[0]).duplicate(true)
	var diamond := template.duplicate(true)
	diamond["id"] = "pal_owned_diamond"
	diamond["pet_id"] = "pal_owned_diamond"
	diamond["name"] = "已持有钻石宠"
	diamond["quality"] = "钻石"
	state.roster = [diamond]
	var blocked_item := diamond.duplicate(true)
	blocked_item["quality"] = "青铜"
	blocked_item["shop_pools"] = ["test_diamond_filter"]
	blocked_item["unlock_day"] = 1
	blocked_item["weights"] = {"night": 100}
	blocked_item["price"] = 2
	var allowed_item := template.duplicate(true)
	allowed_item["id"] = "pal_allowed"
	allowed_item["pet_id"] = "pal_allowed"
	allowed_item["name"] = "可售宠物"
	allowed_item["shop_pools"] = ["test_diamond_filter"]
	allowed_item["unlock_day"] = 1
	allowed_item["weights"] = {"night": 100}
	allowed_item["price"] = 2
	var economy := Dictionary(state.game_data.get("economy", {})).duplicate(true)
	economy["shop_items"] = [blocked_item, allowed_item]
	var updated_content := Dictionary(state.game_data).duplicate(true)
	updated_content["economy"] = economy
	_expect(state.replace_game_data_for_test(updated_content, &"current_assembly"), "diamond-filter fixture binds through the test-only authority helper")
	_expect(state.dispatch({"type": "ENTER_SHOP", "poolId": "test_diamond_filter", "slots": 5, "seedContext": "owned-diamond-filter"}), "can enter controlled diamond-filter shop")
	var ids := []
	for value in Array(state.snapshot().get("shop_offers", [])):
		ids.append(String(Dictionary(value).get("pet_id", "")))
	_expect(not ids.has("pal_owned_diamond"), "ordinary shop excludes a pet already owned at diamond quality")
	_expect(ids.has("pal_allowed"), "diamond filtering keeps other eligible pets")


func _test_same_quality_merge_and_acquisition_history() -> void:
	var state := StateScript.new()
	var source := Dictionary(Array(state.snapshot().get("roster", []))[0]).duplicate(true)
	var pet_id := String(source.get("pet_id", source.get("id", "")))
	source["pet_id"] = pet_id
	source["quality"] = "青铜"
	state.roster = []
	var first := state._add_pet_to_roster(source, "shop")
	_expect(not bool(first.get("merged", true)), "first bronze copy creates a roster instance")
	var first_pet := Dictionary(state.roster[0])
	_expect(String(first_pet.get("acquired_from", "")) == "shop", "roster instance stores acquisition source")
	_expect(typeof(first_pet.get("acquired_at", null)) == TYPE_DICTIONARY, "roster instance stores deterministic purchase moment")
	_expect(Array(first_pet.get("acquisition_history", [])).size() == 1, "roster instance starts acquisition history")
	var silver_source := source.duplicate(true)
	silver_source["quality"] = "白银"
	var cross_quality := state._add_pet_to_roster(silver_source, "shop")
	_expect(not bool(cross_quality.get("merged", true)), "same pet at a different quality does not merge")
	_expect(state.roster.size() == 2, "different qualities remain separate roster instances")
	if state.roster.size() >= 2:
		_expect(String(Dictionary(state.roster[0]).get("id", "")) != String(Dictionary(state.roster[1]).get("id", "")), "separate quality instances have unique runtime ids")
	var same_quality := state._add_pet_to_roster(source, "reward")
	_expect(bool(same_quality.get("merged", false)), "same pet at the same quality merges")
	_expect(String(same_quality.get("quality", "")) == "白银", "two bronze copies upgrade to silver")
	var merged_history_found := false
	for value in state.roster:
		var pet := Dictionary(value)
		if String(pet.get("pet_id", "")) == pet_id and Array(pet.get("acquisition_history", [])).size() == 2:
			merged_history_found = true
	_expect(merged_history_found, "merge keeps both acquisition moments and sources")
	var save_doc := state.save_document()
	var loaded := StateScript.new()
	_expect(loaded.load_document(save_doc), "save document with acquisition history loads")
	var saved_history_found := false
	for value in Array(loaded.snapshot().get("roster", [])):
		var pet := Dictionary(value)
		if String(pet.get("pet_id", "")) == pet_id and Array(pet.get("acquisition_history", [])).size() == 2:
			saved_history_found = true
	_expect(saved_history_found, "acquisition history survives save and load")


func _daily_seen_fixture_state():
	var state := _test_state()
	var template := Dictionary(Array(state.snapshot().get("roster", []))[0]).duplicate(true)
	var items: Array = []
	for index in range(9):
		var pet := template.duplicate(true)
		var pet_id := "daily_seen_pet_%02d" % (index + 1)
		pet["id"] = pet_id
		pet["pet_id"] = pet_id
		pet["name"] = "当日去重测试宠%d" % (index + 1)
		pet["item_type"] = "宠物"
		pet["quality"] = "青铜"
		pet["unlock_day"] = 1
		pet["shop_pools"] = ["daily_seen_a", "daily_seen_b"]
		pet["weights"] = {"night": 100, "element": 100, "role": 100, "tier": 100}
		pet["price"] = 2
		items.append(pet)
	var economy := Dictionary(state.game_data.get("economy", {})).duplicate(true)
	economy["shop_items"] = items
	economy["bazaar_objects"] = []
	var updated_content := Dictionary(state.game_data).duplicate(true)
	updated_content["economy"] = economy
	_expect(state.replace_game_data_for_test(updated_content, &"current_assembly"), "daily-seen fixture binds through the test-only authority helper")
	state.set_run_seed("daily-seen-fixture")
	return state


func _test_state() -> RefCounted:
	var production: RefCounted = StateScript.new()
	return StateScript.new({
		"mode": "test",
		"content_pack": Dictionary(production.get("game_data")).duplicate(true),
		"content_source_kind": production.call("content_source_kind"),
	})


func _offer_pet_ids(offers: Array) -> Array:
	var pet_ids: Array = []
	for value in offers:
		var pet_id := String(Dictionary(value).get("pet_id", ""))
		if pet_id != "":
			pet_ids.append(pet_id)
	return pet_ids


func _arrays_overlap(left: Array, right: Array) -> bool:
	for value in left:
		if right.has(value):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
