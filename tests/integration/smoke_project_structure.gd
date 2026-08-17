extends SceneTree

const MAIN_SCENE_PATH := "res://art/scenes/app/game.tscn"
const FORMAL_SCENE_PATHS: Array[String] = [
	"res://art/scenes/battle/battle_art_scene.tscn",
	MAIN_SCENE_PATH,
]
const ALLOWED_ART_SCENE_PATHS: Array[String] = [
	"res://art/scenes/battle/battle_art_scene.tscn",
	"res://art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn",
	MAIN_SCENE_PATH,
]
const PUBLIC_PREFAB_PATHS: Array[String] = [
	"res://art/prefabs/pet/pet.tscn",
	"res://art/prefabs/pet/pet_detail.tscn",
	"res://art/prefabs/terrain/terrain.tscn",
	"res://art/prefabs/terrain/terrain_detail.tscn",
]
const ALLOWED_ART_PREFAB_PATHS: Array[String] = [
	"res://art/prefabs/pet/pet.tscn",
	"res://art/prefabs/pet/pet_detail.tscn",
	"res://art/prefabs/pet/sprite_info_card.tscn",
	"res://art/prefabs/terrain/terrain.tscn",
	"res://art/prefabs/terrain/terrain_detail.tscn",
]
const FORMAL_DATA_PATH := "res://data/content"
const REQUIRED_DIRECTORIES := [
	"res://art",
	"res://art/scenes",
	"res://art/scenes/battle",
	"res://art/scenes/three_choice",
	"res://art/prefabs",
	"res://art/prefabs/pet",
	"res://art/prefabs/terrain",
	"res://art/images",
	"res://art/images/battle",
	"res://art/images/route",
	"res://art/images/shared/pets",
	"res://art/manifests",
	"res://art/manifests/battle",
	"res://art/manifests/route/rewards",
	"res://art/manifests/shared/pets/sheets",
	"res://core_ui",
	"res://core_ui/scripts",
	"res://core_ui/scripts/app",
	"res://core_ui/scripts/artist_flow",
	"res://core_ui/scripts/battle",
	"res://core_ui/scripts/route",
	"res://core_ui/scripts/shop",
	"res://core_ui/scripts/inventory",
	"res://core_ui/scripts/party",
	"res://core_ui/scripts/settlement",
	"res://core_ui/scripts/shared/pet",
	"res://shared/ui/buttons",
	"res://core/commands",
	"res://session/transport",
	"res://persistence/migrations",
	"res://data/schemas",
	FORMAL_DATA_PATH,
	"res://data/content/generated",
	"res://data/content/extensions",
	"res://debug/fixtures",
	"res://tests/visible",
]
const REQUIRED_FILES := [
	MAIN_SCENE_PATH,
	"res://art/prefabs/README.md",
	"res://art/scenes/battle/battle_art_scene.tscn",
	"res://art/manifests/battle/battle_asset_manifest.json",
	"res://art/manifests/battle/enemy_image_map.json",
	"res://art/manifests/shared/pets/sheets/pet_id_map.json",
	"res://core_ui/scripts/app/game_controller.gd",
	"res://core_ui/scripts/app/scene_router.gd",
	"res://session/session_factory.gd",
	"res://art/prefabs/pet/pet.tscn",
	"res://art/prefabs/pet/pet_detail.tscn",
	"res://art/prefabs/terrain/terrain.tscn",
	"res://art/prefabs/terrain/terrain_detail.tscn",
	"res://core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd",
	"res://core_ui/scripts/artist_flow/presenters/artist_flow_stage_presenter.gd",
	"res://core_ui/scripts/route/controllers/route_controller.gd",
	"res://core_ui/scripts/route/presenters/route_presenter.gd",
	"res://core_ui/scripts/shop/controllers/shop_controller.gd",
	"res://core_ui/scripts/shop/presenters/shop_presenter.gd",
	"res://core_ui/scripts/inventory/controllers/inventory_controller.gd",
	"res://core_ui/scripts/inventory/presenters/inventory_presenter.gd",
	"res://core_ui/scripts/party/controllers/party_controller.gd",
	"res://core_ui/scripts/party/presenters/party_presenter.gd",
	"res://core_ui/scripts/settlement/controllers/settlement_controller.gd",
	"res://core_ui/scripts/settlement/presenters/settlement_presenter.gd",
	"res://session/game_session.gd",
	"res://session/local_game_session.gd",
	"res://session/remote_game_session.gd",
	"res://persistence/save_repository.gd",
	"res://persistence/replay_repository.gd",
]

var failed := false


