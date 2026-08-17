extends SceneTree

const FeatureRegistryScript := preload("res://core_ui/scripts/app/feature_registry.gd")
const SceneRouterScript := preload("res://core_ui/scripts/app/scene_router.gd")


func _init() -> void:
	var ok := true
	var registry: RefCounted = FeatureRegistryScript.new()
	ok = _expect(not bool(registry.call("has_feature", FeatureRegistryScript.THREE_CHOICE_FEATURE)), "three-choice root is not registered as its own child") and ok
	ok = _expect(bool(registry.call("has_feature", FeatureRegistryScript.BATTLE_FEATURE)), "formal battle feature is registered") and ok
	ok = _expect(registry.call("scene_for", FeatureRegistryScript.BATTLE_FEATURE) is PackedScene, "battle feature resolves a PackedScene") and ok
	ok = _expect(
		(registry.call("scene_for", FeatureRegistryScript.BATTLE_FEATURE) as PackedScene).resource_path == "res://art/scenes/battle/battle_art_scene.tscn",
		"battle feature resolves the formal battle Scene"
	) and ok

	var test_scene := PackedScene.new()
	var test_view := Node.new()
	test_view.name = "RegistrySmokeView"
	ok = _expect(test_scene.pack(test_view) == OK, "test feature scene packs") and ok
	test_view.free()
	ok = _expect(bool(registry.call("register_feature", &"test_feature", test_scene)), "new feature registers without shell changes") and ok
	ok = _expect(not bool(registry.call("register_feature", &"test_feature", test_scene)), "duplicate feature is rejected") and ok

	var host := Node.new()
	root.add_child(host)
	var router: RefCounted = SceneRouterScript.new(host, registry)
	var mounted: Node = router.call("mount_feature", &"test_feature")
	ok = _expect(mounted != null and mounted.name == "RegistrySmokeView", "router mounts registered feature") and ok
	ok = _expect(StringName(router.call("active_feature")) == &"test_feature", "router exposes active feature") and ok
	ok = _expect(router.call("mount_feature", &"missing") == null, "unknown feature does not mutate the host") and ok

	print("SMOKE_FEATURE_SCENE_REGISTRY_%s" % ["OK" if ok else "FAIL"])
	quit(0 if ok else 1)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Failed: %s" % label)
	return condition
