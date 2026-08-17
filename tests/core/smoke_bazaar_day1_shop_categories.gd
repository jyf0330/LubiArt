extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const ContentLoadServiceScript := preload("res://core/content/content_load_service.gd")
const GameDataRepositoryScript := preload("res://persistence/game_data_repository.gd")


func _initialize() -> void:
	var ok := true
	var state := StateScript.new()
	var data := state.game_data
	var route := Dictionary(data.get("route", {}))
	var economy := Dictionary(data.get("economy", {}))
	var nodes := Array(route.get("node_pool", []))
	var items := Array(economy.get("shop_items", []))
	var stores := Array(economy.get("shop_stores", []))
	var objects := Array(economy.get("bazaar_objects", []))
	var mappings := Array(economy.get("shop_mapping", []))
	var required_nodes := [
		"node_shop_basic",
		"node_shop_element_day1",
		"node_shop_role_day1",
		"node_shop_growth_day1",
		"node_shop_skill_day1",
	]
	for node_id in required_nodes:
		ok = _expect(_has_id(nodes, node_id), "day-one Bazaar includes %s" % node_id) and ok

	var element_pool := String(state.call("_resolve_day1_shop_pool", "day1_element_dynamic", "smoke-element"))
	var trainer_pool := String(state.call("_resolve_day1_shop_pool", "day1_role_dynamic", "smoke-trainer"))
	ok = _expect(_location_has_open_type(mappings, element_pool, 1, "merchant"), "dynamic merchant route resolves to a day-one merchant location") and ok
	ok = _expect(_location_has_open_type(mappings, trainer_pool, 1, "trainer"), "dynamic trainer route resolves to a day-one trainer location") and ok
	ok = _expect(state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "night_base",
		"stallId": "merchant_aila",
		"slots": 99,
		"seedContext": "smoke-day1-aila",
	}), "can enter the formal Aila stall") and ok
	var shop_snapshot := state.snapshot()
	ok = _expect(String(Dictionary(shop_snapshot.get("active_stall", {})).get("source_stall_id", "")) == "merchant_aila", "day-one 寅将军 resolves Aila independently") and ok
	ok = _expect(Array(shop_snapshot.get("shop_offers", [])).size() == 3, "ordinary Aila stall uses three slots") and ok
	for value in Array(shop_snapshot.get("shop_offers", [])):
		ok = _expect(Array(Dictionary(value).get("source_stall_ids", [])).has("merchant_aila"), "Aila offers only contain Aila source relations") and ok

	ok = _expect(items.size() == 369, "formal runtime catalog contains exactly 369 pet goods") and ok
	ok = _expect(objects.size() == 369, "formal runtime catalog contains exactly 369 Bazaar source objects") and ok
	ok = _expect(stores.size() == 30, "formal catalog contains exactly 30 Journey locations") and ok
	ok = _expect(mappings.size() == 56, "formal catalog maps exactly 56 independent source stalls") and ok

	var store_ids := {}
	var store_candidate_counts := {}
	for value in stores:
		var store_id := String(Dictionary(value).get("id", ""))
		store_ids[store_id] = true
		store_candidate_counts[store_id] = 0

	var objects_by_pet := {}
	var source_type_counts := {}
	var package_size_counts := {}
	var package_tier_counts := {}
	var enchantments := {}
	for value in objects:
		var source := Dictionary(value)
		var pet_id := String(source.get("pet_id", ""))
		var source_type := String(source.get("source_type", ""))
		var local_shop_ids := Array(source.get("local_shop_ids", []))
		objects_by_pet[pet_id] = source
		source_type_counts[source_type] = int(source_type_counts.get(source_type, 0)) + 1
		ok = _expect(local_shop_ids.size() >= 1 and local_shop_ids.size() <= 10, "%s has between one and ten source locations" % pet_id) and ok
		ok = _expect(int(source.get("local_shop_count", -1)) == local_shop_ids.size(), "%s local shop count matches its relations" % pet_id) and ok
		ok = _expect(int(source.get("source_relation_count", -1)) == Array(source.get("source_stall_ids", [])).size(), "%s source stall count matches its relations" % pet_id) and ok
		for location_id in local_shop_ids:
			var store_id := String(location_id)
			ok = _expect(store_ids.has(store_id), "source location %s belongs to the first 30 stores" % store_id) and ok
			if store_candidate_counts.has(store_id):
				store_candidate_counts[store_id] = int(store_candidate_counts.get(store_id, 0)) + 1
		var enchantment := String(source.get("primary_enchant", ""))
		if enchantment != "":
			enchantments[enchantment] = true
		if source_type == "merchant_package":
			var source_size := String(source.get("source_size", ""))
			var source_tier := String(source.get("source_tier", ""))
			package_size_counts[source_size] = int(package_size_counts.get(source_size, 0)) + 1
			package_tier_counts[source_tier] = int(package_tier_counts.get(source_tier, 0)) + 1

	ok = _expect(int(source_type_counts.get("item", 0)) == 138, "catalog keeps 138 ordinary-item pets") and ok
	ok = _expect(int(source_type_counts.get("merchant_package", 0)) == 93, "catalog keeps 93 merchant-package pets") and ok
	ok = _expect(int(source_type_counts.get("skill", 0)) == 138, "catalog keeps 138 skill pets") and ok
	ok = _expect(int(package_size_counts.get("Large", 0)) == 30, "merchant packages include 30 large pets") and ok
	ok = _expect(int(package_size_counts.get("Medium", 0)) == 32, "merchant packages include 32 medium pets") and ok
	ok = _expect(int(package_size_counts.get("Small", 0)) == 31, "merchant packages include 31 small pets") and ok
	ok = _expect(int(package_tier_counts.get("bronze", 0)) == 30, "merchant packages include 30 bronze pets") and ok
	ok = _expect(int(package_tier_counts.get("silver", 0)) == 46, "merchant packages include 46 silver pets") and ok
	ok = _expect(int(package_tier_counts.get("gold", 0)) == 17, "merchant packages include 17 gold pets") and ok
	ok = _expect(enchantments.size() == 13, "catalog preserves all 13 primary enchantment classes") and ok

	for value in items:
		var item := Dictionary(value)
		var pet_id := String(item.get("pet_id", item.get("id", "")))
		ok = _expect(String(item.get("item_type", "")) == "宠物", "formal catalog remains pet-only") and ok
		ok = _expect(objects_by_pet.has(pet_id), "%s has a one-to-one Bazaar source object" % pet_id) and ok
		if objects_by_pet.has(pet_id):
			var source := Dictionary(objects_by_pet[pet_id])
			ok = _expect(Array(item.get("shop_pools", [])) == Array(source.get("local_shop_ids", [])), "%s runtime pools match formal source locations" % pet_id) and ok
	for value in stores:
		var store_id := String(Dictionary(value).get("id", ""))
		ok = _expect(int(store_candidate_counts.get(store_id, 0)) >= 9, "%s naturally contains at least nine pet candidates" % store_id) and ok

	var mapping_type_counts := {}
	for value in mappings:
		var mapping := Dictionary(value)
		var node_type := String(mapping.get("source_node_type", ""))
		var source_name := String(mapping.get("source_name", ""))
		mapping_type_counts[node_type] = int(mapping_type_counts.get(node_type, 0)) + 1
		ok = _expect(int(mapping.get("offer_slots", 0)) == (10 if source_name == "Curio" else 3), "%s uses its formal offer slot count" % source_name) and ok
		ok = _expect(int(mapping.get("free_rerolls", 0)) == 1, "%s provides one free reroll" % source_name) and ok
	ok = _expect(int(mapping_type_counts.get("merchant", 0)) == 41, "mapping contains 41 merchant stalls") and ok
	ok = _expect(int(mapping_type_counts.get("trainer", 0)) == 15, "mapping contains 15 trainer stalls") and ok

	var expected_open_names := {
		1: ["Aila", "Ande", "Barkun", "Curio", "Jay Jay", "Kina", "Midsworth", "Nufu", "Valpak"],
		2: ["Aila", "Ande", "Barkun", "Curio", "Jay Jay", "Midsworth", "Mittel", "Nufu", "Quixel", "Valpak"],
		3: ["Aila", "Ande", "Barkun", "Curio", "Jay Jay", "Midsworth", "Mittel", "Nufu", "Quixel", "Valpak"],
	}
	for current_day in [1, 2, 3]:
		var open_rows := _open_mappings(mappings, current_day)
		var open_names := _mapping_names(open_rows)
		open_names.sort()
		var expected_names := Array(expected_open_names[current_day]).duplicate()
		expected_names.sort()
		ok = _expect(open_rows.size() == (9 if current_day == 1 else 10), "day %d opens the formal number of stalls" % current_day) and ok
		ok = _expect(_mapping_location_count(open_rows) == open_rows.size(), "day %d keeps each open stall at an independent Journey location" % current_day) and ok
		ok = _expect(open_names == expected_names, "day %d open stall names match the source schedule" % current_day) and ok

	var first_five := [
		["night_base", "Aila", 64, 3],
		["elem_火", "Ande", 58, 3],
		["elem_水", "Barkun", 80, 3],
		["elem_草", "Curio", 31, 10],
		["elem_雷", "Jay Jay", 137, 3],
	]
	for expected in first_five:
		var mapping := _mapping_for_location_and_day(mappings, String(expected[0]), 1)
		ok = _expect(String(mapping.get("source_name", "")) == String(expected[1]), "%s day-one source is %s" % [String(expected[0]), String(expected[1])]) and ok
		ok = _expect(int(mapping.get("source_object_count", 0)) == int(expected[2]), "%s source object count is preserved" % String(expected[1])) and ok
		ok = _expect(int(mapping.get("offer_slots", 0)) == int(expected[3]), "%s slot count is preserved" % String(expected[1])) and ok

	var item_count_before := items.size()
	var store_count_before := stores.size()
	var object_count_before := objects.size()
	var mapping_count_before := mappings.size()
	var reload_result := Dictionary(ContentLoadServiceScript.new().load({
		"mode": "production",
		"contentPath": "res://data/content",
		"supplementPath": "res://data/bazaar_day1_shop_catalog.json",
	}, GameDataRepositoryScript.new()))
	ok = _expect(bool(reload_result.get("ok", false)), "public production content load succeeds") and ok
	var merged_again := Dictionary(reload_result.get("contentPack", {}))
	var merged_economy := Dictionary(merged_again.get("economy", {}))
	ok = _expect(Array(merged_economy.get("shop_items", [])).size() == item_count_before, "route supplement does not add non-pet goods") and ok
	ok = _expect(Array(merged_economy.get("shop_stores", [])).size() == store_count_before, "route supplement does not add extra stores") and ok
	ok = _expect(Array(merged_economy.get("bazaar_objects", [])).size() == object_count_before, "route supplement preserves Bazaar source objects") and ok
	ok = _expect(Array(merged_economy.get("shop_mapping", [])).size() == mapping_count_before, "route supplement preserves independent stall mappings") and ok
	var merged_nodes := Array(Dictionary(merged_again.get("route", {})).get("node_pool", []))
	for node_id in required_nodes:
		ok = _expect(_has_id(merged_nodes, node_id), "route supplement still includes %s" % node_id) and ok

	print("SMOKE_BAZAAR_DAY1_SHOP_CATEGORIES_%s merchant_location=%s trainer_location=%s objects=369 mappings=56 day_stalls=9/10/10" % [
		"OK" if ok else "FAIL",
		element_pool,
		trainer_pool,
	])
	quit(0 if ok else 1)


