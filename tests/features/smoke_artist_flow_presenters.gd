extends SceneTree

const RoutePresenterScript := preload("res://core_ui/scripts/route/presenters/route_presenter.gd")
const ShopPresenterScript := preload("res://core_ui/scripts/shop/presenters/shop_presenter.gd")
const InventoryPresenterScript := preload("res://core_ui/scripts/inventory/presenters/inventory_presenter.gd")
const PartyPresenterScript := preload("res://core_ui/scripts/party/presenters/party_presenter.gd")
const SettlementPresenterScript := preload("res://core_ui/scripts/settlement/presenters/settlement_presenter.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var snapshot := {
		"phase": "route",
		"day": 2,
		"route_options": [
			{"id": "node_shop_basic", "title": "商店"},
			{"id": "node_reward_pet", "kind": "reward"},
		],
		"shop_offers": [
			{"id": "offer_1", "pet_id": "pal_001"},
			{"id": "offer_2", "sold": true},
		],
		"reward_options": [{"id": "reward_1", "pet_id": "pal_002"}],
		"roster": [
			{"id": "party_1", "active": true, "slot": 2},
			{"id": "bag_2", "active": false, "bag_slot": 2},
			{"id": "bag_1", "active": false, "bag_slot": 1},
		],
	}

	var route_cards := Array(RoutePresenterScript.new().call("cards", snapshot))
	_expect(route_cards.size() == 2, "route presenter returns authored card count")
	_expect(String(Dictionary(route_cards[0]).get("kind", "")) == "shop", "route presenter normalizes route kind")
	_expect(String(Dictionary(Dictionary(route_cards[0]).get("command", {})).get("type", "")) == "CHOOSE_ROUTE", "route presenter owns route command")

	var shop_cards := Array(ShopPresenterScript.new().call("cards", snapshot))
	_expect(bool(Dictionary(shop_cards[0]).get("available", false)), "shop presenter exposes available offer")
	_expect(not bool(Dictionary(shop_cards[1]).get("available", true)), "shop presenter hides sold offer")

	var party_slots := Array(PartyPresenterScript.new().call("slots", snapshot, 3))
	_expect(String(Dictionary(party_slots[1]).get("id", "")) == "party_1", "party presenter preserves authored slot")

	var inventory_page := Dictionary(InventoryPresenterScript.new().call("page", snapshot, 0, 1))
	_expect(String(Dictionary(Array(inventory_page.get("items", []))[0]).get("id", "")) == "bag_1", "inventory presenter sorts and pages bag pets")
	_expect(int(inventory_page.get("page_count", 0)) == 2, "inventory presenter reports page count")

	var settlement := SettlementPresenterScript.new()
	var reward_cards := Array(settlement.call("reward_cards", snapshot))
	_expect(String(Dictionary(Dictionary(reward_cards[0]).get("command", {})).get("type", "")) == "PICK_REWARD", "settlement presenter owns reward command")
	var terminal := Dictionary(settlement.call("terminal_card", {"phase": "day_end", "day": 2}, "seed"))
	_expect(String(Dictionary(terminal.get("command", {})).get("type", "")) == "START_NEXT_DAY", "settlement presenter owns terminal command")

	var controller_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd")
	_expect(controller_source.find('presenters/route_presenter.gd') >= 0, "artist flow composes route presenter")
	_expect(controller_source.find('snapshot().get("reward_options"') < 0, "reward click does not reread raw reward options")

	if failures.is_empty():
		print("ARTIST_FLOW_PRESENTER_SMOKE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
