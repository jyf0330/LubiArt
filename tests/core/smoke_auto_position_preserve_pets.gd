extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	var state := StateScript.new()
	state.roster = [
		_pet("pal_002", "pal_002", "捣蛋猫", 1, 24, 5),
		_pet("shop_002", "pal_009", "燎火鹿", 2, 24, 4),
		_pet("shop_004", "pal_013", "叶泥泥", 3, 20, 3),
		_pet("shop_001", "pal_005", "火绒狐", 4, 35, 5)
	]
	state.start_battle()
	var identity_before := _player_identity_signature(state)
	var count_before := identity_before.size()
	_expect(count_before == 4, "save-slot-shaped fixture deploys four player pets")
	var positions_before := _player_positions(state)
	var player_ids := positions_before.keys()
	var shared_target := Vector2i(4, 4)
	var invalid_plan := {
		String(player_ids[0]): {"unitId": String(player_ids[0]), "to": {"x": shared_target.x, "y": shared_target.y}},
		String(player_ids[1]): {"unitId": String(player_ids[1]), "to": {"x": shared_target.x, "y": shared_target.y}}
	}
	var invalid_result := Dictionary(state.call("_apply_auto_position_moves_atomically", invalid_plan))
	_expect(not bool(invalid_result.get("ok", true)), "overlapping multi-pet placement is rejected atomically")
	_expect(_player_positions(state) == positions_before, "rejected placement preserves every original pet position")

	_expect(state.auto_position_heroes(), "real auto-position command succeeds")
	var identity_after := _player_identity_signature(state)
	_expect(identity_after == identity_before, "auto-position preserves all four instance ids and pet ids")
	_expect(identity_after.size() == count_before, "auto-position preserves the living player pet count")
	_expect(_player_positions_are_unique(state), "auto-position leaves every living unit on a unique legal cell")
	_expect(_projected_player_pet_ids(state) == ["pal_002", "pal_005", "pal_009", "pal_013"], "board projection keeps the four saved pet identities")

	if failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_PRESERVE_PETS_OK pets=%s" % JSON.stringify(identity_after))
	quit(0)


func _pet(instance_id: String, pet_id: String, display_name: String, slot: int, hp: int, atk: int) -> Dictionary:
	return {
		"id": instance_id,
		"pet_id": pet_id,
		"name": display_name,
		"element": "火",
		"role": "输出",
		"quality": "青铜",
		"max_hp": hp,
		"hp": hp,
		"atk": atk,
		"def": 0,
		"shield": 0,
		"ap": 3,
		"skill": "",
		"shape": "",
		"range": "",
		"active": true,
		"slot": slot,
		"bag_slot": 0,
		"mechanics": []
	}


func _player_identity_signature(state) -> Array[String]:
	var signature: Array[String] = []
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and int(unit.get("hp", 0)) > 0:
			signature.append("%s|%s" % [String(unit.get("id", "")), String(unit.get("pet_id", ""))])
	signature.sort()
	return signature


func _player_positions(state) -> Dictionary:
	var positions := {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and int(unit.get("hp", 0)) > 0:
			positions[String(unit.get("id", ""))] = Vector2i(int(unit.get("x", -1)), int(unit.get("y", -1)))
	return positions


func _player_positions_are_unique(state) -> bool:
	var occupied := {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if int(unit.get("hp", 0)) <= 0:
			continue
		var key := "%d,%d" % [int(unit.get("x", -1)), int(unit.get("y", -1))]
		if occupied.has(key):
			return false
		occupied[key] = true
	return true


func _projected_player_pet_ids(state) -> Array[String]:
	var pet_ids: Array[String] = []
	for cell_value in Array(Dictionary(state.snapshot().get("board", {})).get("cells", [])):
		var cell := Dictionary(cell_value)
		if String(cell.get("side", "")) == StateScript.PLAYER:
			pet_ids.append(String(cell.get("pet_id", "")))
	pet_ids.sort()
	return pet_ids


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_AUTO_POSITION_PRESERVE_PETS_FAIL: %s" % message)
