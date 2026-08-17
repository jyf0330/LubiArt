extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var _failed := false


func _init() -> void:
	var history_root := "user://deterministic_run_history_smoke"
	var state: RefCounted = _test_state()
	_expect(state.call("replace_game_data_for_test", _content_with_durable_day_fixture(Dictionary(state.get("game_data"))), &"current_assembly"), "durable history fixture binds through the test-only authority helper")
	state.call("set_run_history_root", history_root)
	_expect(state.call("enable_run_history", true), "history recording can start")
	_expect(state.dispatch({"type": "NEW_RUN", "seed": "daily-history-seed"}), "seeded run starts")
	var source_status := Dictionary(state.call("run_history_status"))
	var source_run_id := String(source_status.get("runId", ""))
	var source_content_revision := int(source_status.get("contentRevision", 0))
	var source_content_path := String(source_status.get("contentPath", ""))
	_expect(source_run_id != "", "new run receives a stable run id")
	_expect(source_content_revision > 0 and source_content_path != "", "run points to a directly addressable immutable content revision")
	_expect(
		not FileAccess.file_exists(history_root.path_join(source_run_id).path_join("content_pack.json")),
		"run directory does not duplicate the shared content pack"
	)
	_expect(state.dispatch({"type": "RUN_FULL_DAY"}), "first day completes through the public command")
	var day_one_end := _checkpoint_of_kind(Array(state.call("run_history_checkpoints", source_run_id)), 1, "end")
	_expect(not day_one_end.is_empty(), "day one end checkpoint is immutable and indexed")
	_expect(String(day_one_end.get("restoreMode", "")) == "direct_checkpoint", "day checkpoint declares direct restore instead of linear replay")
	var day_one_end_hash := String(day_one_end.get("stateHash", ""))
	_expect(state.dispatch({"type": "START_NEXT_DAY", "day": 2}), "source run enters day two")
	var source_day_two_hash := String(Dictionary(state.call("snapshot")).get("stateHash", ""))
	var day_two_start := _checkpoint_of_kind(Array(state.call("run_history_checkpoints", source_run_id)), 2, "start")
	_expect(String(day_two_start.get("stateHash", "")) == source_day_two_hash, "day two start checkpoint matches live source state")
	var repository: RefCounted = state.get("_core_composition").run_history_repository
	var source_manifest := Dictionary(repository.call("read_manifest", history_root, source_run_id))
	var source_header := Dictionary(repository.call("read_run_header", history_root, source_run_id))
	_expect(
		not source_header.is_empty()
			and not source_header.has("checkpoints")
			and FileAccess.file_exists(history_root.path_join(source_run_id).path_join("run.json")),
		"run has a fixed-size immutable header independent of its growing history manifest"
	)
	_expect(
		FileAccess.file_exists(history_root.path_join(source_run_id).path_join("day_index/day_001_end.json")),
		"day and checkpoint kind have a deterministic direct pointer file"
	)

	var drifted_content := _content_with_future_catalog_item(Dictionary(state.get("game_data")))
	var future_runtime: RefCounted = _test_state()
	future_runtime.call("set_run_history_root", history_root)
	_expect(future_runtime.call("enable_run_history", true), "future content build enables the same revision store")
	_expect(future_runtime.call("replace_game_data_for_test", drifted_content.duplicate(true), &"current_assembly"), "future content binds through the test-only authority helper")
	_expect(future_runtime.dispatch({"type": "NEW_RUN", "seed": "daily-history-seed"}), "future content build starts with the same seed")
	var future_status := Dictionary(future_runtime.call("run_history_status"))
	_expect(int(future_status.get("contentRevision", 0)) > source_content_revision, "actual content addition advances the monotonic content revision")
	_expect(String(future_status.get("contentPath", "")) != source_content_path, "new content revision has its own immutable shared pack")
	_expect(future_runtime.dispatch({"type": "RUN_FULL_DAY"}), "future content build completes day one")
	_expect(future_runtime.dispatch({"type": "START_NEXT_DAY", "day": 2}), "future content build enters day two")
	_expect(
		String(Dictionary(future_runtime.call("snapshot")).get("stateHash", "")) != source_day_two_hash,
		"adding a real selectable catalog item creates a distinct content-version state"
	)
	_expect(state.call("replace_game_data_for_test", drifted_content, &"current_assembly"), "resume probe drift binds through the test-only authority helper")
	_expect(
		repository.call(
			"_write_json_atomic",
			history_root.path_join(source_run_id).path_join("manifest.json"),
			{}
		),
		"growing manifest is removed from the direct-resume probe"
	)
	var direct_resume_ok := bool(state.call("resume_from_run_history_day", source_run_id, 1, "end"))
	_expect(
		repository.call(
			"_write_json_atomic",
			history_root.path_join(source_run_id).path_join("manifest.json"),
			source_manifest
		),
		"source manifest is restored after the direct-resume probe"
	)
	_expect(
		direct_resume_ok,
		"day pointer resumes directly even when the growing manifest is unavailable"
	)
	var branch_status := Dictionary(state.call("run_history_status"))
	var branch_run_id := String(branch_status.get("runId", ""))
	_expect(branch_run_id != "" and branch_run_id != source_run_id, "resume creates a new run branch without overwriting its parent")
	_expect(String(branch_status.get("parentRunId", "")) == source_run_id, "branch records its parent run")
	_expect(String(branch_status.get("parentCheckpointId", "")) == String(day_one_end.get("checkpointId", "")), "branch records its parent checkpoint")
	_expect(int(branch_status.get("contentRevision", 0)) == source_content_revision, "branch keeps the original content revision point")
	_expect(String(branch_status.get("contentPath", "")) == source_content_path, "branch directly reuses the original immutable content pack")
	_expect(String(Dictionary(state.call("snapshot")).get("stateHash", "")) == day_one_end_hash, "branch starts at the exact checkpoint state hash")
	_expect(not _content_has_offer(Dictionary(state.get("game_data")), "shop_future_seed_drift"), "branch removes future selectable items by restoring the source run content pack")
	_expect(state.dispatch({"type": "START_NEXT_DAY", "day": 2}), "branched run enters day two")
	_expect(String(Dictionary(state.call("snapshot")).get("stateHash", "")) == source_day_two_hash, "same command after resume produces the exact same day-two state")

	for index in range(105):
		_expect(state.dispatch({
			"type": "SET_DIFFICULTY",
			"difficulty": "easy" if index % 2 == 0 else "normal"
		}), "long history command %d is accepted" % (index + 1))
	_expect(Array(state.get("command_log")).size() > 80, "authoritative replay command stream is no longer truncated at 80 commands")
	_expect(
		Dictionary(source_manifest.get("checkpointIndex", {})).has(String(day_one_end.get("checkpointId", ""))),
		"checkpoint id has a direct manifest index"
	)
	_expect(
		String(Dictionary(source_manifest.get("dayIndex", {})).get("001:end", ""))
			== String(day_one_end.get("checkpointId", "")),
		"day and checkpoint kind have a direct time-point index"
	)
	var legacy_manifest := source_manifest.duplicate(true)
	legacy_manifest.erase("checkpointIndex")
	legacy_manifest.erase("dayIndex")
	var day_pointer_path := history_root.path_join(source_run_id).path_join("day_index/day_001_end.json")
	var day_pointer_probe_path := "%s.legacy_probe" % day_pointer_path
	_expect(
		repository.call(
			"_write_json_atomic",
			history_root.path_join(source_run_id).path_join("manifest.json"),
			legacy_manifest
		),
		"legacy manifest fixture is written"
	)
	_expect(
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(day_pointer_path),
			ProjectSettings.globalize_path(day_pointer_probe_path)
		) == OK,
		"direct day pointer is set aside for the legacy manifest probe"
	)
	_expect(
		String(Dictionary(repository.call("checkpoint_for_day", history_root, source_run_id, 1, "end")).get("checkpointId", ""))
			== String(day_one_end.get("checkpointId", "")),
		"legacy manifest without direct indices remains readable"
	)
	_expect(
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(day_pointer_probe_path),
			ProjectSettings.globalize_path(day_pointer_path)
		) == OK,
		"direct day pointer is restored after the legacy manifest probe"
	)
	_expect(
		repository.call(
			"_write_json_atomic",
			history_root.path_join(source_run_id).path_join("manifest.json"),
			source_manifest
		),
		"direct manifest index is restored after the compatibility probe"
	)
	var checkpoint_document := Dictionary(repository.call(
		"read_checkpoint",
		history_root,
		source_run_id,
		String(day_one_end.get("checkpointId", ""))
	))
	var checkpoint_file := history_root.path_join(source_run_id).path_join(String(day_one_end.get("path", "")))
	_expect(
		FileAccess.get_file_as_bytes(checkpoint_file).size()
			< JSON.stringify(checkpoint_document).to_utf8_buffer().size(),
		"direct checkpoint is stored compressed"
	)
	_expect(
		FileAccess.get_file_as_bytes(history_root.path_join(source_content_path)).size()
			< JSON.stringify(Dictionary(state.get("game_data"))).to_utf8_buffer().size(),
		"shared content revision is stored compressed"
	)
	_expect(
		repository.call("command_count",
			state.get("history_root"),
			branch_run_id
		) >= 106,
		"branch command journal remains append-only beyond 100 commands"
	)
	var replay := Dictionary(state.call("replay_document"))
	_expect(Array(replay.get("commandStream", [])).size() > 80, "exported replay keeps the complete long command stream")
	var replay_verification := Dictionary(state.call("verify_replay_document", replay))
	_expect(bool(replay_verification.get("ok", false)), "long replay verifies every checkpoint: %s" % str(replay_verification))

	var drifted_replay := replay.duplicate(true)
	drifted_replay["determinism"]["contentHash"] = "different-content"
	drifted_replay["dataVersion"] = "different-content"
	drifted_replay["checksum"] = state.call("_replay_checksum", drifted_replay)
	var drift_result := Dictionary(state.call("verify_replay_document", drifted_replay))
	_expect(String(drift_result.get("error", "")) == "REPLAY_CONTENT_VERSION_MISMATCH", "replay rejects silent content-version drift")

	var rules_drifted_replay := replay.duplicate(true)
	rules_drifted_replay["determinism"]["rulesVersion"] = "future-rules"
	rules_drifted_replay["rulesVersion"] = "future-rules"
	rules_drifted_replay["checksum"] = state.call("_replay_checksum", rules_drifted_replay)
	var rules_drift_result := Dictionary(state.call("verify_replay_document", rules_drifted_replay))
	_expect(String(rules_drift_result.get("error", "")) == "REPLAY_RULES_VERSION_MISMATCH", "replay rejects silent rules-version drift")

	var rng_drifted_replay := replay.duplicate(true)
	rng_drifted_replay["determinism"]["rngVersion"] = "future-rng"
	rng_drifted_replay["rngVersion"] = "future-rng"
	rng_drifted_replay["checksum"] = state.call("_replay_checksum", rng_drifted_replay)
	var rng_drift_result := Dictionary(state.call("verify_replay_document", rng_drifted_replay))
	_expect(String(rng_drift_result.get("error", "")) == "REPLAY_RNG_VERSION_MISMATCH", "replay rejects silent RNG-version drift")

	var runs := Array(state.call("run_history_runs"))
	_expect(runs.size() >= 2, "history index retains both parent and branch")

	if _failed:
		print("SMOKE_DETERMINISTIC_RUN_HISTORY_FAIL")
		quit(1)
		return
	print("SMOKE_DETERMINISTIC_RUN_HISTORY_OK daily_checkpoints=true branch_resume=true commands=%d" % Array(replay.get("commandStream", [])).size())
	quit()


