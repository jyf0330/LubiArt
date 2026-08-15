extends RefCounted

## Non-authoritative state projection used only when artists run ShopScene
## directly. It owns no Session, persistence, routing or Godot nodes.

const OFFER_COUNT := 5
const BAG_SLOT_COUNT := 8
const PREVIEW_OFFERS := [
	{"id": "preview_shop_001", "name": "预览商品1", "pet_id": "pal_001", "price": 2, "sold": false},
	{"id": "preview_shop_002", "name": "预览商品2", "pet_id": "pal_002", "price": 2, "sold": false},
	{"id": "preview_shop_003", "name": "预览商品3", "pet_id": "pal_003", "price": 2, "sold": false},
	{"id": "preview_shop_004", "name": "预览商品4", "pet_id": "pal_004", "price": 2, "sold": false},
	{"id": "preview_shop_005", "name": "预览商品5", "pet_id": "pal_005", "price": 2, "sold": false},
	{"id": "preview_shop_006", "name": "预览商品6", "pet_id": "pal_006", "price": 2, "sold": false},
	{"id": "preview_shop_007", "name": "预览商品7", "pet_id": "pal_007", "price": 2, "sold": false},
	{"id": "preview_shop_008", "name": "预览商品8", "pet_id": "pal_008", "price": 2, "sold": false},
	{"id": "preview_shop_009", "name": "预览商品9", "pet_id": "pal_009", "price": 2, "sold": false},
	{"id": "preview_shop_010", "name": "预览商品10", "pet_id": "pal_010", "price": 2, "sold": false},
]

var _snapshot: Dictionary = {}
var _roll_page := 0
var _owned_sequence := 0


func reset() -> Dictionary:
	_roll_page = 0
	_owned_sequence = 0
	_snapshot = {
		"phase": "shop",
		"coins": 15,
		"shop_offers": _offer_page(0),
		"roster": [{
			"id": "preview_party_001",
			"name": "预览队伍精灵",
			"pet_id": "pal_002",
			"active": true,
			"slot": 1,
			"bag_slot": 0,
		}],
	}
	return snapshot()


func snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func apply_command(command: Dictionary) -> Dictionary:
	var command_type := String(command.get("type", "")).to_upper()
	match command_type:
		"ROLL_SHOP":
			_roll_page = 1 - _roll_page
			_snapshot["shop_offers"] = _offer_page(_roll_page)
		"BUY_OFFER":
			_apply_drop({
				"source_type": "shop",
				"offer_id": String(command.get("offer_id", command.get("offerId", ""))),
				"target_type": "bag",
				"target_index": -1,
			})
		"DROP_ITEM_ON_TARGET":
			_apply_drop(command)
		"EXIT_SHOP":
			pass
		_:
			return {"accepted": false, "snapshot": snapshot(), "error": "unsupported_preview_command"}
	return {
		"accepted": true,
		"standalone_art_preview": true,
		"snapshot": snapshot(),
	}


func _offer_page(page: int) -> Array:
	var result: Array = []
	var start := clampi(page, 0, 1) * OFFER_COUNT
	for index in range(OFFER_COUNT):
		result.append(Dictionary(PREVIEW_OFFERS[start + index]).duplicate(true))
	return result


