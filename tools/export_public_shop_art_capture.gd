extends SceneTree

## Exports a deterministic, public shop presentation flow for the independent
## art workspace. This file never serializes the authority object, saves,
## catalog sources, or implementation code; only public Session results and
## Snapshots cross the boundary.

const SessionFactoryScript := preload("res://session/session_factory.gd")

const RUN_SEED := "shop-art-roundtrip-v1"
const PREFERRED_SHOP_OPTION_ID := "node_shop_basic"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := _output_path()
	if output_path == "":
		_fail("pass --output=<absolute path>", 2)
		return

	var creation := Dictionary(SessionFactoryScript.create_local_result({
		"run_seed": RUN_SEED,
		"command_scope": "developer",
	}))
	if not bool(creation.get("ok", false)):
		_fail("LocalGameSession initialization failed: %s" % JSON.stringify(creation.get("initialization", {})), 3)
		return
	var session := creation.get("session") as RefCounted
	if session == null or not bool(session.call("connect_session")):
		_fail("LocalGameSession is unavailable", 3)
		return

	var route_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	if String(route_snapshot.get("phase", "")) != "route":
		_fail("new public Session did not start on route", 4)
		return
	var route_options := Array(route_snapshot.get("route_options", []))
	for value in route_options:
		var route_option := Dictionary(value)
		print("PUBLIC_SHOP_ART_CAPTURE_ROUTE id=%s kind=%s pool=%s source=%s" % [
			String(route_option.get("id", "")),
			String(route_option.get("kind", route_option.get("nodeType", ""))),
			String(route_option.get("shopPoolId", route_option.get("shop_pool_id", ""))),
			String(Dictionary(route_option.get("sourceNode", {})).get("id", "")),
		])
	var selected_option := _select_shop_option(route_options)
	if selected_option.is_empty():
		_fail("public route Snapshot has no shop option", 4)
		return
	var option_id := String(selected_option.get("id", selected_option.get("option_id", "")))
	var entry := _submit(session, {
		"type": "CHOOSE_ROUTE",
		"option_id": option_id,
	})
	if not bool(entry.get("accepted", false)):
		_fail("CHOOSE_ROUTE rejected: %s" % JSON.stringify(entry), 5)
		return
	var shop_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	if String(shop_snapshot.get("phase", "")) != "shop":
		_fail("CHOOSE_ROUTE did not enter shop", 5)
		return
	var initial_offers := Array(shop_snapshot.get("shop_offers", []))
	print("PUBLIC_SHOP_ART_CAPTURE_SHOP option=%s offers=%d stall=%s pool=%s" % [
		option_id,
		initial_offers.size(),
		String(Dictionary(shop_snapshot.get("active_stall", {})).get("id", "")),
		String(shop_snapshot.get("active_shop_pool", "")),
	])
	if initial_offers.size() < 3:
		_fail("shop Snapshot must expose at least three offers", 6)
		return

	var roll := _submit(session, {"type": "ROLL_SHOP"})
	if not bool(roll.get("accepted", false)):
		_fail("ROLL_SHOP rejected: %s" % JSON.stringify(roll), 7)
		return
	var refreshed_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	var refreshed_offers := Array(refreshed_snapshot.get("shop_offers", []))
	if refreshed_offers.is_empty():
		_fail("refreshed shop has no offers", 7)
		return
	var purchase_offer := Dictionary(refreshed_offers[0])
	var purchase := _submit(session, {
		"type": "BUY_OFFER",
		"offer_id": String(purchase_offer.get("id", "")),
	})
	if not bool(purchase.get("accepted", false)):
		_fail("BUY_OFFER rejected: %s" % JSON.stringify(purchase), 8)
		return
	var purchased_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)

	var second_offer := Dictionary(refreshed_offers[1])
	var second_purchase := _submit(session, {
		"type": "BUY_OFFER",
		"offer_id": String(second_offer.get("id", "")),
	})
	if not bool(second_purchase.get("accepted", false)):
		_fail("second BUY_OFFER rejected: %s" % JSON.stringify(second_purchase), 8)
		return
	var second_purchased_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)

	var third_offer := Dictionary(refreshed_offers[2])
	var third_purchase := _submit(session, {
		"type": "BUY_OFFER",
		"offer_id": String(third_offer.get("id", "")),
	})
	if not bool(third_purchase.get("accepted", false)):
		_fail("third BUY_OFFER rejected: %s" % JSON.stringify(third_purchase), 8)
		return
	var party_full_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	if _active_roster_count(party_full_snapshot) != 4:
		_fail("three purchases did not produce four active roster records", 8)
		return

	var paid_roll := _submit(session, {"type": "ROLL_SHOP"})
	if not bool(paid_roll.get("accepted", false)):
		_fail("paid ROLL_SHOP rejected: %s" % JSON.stringify(paid_roll), 8)
		return
	var paid_refreshed_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	var paid_refreshed_offers := Array(paid_refreshed_snapshot.get("shop_offers", []))
	if paid_refreshed_offers.is_empty():
		_fail("paid refresh has no offers", 8)
		return
	var bag_offer := Dictionary(paid_refreshed_offers[0])
	var bag_purchase := _submit(session, {
		"type": "BUY_OFFER",
		"offer_id": String(bag_offer.get("id", "")),
	})
	if not bool(bag_purchase.get("accepted", false)):
		_fail("bag BUY_OFFER rejected: %s" % JSON.stringify(bag_purchase), 8)
		return
	var bag_purchased_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	if _active_roster_count(bag_purchased_snapshot) != 4 \
			or _inactive_roster_count(bag_purchased_snapshot) != 1:
		_fail("fifth purchase did not produce four active and one inactive roster records", 8)
		return

	var exit := _submit(session, {"type": "EXIT_SHOP"})
	if not bool(exit.get("accepted", false)):
		_fail("EXIT_SHOP rejected: %s" % JSON.stringify(exit), 9)
		return
	var exit_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	if String(exit_snapshot.get("phase", "")) != "route":
		_fail("EXIT_SHOP did not return to route", 9)
		return

	var reentry := _submit(session, {
		"type": "CHOOSE_ROUTE",
		"option_id": option_id,
	})
	if not bool(reentry.get("accepted", false)):
		_fail("second CHOOSE_ROUTE rejected: %s" % JSON.stringify(reentry), 9)
		return
	var reentered_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	if String(reentered_snapshot.get("phase", "")) != "shop":
		_fail("second CHOOSE_ROUTE did not re-enter shop", 9)
		return

	var capture := {
		"schema": "ysbzs.public-shop-art-capture.v1",
		"source": {
			"project": "godot-latest",
			"session": "LocalGameSession",
			"snapshot_method": "current_snapshot",
			"run_seed": RUN_SEED,
			"selected_option_id": option_id,
			"display_only": true,
			"authority_object_exported": false,
			"save_data_exported": false,
		},
		"route_snapshot": route_snapshot,
		"shop_snapshot": shop_snapshot,
		"refreshed_snapshot": refreshed_snapshot,
		"purchased_snapshot": purchased_snapshot,
		"second_purchased_snapshot": second_purchased_snapshot,
		"party_full_snapshot": party_full_snapshot,
		"paid_refreshed_snapshot": paid_refreshed_snapshot,
		"bag_purchased_snapshot": bag_purchased_snapshot,
		"exit_snapshot": exit_snapshot,
		"reentered_snapshot": reentered_snapshot,
		"replay_snapshots": {
			"shop_snapshot": shop_snapshot,
			"refreshed_snapshot": refreshed_snapshot,
			"purchased_snapshot": purchased_snapshot,
			"second_purchased_snapshot": second_purchased_snapshot,
			"party_full_snapshot": party_full_snapshot,
			"paid_refreshed_snapshot": paid_refreshed_snapshot,
			"bag_purchased_snapshot": bag_purchased_snapshot,
			"exit_snapshot": exit_snapshot,
			"reentered_snapshot": reentered_snapshot,
		},
		"operations": [
			_operation_record("enter_shop", "shop_snapshot", {"type": "CHOOSE_ROUTE", "option_id": option_id}, entry, shop_snapshot),
			_operation_record("refresh_shop", "refreshed_snapshot", {"type": "ROLL_SHOP"}, roll, refreshed_snapshot),
			_operation_record("purchase_offer", "purchased_snapshot", {"type": "BUY_OFFER", "offer_id": String(purchase_offer.get("id", ""))}, purchase, purchased_snapshot),
			_operation_record("purchase_second_offer", "second_purchased_snapshot", {"type": "BUY_OFFER", "offer_id": String(second_offer.get("id", ""))}, second_purchase, second_purchased_snapshot),
			_operation_record("purchase_third_offer", "party_full_snapshot", {"type": "BUY_OFFER", "offer_id": String(third_offer.get("id", ""))}, third_purchase, party_full_snapshot),
			_operation_record("paid_refresh_shop", "paid_refreshed_snapshot", {"type": "ROLL_SHOP"}, paid_roll, paid_refreshed_snapshot),
			_operation_record("purchase_bag_offer", "bag_purchased_snapshot", {"type": "BUY_OFFER", "offer_id": String(bag_offer.get("id", ""))}, bag_purchase, bag_purchased_snapshot),
			_operation_record("exit_shop", "exit_snapshot", {"type": "EXIT_SHOP"}, exit, exit_snapshot),
			_operation_record("reenter_shop_after_exit", "reentered_snapshot", {"type": "CHOOSE_ROUTE", "option_id": option_id}, reentry, reentered_snapshot),
		],
	}
	if not _write_json(output_path, capture):
		_fail("could not write %s" % output_path, 10)
		return
	print("PUBLIC_SHOP_ART_CAPTURE_OK output=%s option=%s offers=%d refreshed=%d purchased=%s bag_purchase=%s roster=%d reentered=%s" % [
		output_path,
		option_id,
		initial_offers.size(),
		refreshed_offers.size(),
		String(purchase_offer.get("id", "")),
		String(bag_offer.get("id", "")),
		Array(bag_purchased_snapshot.get("roster", [])).size(),
		String(reentered_snapshot.get("phase", "")),
	])
	quit(0)


