extends SceneTree

const StateScript: Script = preload("res://core/state/game_state.gd")

const LEGACY_SAVE_PATH := "user://ysbzs_singleplayer_save.json"
const LEGACY_SAVE_BACKUP_PATH := "user://ysbzs_singleplayer_save.bak.json"
const SAVE_PATH_PATTERN := "user://ysbzs_singleplayer_save_slot_%d.json"
const SAVE_BACKUP_PATH_PATTERN := "user://ysbzs_singleplayer_save_slot_%d.bak.json"
const SAVE_TEMP_PATH_PATTERN := "user://ysbzs_singleplayer_save_slot_%d.tmp.json"

func _init() -> void:
	var ok := true
	_cleanup_save_files()

	var shop_state: RefCounted = StateScript.new()
	ok = ok and _expect(shop_state.dispatch({"type": "ENTER_SHOP", "poolId": "night_base", "slots": 3}), "fixture can enter shop")
	ok = ok and _expect(shop_state.save_to_user(1), "first save writes slot 1 primary")
	var shop_doc := _read_save_doc(_save_path(1))
	ok = ok and _expect(Dictionary(shop_doc.get("summary", {})).get("phase", "") == "shop", "save document exposes summary phase")
	ok = ok and _expect(String(shop_doc.get("summaryText", "")).contains("商店"), "save document exposes readable summary text")

	var battle_state: RefCounted = StateScript.new()
	ok = ok and _expect(battle_state.dispatch({"type": "START_BATTLE"}), "fixture can enter battle")
	ok = ok and _expect(battle_state.save_to_user(1), "second save writes slot 1 primary")
	ok = ok and _expect(FileAccess.file_exists(_backup_path(1)), "second slot 1 save keeps previous primary as backup")
	ok = ok and _expect(not FileAccess.file_exists(_temp_path(1)), "atomic save leaves no slot 1 temp file")
	var primary_doc := _read_save_doc(_save_path(1))
	var backup_doc := _read_save_doc(_backup_path(1))
	ok = ok and _expect(Dictionary(primary_doc.get("summary", {})).get("phase", "") == "battle", "primary is latest battle save")
	ok = ok and _expect(Dictionary(backup_doc.get("summary", {})).get("phase", "") == "shop", "backup is previous shop save")

	_write_text(_save_path(1), "{ broken json")
	var fallback_state: RefCounted = StateScript.new()
	ok = ok and _expect(fallback_state.load_from_user(1), "slot 1 load falls back to backup when primary is corrupt")
	ok = ok and _expect(String(fallback_state.snapshot().get("phase", "")) == "shop", "backup restore uses previous shop phase")
	ok = ok and _expect(_log_contains(Array(fallback_state.snapshot().get("log_lines", [])), "备份"), "fallback load reports backup usage")

	var tampered: Dictionary = battle_state.save_document()
	var tampered_state := Dictionary(tampered.get("state", {}))
	tampered_state["phase"] = "not_a_real_phase"
	tampered["state"] = tampered_state
	tampered["checksum"] = battle_state.call("_save_checksum", tampered)
	var reject_state: RefCounted = StateScript.new()
	ok = ok and _expect(not reject_state.load_document(tampered), "load rejects checksum-valid impossible phase")

	var slot_two_state: RefCounted = StateScript.new()
	ok = ok and _expect(slot_two_state.dispatch({"type": "ENTER_SHOP", "poolId": "night_base", "slots": 3}), "slot 2 fixture can enter shop")
	ok = ok and _expect(slot_two_state.save_to_user(2), "slot 2 writes independently")
	var slot_three_state: RefCounted = StateScript.new()
	ok = ok and _expect(slot_three_state.save_to_user(3), "slot 3 writes independently")
	ok = ok and _expect(Dictionary(_read_save_doc(_save_path(2)).get("summary", {})).get("phase", "") == "shop", "slot 2 keeps its shop progress")
	ok = ok and _expect(FileAccess.file_exists(_save_path(3)), "slot 3 primary exists")
	ok = ok and _expect(not slot_three_state.save_to_user(4), "out-of-range slot is rejected")

	for path in [_save_path(1), _backup_path(1), _temp_path(1)]:
		_remove_path(path)
	_write_text(LEGACY_SAVE_PATH, JSON.stringify(shop_state.save_document()))
	var legacy_state: RefCounted = StateScript.new()
	ok = ok and _expect(legacy_state.load_from_user(1), "slot 1 loads legacy single-save when no slot 1 files exist")
	ok = ok and _expect(String(legacy_state.snapshot().get("phase", "")) == "shop", "legacy single-save restores shop phase into slot 1")

	_cleanup_save_files()
	ok = ok and _expect(battle_state.save_to_user(1), "smoke leaves a valid slot 1 primary behind")

	print("SMOKE_SAVE_SYSTEM_%s" % ["OK" if ok else "FAIL"])
	quit(0 if ok else 1)

func _read_save_doc(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	return Dictionary(parsed) if typeof(parsed) == TYPE_DICTIONARY else {}

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)

func _cleanup_save_files() -> void:
	for path in [LEGACY_SAVE_PATH, LEGACY_SAVE_BACKUP_PATH]:
		_remove_path(path)
	for slot in range(1, StateScript.SAVE_SLOT_COUNT + 1):
		for path in [_save_path(slot), _backup_path(slot), _temp_path(slot)]:
			_remove_path(path)

func _save_path(slot: int) -> String:
	return SAVE_PATH_PATTERN % slot

func _backup_path(slot: int) -> String:
	return SAVE_BACKUP_PATH_PATTERN % slot

func _temp_path(slot: int) -> String:
	return SAVE_TEMP_PATH_PATTERN % slot

func _remove_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _log_contains(lines: Array, needle: String) -> bool:
	for line in lines:
		if String(line).contains(needle):
			return true
	return false

func _expect(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Failed: %s" % label)
	return condition
