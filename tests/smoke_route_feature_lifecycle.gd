extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")

var _failed := false


class RoutingSession:
	extends RefCounted

	signal snapshot_received(snapshot: Dictionary, metadata: Dictionary)

	var _route_snapshot: Dictionary
	var _battle_snapshot: Dictionary
	var _snapshot: Dictionary


	func _init(route_snapshot: Dictionary, battle_snapshot: Dictionary) -> void:
		_route_snapshot = route_snapshot.duplicate(true)
		_battle_snapshot = battle_snapshot.duplicate(true)
		_snapshot = _route_snapshot.duplicate(true)


	func current_snapshot() -> Dictionary:
		return _snapshot.duplicate(true)


	func submit_command_and_wait(command: Dictionary) -> Dictionary:
		match String(command.get("type", "")):
			"TEST_ENTER_BATTLE":
				_snapshot = _battle_snapshot.duplicate(true)
			"TEST_LEAVE_BATTLE":
				_snapshot = _route_snapshot.duplicate(true)
		return {
			"accepted": true,
			"command": String(command.get("type", "")),
			"snapshot": current_snapshot(),
		}


	func supports_persistence() -> bool:
		return false


	func persistence_slot_count() -> int:
		return 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_snapshot := Dictionary(MockSession.new({"start_phase": "route"}).current_snapshot())
	var battle_snapshot := Dictionary(MockSession.new({"start_phase": "battle"}).current_snapshot())
	var game := GameScene.instantiate() as Control
	game.call("set_game_session", RoutingSession.new(route_snapshot, battle_snapshot))
	root.add_child(game)
	await _settle(8)
	var route_view := game.call("get_three_choice_view") as Control
	_expect(route_view != null and route_view.visible, "route view starts visible")
	_expect(game.call("get_active_feature_view") == null, "route starts without a mounted feature")
	route_view.command_requested.emit({"type": "TEST_ENTER_BATTLE"}, 9001)
	await _settle(8)
	var battle_view := game.call("get_active_feature_view") as Control
	_expect(StringName(game.call("get_active_feature_id")) == &"battle", "Game mounts BattleArtScene in FeatureHost")
	_expect(battle_view != null and battle_view.visible, "mounted battle view is visible")
	_expect(not route_view.visible, "route view is hidden while battle owns the feature surface")
	if battle_view != null:
		battle_view.command_requested.emit({"type": "TEST_LEAVE_BATTLE"})
	await _settle(8)
	_expect(game.call("get_active_feature_view") == null, "Game releases BattleArtScene after the returned route Snapshot")
	_expect(route_view.visible, "Game restores ThreeChoiceScene directly after battle")
	_expect(not route_view.has_method("attach_feature_view") and not route_view.has_method("render_battle_command_response"), "ThreeChoiceScene owns no BattleArtScene lifecycle")
	game.queue_free()
	await process_frame
	print("SMOKE_ROUTE_FEATURE_LIFECYCLE_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_ROUTE_FEATURE_LIFECYCLE_FAIL: %s" % message)