func _select_shop_option(options: Array) -> Dictionary:
	var first_shop: Dictionary = {}
	for value in options:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var option := Dictionary(value)
		if String(option.get("kind", option.get("nodeType", ""))) != "shop":
			continue
		if first_shop.is_empty():
			first_shop = option.duplicate(true)
		var option_id := String(option.get("id", option.get("option_id", "")))
		if option_id == PREFERRED_SHOP_OPTION_ID:
			return option.duplicate(true)
	return first_shop


func _submit(session: RefCounted, command: Dictionary) -> Dictionary:
	return Dictionary(session.call("submit_command", command.duplicate(true))).duplicate(true)


func _operation_record(
	name: String,
	snapshot_key: String,
	command: Dictionary,
	response: Dictionary,
	snapshot: Dictionary
) -> Dictionary:
	return {
		"name": name,
		"snapshot_key": snapshot_key,
		"command": command.duplicate(true),
		"response": {
			"accepted": bool(response.get("accepted", false)),
			"status": String(response.get("status", "")),
			"stateVersion": int(response.get("stateVersion", -1)),
			"stateHash": String(response.get("stateHash", "")),
			"result": Dictionary(response.get("result", {})).duplicate(true),
		},
		"snapshot_identity": {
			"phase": String(snapshot.get("phase", "")),
			"stateVersion": int(snapshot.get("stateVersion", -1)),
			"stateHash": String(snapshot.get("stateHash", "")),
			"coins": int(snapshot.get("coins", 0)),
			"offer_count": Array(snapshot.get("shop_offers", [])).size(),
			"roster_count": Array(snapshot.get("roster", [])).size(),
		},
	}


func _active_roster_count(snapshot: Dictionary) -> int:
	var count := 0
	for value in Array(snapshot.get("roster", [])):
		if value is Dictionary and bool(Dictionary(value).get("active", false)):
			count += 1
	return count


func _inactive_roster_count(snapshot: Dictionary) -> int:
	var count := 0
	for value in Array(snapshot.get("roster", [])):
		if value is Dictionary and not bool(Dictionary(value).get("active", false)):
			count += 1
	return count


func _output_path() -> String:
	for arg_value in OS.get_cmdline_user_args():
		var arg := String(arg_value)
		if arg.begins_with("--output="):
			return arg.trim_prefix("--output=").strip_edges()
	return ""


func _write_json(path: String, value: Dictionary) -> bool:
	var parent := path.get_base_dir()
	if parent != "" and DirAccess.make_dir_recursive_absolute(parent) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "", false) + "\n")
	file.close()
	return true


func _fail(message: String, code: int) -> void:
	push_error("PUBLIC_SHOP_ART_CAPTURE_FAIL: %s" % message)
	quit(code)
