extends SceneTree

const PetScene := preload("res://art/prefabs/pet/pet.tscn")
const MANIFEST_PATH := "res://art/manifests/shared/pets/animations/pet_frame_animation_manifest.json"
const APPROVED_MANIFEST_PATH := "res://art/manifests/shared/pets/animations/approved_sprite_animation_manifest.json"
const EXPECTED_FRAME_COUNT := 4

var _animations: Array[Node] = []
var _capture_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("IDLE_SYNC_CAPTURE_DIR").strip_edges()
	if _capture_dir == "":
		_capture_dir = OS.get_environment("TEMP").path_join("approved_idle_4frame_sync")
	DirAccess.make_dir_recursive_absolute(_capture_dir)

	var stage := Control.new()
	stage.size = Vector2(1920.0, 1080.0)
	root.add_child(stage)
	var background := ColorRect.new()
	background.size = stage.size
	background.color = Color("202124")
	stage.add_child(background)

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_fail("runtime manifest is invalid")
		return
	var by_texture_path := Dictionary(Dictionary(parsed).get("by_texture_path", {}))
	var approved_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(APPROVED_MANIFEST_PATH))
	if not approved_parsed is Dictionary:
		_fail("approved manifest is invalid")
		return
	var approved_count := Array(Dictionary(approved_parsed).get("approved_animations", [])).size()
	var texture_paths: Array[String] = []
	for texture_path_value in by_texture_path.keys():
		texture_paths.append(String(texture_path_value))
	texture_paths.sort()
	if texture_paths.size() != approved_count:
		_fail("runtime idles=%d do not match approved idles=%d" % [texture_paths.size(), approved_count])
		return

	for index in range(texture_paths.size()):
		var texture_path := texture_paths[index]
		var texture_resource := load(texture_path) as Texture2D
		if texture_resource == null:
			_fail("missing source texture %s" % texture_path)
			return
		var pet := PetScene.instantiate() as Control
		pet.position = Vector2(190.0 + float(index % 5) * 345.0, 95.0 + float(index / 5) * 480.0)
		pet.size = Vector2(280.0, 280.0)
		stage.add_child(pet)
		pet.call("set_collection_data", {"id": texture_path.get_file().get_basename()}, texture_resource)
		var animation := pet.get_node("CompleteBattleCreaturePrefab/03_AttackActions")
		_animations.append(animation)

	for _frame in range(8):
		await process_frame

	var captured_indices: Dictionary = {}
	var first_index := -1
	var deadline_msec := Time.get_ticks_msec() + 8000
	while captured_indices.size() < EXPECTED_FRAME_COUNT and Time.get_ticks_msec() < deadline_msec:
		await process_frame
		var synchronized_index := _synchronized_index()
		if synchronized_index < 0:
			return
		if first_index < 0:
			first_index = synchronized_index
		if not captured_indices.has(synchronized_index):
			captured_indices[synchronized_index] = true
			if not await _capture(
				_capture_dir.path_join("phase_%02d.png" % (synchronized_index + 1))
			):
				return

	if captured_indices.size() != EXPECTED_FRAME_COUNT:
		_fail("did not observe all four synchronized idle phases")
		return

	var left_first_phase := false
	deadline_msec = Time.get_ticks_msec() + 6500
	while Time.get_ticks_msec() < deadline_msec:
		await process_frame
		var current_index := _synchronized_index()
		if current_index < 0:
			return
		if current_index != first_index:
			left_first_phase = true
		elif left_first_phase:
			if not await _capture(
				_capture_dir.path_join("phase_%02d_repeat.png" % (first_index + 1))
			):
				return
			print(
				"VISIBLE_PET_FRAME_ANIMATIONS_PASS pets=%d frames=4 loop_ms=1600 synchronized=true output=%s"
				% [_animations.size(), _capture_dir]
			)
			quit(0)
			return
	_fail("did not return to the first synchronized phase")


func _synchronized_index() -> int:
	var expected_index := -1
	for animation in _animations:
		var snapshot := Dictionary(animation.call("get_frame_animation_snapshot"))
		var actions := Dictionary(snapshot.get("actions", {}))
		if int(actions.get("idle", 0)) != EXPECTED_FRAME_COUNT:
			_fail("runtime idle did not expose exactly four frames")
			return -1
		var frame_index := int(snapshot.get("frame_index", -1))
		if frame_index < 0:
			_fail("runtime idle has no active synchronized frame")
			return -1
		if expected_index < 0:
			expected_index = frame_index
		elif frame_index != expected_index:
			_fail("approved idles drifted out of phase: %d != %d" % [frame_index, expected_index])
			return -1
	return expected_index


func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var viewport_image := root.get_texture().get_image()
	if viewport_image.save_png(path) != OK:
		_fail("could not save %s" % path)
		return false
	return true


func _fail(message: String) -> void:
	push_error("VISIBLE_PET_FRAME_ANIMATIONS_FAIL: %s" % message)
	quit(1)