func _initialize() -> void:
	for path in REQUIRED_FILES:
		_expect(FileAccess.file_exists(path), "required project file exists: %s" % path)
	for path in REQUIRED_DIRECTORIES:
		_expect(_directory_exists(path), "required project directory exists: %s" % path)
	_expect(not _directory_exists("res://scripts"), "legacy scripts root stays removed")
	_expect(not _directory_exists("res://scenes"), "legacy scenes root stays removed")
	_expect(not _directory_exists("res://game"), "legacy game UI root stays removed")
	_expect(not _directory_exists("res://features"), "legacy feature UI root stays removed")
	_expect(not _directory_exists("res://assets"), "legacy image root stays removed")
	_expect(_directory_exists("res://art/images"), "formal Art image root exists")
	_expect(String(ProjectSettings.get_setting("application/run/main_scene", "")) == MAIN_SCENE_PATH, "project starts from the three-choice Scene")

	var forbidden_runtime_dependencies := ["res://core_ui/", "res://art/", "res://shared/", "res://game/", "res://features/"]
	var forbidden_runtime_classes := _class_names_for_roots(["res://core_ui", "res://art", "res://shared"])
	_scan_layer("res://core", forbidden_runtime_dependencies, forbidden_runtime_classes, "core")
	_scan_layer("res://session", forbidden_runtime_dependencies, forbidden_runtime_classes, "session")
	_scan_layer("res://persistence", forbidden_runtime_dependencies, forbidden_runtime_classes, "persistence")
	_scan_core_runtime_api("res://core")
	if failed:
		quit(1)
		return
	_scan_prefabs("res://art/prefabs")
	_scan_file_type_boundaries()

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "three-choice Scene loads")
	if packed != null:
		var art := packed.instantiate()
		root.add_child(art)
		await process_frame
		await process_frame
		_expect(art.get_node_or_null("ViewHost") == null, "three-choice Scene has no redundant self-wrapper view host")
		_expect(art.get_node_or_null("FeatureHost") != null, "three-choice Scene owns the battle feature host")
		_expect(art.has_method("get_active_view") and art.call("get_active_view") != null, "scene router mounts the authored three-choice view")
		_expect(art.has_method("get_game_session") and art.call("get_game_session") != null, "three-choice Scene exposes the session boundary")
		for feature_name in [&"route", &"shop", &"inventory", &"party", &"settlement"]:
			_expect(art.call("get_feature_controller", feature_name) != null, "%s controller is reachable through the public adapter" % feature_name)
		_expect(art.call("get_feature_controller", &"battle") == null, "battle controller stays unmounted during route startup")
		root.remove_child(art)
		art.free()
		art = null
		await process_frame
		await process_frame

	if failed:
		quit(1)
		return
	print("SMOKE_PROJECT_STRUCTURE_OK main=%s data=%s" % [MAIN_SCENE_PATH, FORMAL_DATA_PATH])
	quit(0)


func _scan_layer(root_path: String, forbidden_tokens: Array, forbidden_classes: Array[String], label: String) -> void:
	for path in _source_files(root_path):
		var source := FileAccess.get_file_as_string(path)
		for token in forbidden_tokens:
			_expect(not source.contains(String(token)), "%s source does not reference %s: %s" % [label, token, path])
		for class_name_value in forbidden_classes:
			_expect(not _contains_identifier(source, class_name_value), "%s source does not reference UI class %s: %s" % [label, class_name_value, path])
		for resource_path in _literal_resource_paths(source):
			_expect(String(resource_path).begins_with("res://"), "%s source uses an absolute res:// resource path instead of %s: %s" % [label, resource_path, path])


func _scan_core_runtime_api(root_path: String) -> void:
	var forbidden_node_api := [
		"get_node(", "get_node_or_null(", "get_tree(", "get_child(", "get_children(", "get_child_count(",
		"find_child(", "find_children(", "get_parent(", "has_node(", "add_child(", "remove_child(",
		"move_child(", "reparent(", "NodePath(",
	]
	for path in _source_files(root_path):
		if not path.ends_with(".gd"):
			continue
		var source := FileAccess.get_file_as_string(path)
		var script := load(path) as Script
		_expect(script != null, "core script remains loadable for dependency inspection: %s" % path)
		if script != null:
			var native_base := String(script.get_instance_base_type())
			_expect(not ClassDB.is_parent_class(native_base, "Node"), "core script native base %s stays outside the Godot node lifecycle: %s" % [native_base, path])
		for token in forbidden_node_api:
			_expect(not source.contains(String(token)), "core script does not traverse a scene tree via %s: %s" % [token, path])


