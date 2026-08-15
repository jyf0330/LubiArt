extends SceneTree

const MockGameSessionScript := preload("res://session/mock_game_session.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := MockGameSessionScript.new()
	var route_snapshot := Dictionary(session.current_snapshot())
	var shop_option := _first_shop_option(route_snapshot)
	_expect(not shop_option.is_empty(), "public Snapshot exposes a shop route")
	var route_response := Dictionary(session.submit_command({
		"type": "CHOOSE_ROUTE",
		"option_id": String(shop_option.get("id", shop_option.get("optionId", ""))),
		"kind": "shop",
	}))
	_expect(bool(route_response.get("accepted", false)), "shop route projection is accepted")

	var shop_snapshot := Dictionary(route_response.get("snapshot", {}))
	var initial_offer_ids := _offer_ids(shop_snapshot).slice(0, 5)
	var roll_response := Dictionary(session.submit_command({"type": "ROLL_SHOP"}))
	var rolled_snapshot := Dictionary(roll_response.get("snapshot", {}))
	var rolled_offer_ids := _offer_ids(rolled_snapshot)
	_expect(bool(roll_response.get("accepted", false)), "ROLL_SHOP returns through the public command contract")
	_expect(rolled_offer_ids.size() == 5 and rolled_offer_ids != initial_offer_ids, "ROLL_SHOP replaces all five visible offer records")

	var dragged_offer := Dictionary(Array(rolled_snapshot.get("shop_offers", []))[0])
	var dragged_offer_id := String(dragged_offer.get("id", ""))
	var coins_before_drag := int(rolled_snapshot.get("coins", 0))
	var roster_before_drag := Array(rolled_snapshot.get("roster", [])).size()
	var drag_response := Dictionary(session.submit_command({
		"type": "DROP_ITEM_ON_TARGET",
		"source_type": "shop",
		"source_index": 0,
		"offer_id": dragged_offer_id,
		"target_type": "party",
		"target_index": 0,
	}))
	var dragged_snapshot := Dictionary(drag_response.get("snapshot", {}))
	_expect(not _offer_ids(dragged_snapshot).has(dragged_offer_id), "shop drag removes the purchased offer")
	_expect(Array(dragged_snapshot.get("shop_offers", [])).size() == 5, "shop drag preserves the five authored shelf positions")
	_expect(Dictionary(Array(dragged_snapshot.get("shop_offers", []))[0]).is_empty(), "shop drag leaves the purchased shelf position empty")
	_expect(String(Dictionary(Array(dragged_snapshot.get("shop_offers", []))[1]).get("id", "")) == rolled_offer_ids[1], "shop drag does not compact the following offer into the empty position")
	_expect(Array(dragged_snapshot.get("roster", [])).size() == roster_before_drag + 1, "shop drag adds the exported pet record to roster")
	_expect(int(dragged_snapshot.get("coins", 0)) == coins_before_drag - int(dragged_offer.get("price", 0)), "shop drag pays the exported price")

	var clicked_offer := Dictionary(Array(dragged_snapshot.get("shop_offers", []))[1])
	var clicked_offer_id := String(clicked_offer.get("id", ""))
	var roster_before_click := Array(dragged_snapshot.get("roster", [])).size()
	var buy_response := Dictionary(session.submit_command({
		"type": "BUY_OFFER",
		"offer_id": clicked_offer_id,
	}))
	var bought_snapshot := Dictionary(buy_response.get("snapshot", {}))
	_expect(not _offer_ids(bought_snapshot).has(clicked_offer_id), "BUY_OFFER removes the clicked offer")
	_expect(Dictionary(Array(bought_snapshot.get("shop_offers", []))[0]).is_empty(), "BUY_OFFER keeps the earlier empty shelf position")
	_expect(Dictionary(Array(bought_snapshot.get("shop_offers", []))[1]).is_empty(), "BUY_OFFER empties only the clicked shelf position")
	_expect(Array(bought_snapshot.get("roster", [])).size() == roster_before_click + 1, "BUY_OFFER places the exported pet in the first free bag slot")

	print("SMOKE_SHOP_SESSION_PROJECTION_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _first_shop_option(snapshot: Dictionary) -> Dictionary:
	for value in Array(snapshot.get("route_options", [])):
		var option := Dictionary(value)
		if String(option.get("kind", option.get("nodeType", ""))) == "shop":
			return option
	return {}


func _offer_ids(snapshot: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for value in Array(snapshot.get("shop_offers", [])):
		result.append(String(Dictionary(value).get("id", "")))
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_SHOP_SESSION_PROJECTION_FAIL: %s" % message)