func _test_state() -> RefCounted:
	var production: RefCounted = StateScript.new()
	return StateScript.new({
		"mode": "test",
		"content_pack": Dictionary(production.get("game_data")).duplicate(true),
		"content_source_kind": production.call("content_source_kind"),
	})


func _checkpoint_of_kind(checkpoints: Array, expected_day: int, kind: String) -> Dictionary:
	for value in checkpoints:
		var item := Dictionary(value)
		if int(item.get("day", 0)) == expected_day and String(item.get("kind", "")) == kind:
			return item
	return {}


func _content_with_future_catalog_item(source: Dictionary) -> Dictionary:
	var content := source.duplicate(true)
	var offers := Array(content.get("shop_offers", [])).duplicate(true)
	var future_offer := Dictionary(offers[0]).duplicate(true) if not offers.is_empty() else {}
	future_offer["id"] = "shop_future_seed_drift"
	future_offer["offer_id"] = "shop_future_seed_drift"
	future_offer["pet_id"] = "pal_future_seed_drift"
	future_offer["name"] = "未来新增候选"
	future_offer["status"] = "启用"
	future_offer["unlock_day"] = 1
	future_offer["pool_id"] = "night_base"
	future_offer["shop_pools"] = ["night_base"]
	future_offer["weights"] = {"night": 999999}
	offers.push_front(future_offer)
	content["shop_offers"] = offers
	return content


func _content_with_durable_day_fixture(source: Dictionary) -> Dictionary:
	var content := source.duplicate(true)
	var player := Dictionary(content.get("player", {})).duplicate(true)
	player["hero_hp"] = 10000.0
	player["heroMaxHp"] = 10000.0
	content["player"] = player
	var roster := Array(content.get("roster", [])).duplicate(true)
	if not roster.is_empty():
		var first_pet := Dictionary(roster[0]).duplicate(true)
		first_pet["max_hp"] = 10000.0
		first_pet["atk"] = 10000.0
		first_pet["shield"] = 10000.0
		var base_stats := Dictionary(first_pet.get("base_stats", {})).duplicate(true)
		base_stats["max_hp"] = 10000.0
		base_stats["atk"] = 10000.0
		base_stats["starting_shield"] = 10000.0
		first_pet["base_stats"] = base_stats
		roster[0] = first_pet
	content["roster"] = roster
	return content


func _content_has_offer(content: Dictionary, offer_id: String) -> bool:
	for value in Array(content.get("shop_offers", [])):
		var offer := Dictionary(value)
		if String(offer.get("offer_id", offer.get("id", ""))) == offer_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_DETERMINISTIC_RUN_HISTORY_FAIL: %s" % message)