func _apply_drop(command: Dictionary) -> void:
	var source_type := String(command.get("source_type", "")).to_lower()
	var target_type := String(command.get("target_type", "")).to_lower()
	var target_index := int(command.get("target_index", -1))
	var roster := Array(_snapshot.get("roster", [])).duplicate(true)
	var source_index := -1
	var source_record: Dictionary = {}
	var source_was_active := false
	var source_party_slot := 0
	var source_bag_slot := -1
	var offer_id := ""
	var offer_price := 0
	if source_type == "shop":
		var offer := _offer_for_command(command)
		if offer.is_empty():
			return
		offer_id = String(offer.get("id", ""))
		offer_price = int(offer.get("price", 0))
		_owned_sequence += 1
		source_record = offer.duplicate(true)
		source_record["id"] = "preview_owned_%s_%d" % [offer_id, _owned_sequence]
		source_record["origin_offer_id"] = offer_id
		source_record.erase("sold")
		roster.append(source_record)
		source_index = roster.size() - 1
	else:
		source_index = _roster_source_index(roster, source_type, command)
		if source_index < 0:
			return
		source_record = Dictionary(roster[source_index]).duplicate(true)
		source_was_active = bool(source_record.get("active", false))
		source_party_slot = int(source_record.get("slot", 0))
		source_bag_slot = int(source_record.get("bag_slot", -1))
	var occupant_index := -1
	if target_type == "party":
		var party_slot := target_index + 1
		if party_slot <= 0:
			party_slot = _first_free_party_slot(roster, source_index)
		occupant_index = _active_at_slot(roster, party_slot, source_index)
		source_record["active"] = true
		source_record["slot"] = party_slot
	elif target_type == "bag":
		var bag_slot := target_index
		if bag_slot < 0 or (_inactive_at_slot(roster, bag_slot, source_index) >= 0 and source_type == "shop"):
			bag_slot = _first_free_bag_slot(roster, source_index)
		occupant_index = _inactive_at_slot(roster, bag_slot, source_index)
		source_record["active"] = false
		source_record["bag_slot"] = bag_slot
	else:
		return
	roster[source_index] = source_record
	if occupant_index >= 0:
		var occupant := Dictionary(roster[occupant_index]).duplicate(true)
		if source_type == "shop":
			occupant["active"] = false
			occupant["bag_slot"] = _first_free_bag_slot(roster, occupant_index)
		elif source_was_active:
			occupant["active"] = true
			occupant["slot"] = source_party_slot
		else:
			occupant["active"] = false
			occupant["bag_slot"] = source_bag_slot
		roster[occupant_index] = occupant
	if offer_id != "":
		var offers := Array(_snapshot.get("shop_offers", [])).duplicate(true)
		for index in range(offers.size()):
			if String(Dictionary(offers[index]).get("id", "")) == offer_id:
				offers[index] = {}
				break
		_snapshot["shop_offers"] = offers
		_snapshot["coins"] = maxi(0, int(_snapshot.get("coins", 0)) - offer_price)
	_snapshot["roster"] = roster


func _offer_for_command(command: Dictionary) -> Dictionary:
	var offer_id := String(command.get("offer_id", command.get("offerId", "")))
	var offers := Array(_snapshot.get("shop_offers", []))
	for value in offers:
		var offer := Dictionary(value)
		if String(offer.get("id", "")) == offer_id:
			return offer.duplicate(true)
	var source_index := int(command.get("source_index", -1))
	if source_index >= 0 and source_index < offers.size():
		return Dictionary(offers[source_index]).duplicate(true)
	return {}


func _roster_source_index(roster: Array, source_type: String, command: Dictionary) -> int:
	var unit_id := String(command.get("unitId", command.get("unit_id", "")))
	if unit_id != "":
		for index in range(roster.size()):
			if String(Dictionary(roster[index]).get("id", "")) == unit_id:
				return index
	var source_index := int(command.get("source_index", -1))
	if source_type == "party":
		return _active_at_slot(roster, source_index + 1)
	if source_type == "bag":
		var inactive := _inactive_indices(roster)
		if source_index >= 0 and source_index < inactive.size():
			return int(inactive[source_index])
	return -1


func _active_at_slot(roster: Array, slot: int, ignored_index: int = -1) -> int:
	for index in range(roster.size()):
		if index == ignored_index:
			continue
		var record := Dictionary(roster[index])
		if bool(record.get("active", false)) and int(record.get("slot", 0)) == slot:
			return index
	return -1


func _inactive_at_slot(roster: Array, slot: int, ignored_index: int = -1) -> int:
	for index in range(roster.size()):
		if index == ignored_index:
			continue
		var record := Dictionary(roster[index])
		if not bool(record.get("active", false)) and int(record.get("bag_slot", -1)) == slot:
			return index
	return -1


func _inactive_indices(roster: Array) -> Array:
	var indexed: Array = []
	for index in range(roster.size()):
		if not bool(Dictionary(roster[index]).get("active", false)):
			indexed.append(index)
	indexed.sort_custom(func(left, right):
		return int(Dictionary(roster[left]).get("bag_slot", 999)) < int(Dictionary(roster[right]).get("bag_slot", 999))
	)
	return indexed


func _first_free_party_slot(roster: Array, ignored_index: int = -1) -> int:
	for slot in range(1, 5):
		if _active_at_slot(roster, slot, ignored_index) < 0:
			return slot
	return 1


func _first_free_bag_slot(roster: Array, ignored_index: int = -1) -> int:
	for slot in range(BAG_SLOT_COUNT):
		if _inactive_at_slot(roster, slot, ignored_index) < 0:
			return slot
	return 0