func _has_id(rows: Array, target_id: String) -> bool:
	for value in rows:
		if String(Dictionary(value).get("nodeId", "")) == target_id:
			return true
	return false


func _location_has_open_type(mappings: Array, location_id: String, current_day: int, node_type: String) -> bool:
	for value in _open_mappings(mappings, current_day):
		var mapping := Dictionary(value)
		if String(mapping.get("local_shop_id", "")) == location_id and String(mapping.get("source_node_type", "")) == node_type:
			return true
	return false


func _open_mappings(mappings: Array, current_day: int) -> Array:
	var rows: Array = []
	for value in mappings:
		var mapping := Dictionary(value)
		if current_day < int(mapping.get("unlock_day", 1)):
			continue
		var close_day := int(mapping.get("close_day", 0))
		if close_day > 0 and current_day > close_day:
			continue
		if String(mapping.get("day%d_status" % current_day, "")) != "开放":
			continue
		rows.append(mapping)
	return rows


func _mapping_names(mappings: Array) -> Array:
	var names: Array = []
	for value in mappings:
		names.append(String(Dictionary(value).get("source_name", "")))
	return names


func _mapping_location_count(mappings: Array) -> int:
	var location_ids := {}
	for value in mappings:
		location_ids[String(Dictionary(value).get("local_shop_id", ""))] = true
	return location_ids.size()


func _mapping_for_location_and_day(mappings: Array, location_id: String, current_day: int) -> Dictionary:
	for value in _open_mappings(mappings, current_day):
		var mapping := Dictionary(value)
		if String(mapping.get("local_shop_id", "")) == location_id:
			return mapping
	return {}


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false
