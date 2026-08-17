extends SceneTree

const ATTACK_TIMELINE_SCENE := preload("res://art/prefabs/battle/hud/attack_timeline.tscn")

var _failed := false
var _commands: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var timeline := ATTACK_TIMELINE_SCENE.instantiate()
	root.add_child(timeline)
	timeline.command_requested.connect(_on_command_requested)
	await process_frame
	await process_frame
	timeline.call("render_snapshot", _snapshot_fixture())
	await process_frame
	_expect(int(timeline.call("debug_marker_count")) == 8, "timeline projects all four pets' A/B entries")
	for marker in timeline.get_node("TimelineArea/MarkerLayer").get_children():
		if not marker.visible:
			continue
		var pet := marker.get_node("PetFrame/Pet") as TextureRect
		_expect(pet.visible and pet.texture != null, "timeline keeps an authored fallback portrait for unmapped formal pets")
	_expect(
		Array(timeline.call("debug_order_ids")) == [
			"pet_1:a", "pet_1:b", "pet_2:a", "pet_2:b",
			"pet_3:a", "pet_3:b", "pet_4:a", "pet_4:b",
		],
		"timeline keeps the authoritative stable entry ids"
	)
	_expect(bool(timeline.call("debug_set_marker_position", "pet_4:b", 0.0)), "last entry can move to the front")
	_expect(bool(timeline.call("debug_set_marker_position", "pet_1:a", 1.0)), "first entry can move to the end")
	timeline.call("debug_commit_order")
	_expect(_commands.size() == 1, "one drag completion emits one intent")
	if _commands.size() == 1:
		var command := _commands[0]
		_expect(String(command.get("type", "")) == "SET_SKILL_CONTROL_ORDER", "intent uses the public reorder command")
		_expect(command.keys().size() == 2, "intent carries no Session or authority metadata")
		_expect(Array(command.get("orderedEntryIds", [])).front() == "pet_4:b", "intent preserves the reordered stable id")
		_expect(Array(command.get("orderedEntryIds", [])).back() == "pet_1:a", "intent preserves the reordered final id")
	timeline.call("set_interaction_locked", true)
	_expect((timeline.get_node("PlayButton") as Button).disabled, "trace lock disables timeline playback")
	_expect((timeline.get_node("ResetButton") as Button).disabled, "trace lock disables timeline reset")
	_finish()


func _snapshot_fixture() -> Dictionary:
	var units: Array = []
	var control_bar: Array = []
	for pet_index in range(4):
		var unit_id := "pet_%d" % (pet_index + 1)
		var unit_name := "测试宠物%d" % (pet_index + 1)
		units.append({
			"id": unit_id,
			"pet_id": ["pal_002", "pal_011", "pal_030", "pal_099"][pet_index],
			"name": unit_name,
			"side": "player",
		})
		for skill_slot in ["a", "b"]:
			control_bar.append({
				"entryId": "%s:%s" % [unit_id, skill_slot],
				"unitId": unit_id,
				"unitName": unit_name,
				"skillSlot": skill_slot,
				"skillId": "skill_%s" % skill_slot,
				"label": "技能%s" % skill_slot.to_upper(),
			})
	return {
		"phase": "battle",
		"units": units,
		"skillControlBar": control_bar,
	}


func _on_command_requested(command: Dictionary) -> void:
	_commands.append(command.duplicate(true))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_BATTLE_ATTACK_TIMELINE_FAIL %s" % message)


func _finish() -> void:
	if not _failed:
		print("SMOKE_BATTLE_ATTACK_TIMELINE_OK")
	quit(1 if _failed else 0)
