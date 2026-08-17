extends SceneTree

const BootstrapScript := preload("res://core/startup/default_timepoint_three_save_bootstrap.gd")
const SessionFactoryScript := preload("res://session/session_factory.gd")
const GameScene := preload("res://art/scenes/app/game.tscn")

const DEFAULT_RUN_SEED := "ysbzs-test-play-20260715-v1"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var creation := Dictionary(SessionFactoryScript.create_local_result({
		"run_seed": DEFAULT_RUN_SEED,
		"run_history": false,
	}))
	if not bool(creation.get("ok", false)):
		_fail("startup fixture session creation failed: %s" % JSON.stringify(creation))
		return
	var session := creation.get("session") as RefCounted
	var result := Dictionary(BootstrapScript.prepare_and_load(session, DEFAULT_RUN_SEED))
	if not bool(result.get("ok", false)):
		_fail("startup fixture generation failed: %s" % JSON.stringify(result))
		return
	var snapshot := Dictionary(session.call("current_snapshot"))
	var validation := Dictionary(BootstrapScript.validate_snapshot(snapshot, DEFAULT_RUN_SEED))
	if not bool(validation.get("ok", false)):
		_fail("generated snapshot failed validation: %s" % JSON.stringify(validation))
		return
	if Array(result.get("purchased_offer_ids", [])).size() != BootstrapScript.PURCHASE_COUNT:
		_fail("startup fixture did not report four purchased offers")
		return

	var restore_creation := Dictionary(SessionFactoryScript.create_local_result({
		"run_seed": "startup-restore-probe",
		"run_history": false,
	}))
	if not bool(restore_creation.get("ok", false)):
		_fail("restore probe session creation failed")
		return
	var restored_session := restore_creation.get("session") as RefCounted
	if not bool(restored_session.call("load_from_slot", BootstrapScript.DEFAULT_SAVE_SLOT)):
		_fail("slot 3 could not be loaded by a fresh session")
		return
	var restored_snapshot := Dictionary(restored_session.call("current_snapshot"))
	var restored_validation := Dictionary(BootstrapScript.validate_snapshot(restored_snapshot, DEFAULT_RUN_SEED))
	if not bool(restored_validation.get("ok", false)):
		_fail("restored slot 3 failed validation: %s" % JSON.stringify(restored_validation))
		return
	if String(restored_snapshot.get("stateHash", "")) != String(snapshot.get("stateHash", "")):
		_fail("slot 3 load changed the authoritative state hash")
		return

	var game := GameScene.instantiate()
	if bool(game.call("_should_prepare_direct_startup_save")):
		_fail("normal project startup must not opt into the timepoint-three save")
		return
	if not bool(game.call(
		"_should_prepare_direct_startup_save",
		PackedStringArray(["--startup-save=timepoint-three"])
	)):
		_fail("explicit startup-save argument must keep the timepoint-three fixture available")
		return
	game.call("set_game_session", restored_session)
	root.add_child(game)
	await process_frame
	await process_frame
	if String(game.state.snapshot().get("phase", "")) != "battle":
		_fail("Game did not mount from the loaded battle snapshot")
		return
	if StringName(game.call("get_active_feature_id")) != &"battle":
		_fail("Game did not mount the formal battle feature from slot 3")
		return

	var facts := Dictionary(validation.get("facts", {}))
	print(
		"SMOKE_STARTUP_TIMEPOINT_THREE_SAVE_OK slot=3 seed=%s purchases=%d roster=%d active=%d hash=%s" % [
			DEFAULT_RUN_SEED,
			int(facts.get("purchase_count", 0)),
			int(facts.get("roster_count", 0)),
			int(facts.get("active_player_pet_count", 0)),
			String(snapshot.get("stateHash", "")),
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