func _class_names_for_roots(root_paths: Array[String]) -> Array[String]:
	var names: Dictionary = {}
	for root_path in root_paths:
		for path in _source_files(root_path):
			if not path.ends_with(".gd"):
				continue
			for line_value in FileAccess.get_file_as_string(path).split("\n"):
				var line := String(line_value).strip_edges()
				if not line.begins_with("class_name "):
					continue
				var class_name_value := line.trim_prefix("class_name ").get_slice(" ", 0).strip_edges()
				if class_name_value != "":
					names[class_name_value] = true
	var result: Array[String] = []
	for value in names.keys():
		result.append(String(value))
	result.sort()
	return result


func _contains_identifier(source: String, identifier: String) -> bool:
	var regex := RegEx.new()
	regex.compile("(^|[^A-Za-z0-9_])%s([^A-Za-z0-9_]|$)" % identifier)
	return regex.search(source) != null


func _literal_resource_paths(source: String) -> Array[String]:
	var paths: Array[String] = []
	for pattern in ["(?:preload|load)\\s*\\(\\s*\"([^\"]+)\"\\s*\\)", "extends\\s+\"([^\"]+)\""]:
		var regex := RegEx.new()
		regex.compile(pattern)
		for matched in regex.search_all(source):
			paths.append(String(matched.get_string(1)))
	return paths


func _scan_prefabs(root_path: String) -> void:
	for path in _source_files(root_path):
		if not path.ends_with(".tscn") or not path.contains("/prefabs/"):
			continue
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("res://core/state/game_state.gd"), "feature prefab does not read GameState directly: %s" % path)


func _scan_file_type_boundaries() -> void:
	var formal_scenes := _files_with_suffix("res://art/scenes", [".tscn"])
	formal_scenes.sort()
	for path in ALLOWED_ART_SCENE_PATHS:
		_expect(formal_scenes.has(path), "required authored Scene remains present: %s" % path)
	for path in FORMAL_SCENE_PATHS:
		_expect(formal_scenes.has(path), "runtime Scene remains present: %s" % path)
	var formal_prefabs := _files_with_suffix("res://art/prefabs", [".tscn"])
	formal_prefabs.sort()
	for path in ALLOWED_ART_PREFAB_PATHS:
		_expect(formal_prefabs.has(path), "required authored prefab remains present: %s" % path)
	for path in PUBLIC_PREFAB_PATHS:
		_expect(formal_prefabs.has(path), "public gameplay prefab remains present: %s" % path)
	_expect(_files_with_suffix("res://art/scenes", [".gd", ".gd.uid", ".json", ".png", ".jpg", ".jpeg", ".webp", ".svg"]).is_empty(), "scene type directory contains only scenes and documentation")
	_expect(_files_with_suffix("res://art/prefabs", [".gd", ".gd.uid", ".json", ".png", ".jpg", ".jpeg", ".webp", ".svg"]).is_empty(), "prefab type directory contains only prefabs and documentation")
	_expect(_files_with_suffix("res://art/images", [".gd", ".gd.uid", ".tscn", ".json"]).is_empty(), "image type directory contains no scripts, scenes, or JSON manifests")
	_expect(_files_with_suffix("res://art/manifests", [".gd", ".gd.uid", ".tscn", ".png", ".jpg", ".jpeg", ".webp", ".svg"]).is_empty(), "manifest type directory contains no scripts, scenes, or images")
	_expect(_files_with_suffix("res://core_ui", [".tscn", ".json", ".png", ".jpg", ".jpeg", ".webp", ".svg"]).is_empty(), "Core UI contains no scenes, manifests, or images")
	for path in _all_files("res://core_ui"):
		if path == "res://core_ui/README.md":
			continue
		_expect(path.begins_with("res://core_ui/scripts/"), "all Core UI implementation files stay under scripts/: %s" % path)


func _files_with_suffix(root_path: String, suffixes: Array[String]) -> Array[String]:
	var matches: Array[String] = []
	for path in _all_files(root_path):
		for suffix in suffixes:
			if path.ends_with(suffix):
				matches.append(path)
				break
	return matches


func _all_files(root_path: String) -> Array[String]:
	var results: Array[String] = []
	_collect_all_files(root_path, results)
	return results


func _collect_all_files(root_path: String, results: Array[String]) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var path := root_path.path_join(entry)
		if directory.current_is_dir():
			_collect_all_files(path, results)
		else:
			results.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _source_files(root_path: String) -> Array[String]:
	var results: Array[String] = []
	_collect_sources(root_path, results)
	return results


func _collect_sources(root_path: String, results: Array[String]) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var path := root_path.path_join(entry)
		if directory.current_is_dir():
			_collect_sources(path, results)
		elif path.ends_with(".gd") or path.ends_with(".tscn"):
			results.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _directory_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
