extends SceneTree

const GAME_SCENE := preload("res://art/scenes/app/game.tscn")
const FEATURE_REGISTRY := preload("res://core_ui/scripts/app/feature_registry.gd")
const GAME_SESSION := preload("res://session/game_session.gd")

var _failed := false


class FakeSaveSession extends GAME_SESSION:
	var projected_snapshot: Dictionary
	var saved_slots: Array[int] = []
	var loaded_slots: Array[int] = []

	func _init(snapshot: Dictionary) -> void:
		projected_snapshot = snapshot.duplicate(true)

	func supports_persistence() -> bool:
		return true

	func persistence_slot_count() -> int:
		return 3

	func save_to_slot(slot: int = 1) -> bool:
		saved_slots.append(slot)
		return true

	func load_from_slot(slot: int = 1) -> bool:
		loaded_slots.append(slot)
		return true

	func current_snapshot() -> Dictionary:
		return projected_snapshot.duplicate(true)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame

	_expect(
		game.get_node_or_null("GlobalSettingsMenu") == null,
		"route startup does not mount the global save/load menu"
	)
	var real_session := game.call("get_game_session") as RefCounted
	var fake_session := FakeSaveSession.new(Dictionary(real_session.call("current_snapshot")))
	game.call("set_game_session", fake_session)
	await process_frame
	await _press_j()
	var route_view := game.get_node("ThreeChoiceScene") as Control
	var run_tools := route_view.get_node_or_null("RunTools") as Control
	_expect(run_tools != null and run_tools.visible, "J opens the code-generated quick save/load toolbar")
	var save_slot_2 := run_tools.find_child("SaveSlot2Button", true, false) as Button
	var load_slot_3 := run_tools.find_child("LoadSlot3Button", true, false) as Button
	_expect(save_slot_2 != null and load_slot_3 != null, "quick toolbar exposes all configured save slots")
	if save_slot_2 != null:
		save_slot_2.pressed.emit()
	await process_frame
	_expect(fake_session.saved_slots == [2], "quick toolbar delegates save slot 2 through GameSession")
	if load_slot_3 != null:
		load_slot_3.pressed.emit()
	await process_frame
	_expect(fake_session.loaded_slots == [3], "quick toolbar delegates load slot 3 through GameSession")
	_expect(game.get_node_or_null("GlobalSettingsMenu") == null, "J does not mount the formal save/load menu")
	await _press_j()
	await process_frame
	_expect(
		run_tools != null and not run_tools.visible,
		"second J hides the quick save/load toolbar"
	)

	var mounted := game.call("mount_feature", FEATURE_REGISTRY.BATTLE_FEATURE) as Control
	await process_frame
	await process_frame
	var battle := game.call("get_active_feature_view") as Control
	_expect(battle == mounted and battle != null, "fixture mounts battle through the Game-owned feature router")
	var battle_menu := battle.get_node_or_null("OverlayHost/SettingsMenu") as Control if battle != null else null
	_expect(battle_menu != null and not battle_menu.visible, "battle menu is hidden by default")

	await _press_j()
	_expect(run_tools != null and run_tools.visible, "battle J opens the same quick save/load toolbar")
	_expect(
		battle_menu != null and not battle_menu.visible,
		"battle J leaves the authored settings menu closed"
	)
	await _press_j()
	_expect(run_tools != null and not run_tools.visible, "second battle J hides the quick toolbar")

	game.queue_free()
	await process_frame
	if not _failed:
		print("SMOKE_GLOBAL_SAVE_LOAD_HOTKEY_OK")
	quit(1 if _failed else 0)


func _press_j() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_J
	press.physical_keycode = KEY_J
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_J
	release.physical_keycode = KEY_J
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_GLOBAL_SAVE_LOAD_HOTKEY_FAIL: %s" % message)
