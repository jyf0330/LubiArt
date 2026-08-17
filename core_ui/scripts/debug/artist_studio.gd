extends Control

const SingleplayerScene := preload("res://art/scenes/app/game.tscn")
const ArtistPreviewCatalogScript := preload("res://core_ui/scripts/debug/artist_preview_catalog.gd")

var _catalog: RefCounted = ArtistPreviewCatalogScript.new()
var _game_view: Control = null
var _battle_view: Node = null


func _process(_delta: float) -> void:
	_hide_player_only_widgets()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_view = SingleplayerScene.instantiate() as Control
	_game_view.name = "ArtistStudioGameView"
	_game_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_game_view)
	await get_tree().process_frame
	_install_controls()
	debug_apply_preset(&"route_default")
	call_deferred("_hide_player_only_widgets")


func debug_apply_preset(preset_name: StringName) -> Dictionary:
	if _game_view == null:
		return {"preset": preset_name, "phase": "", "ready": false}
	var preview_state: RefCounted = _catalog.create_state(preset_name)
	_game_view.set("state", preview_state)
	if _game_view.has_method("render_current_view"):
		_game_view.call("render_current_view")
	_hide_player_only_widgets()
	_battle_view = _game_view.find_child("BattleArtScene", true, false)
	return {
		"preset": preset_name,
		"phase": String(preview_state.snapshot().get("phase", "")),
		"ready": true,
	}


func debug_play_motion(motion_name: StringName) -> Dictionary:
	if motion_name != &"prefab_samples":
		return {"started": false, "reason": "unknown_motion"}
	debug_apply_preset(&"battle_opening")
	if _battle_view == null:
		return {"started": false, "reason": "battle_view_unavailable"}
	var vfx_host := _battle_view.get_node_or_null("Board/VfxHost")
	if vfx_host == null or not vfx_host.has_method("debug_spawn_prefab_samples"):
		return {"started": false, "reason": "vfx_host_unavailable"}
	var summary := Dictionary(vfx_host.call("debug_spawn_prefab_samples"))
	return {"started": not summary.is_empty(), "summary": summary}


func _install_controls() -> void:
	var panel := PanelContainer.new()
	panel.name = "ArtistStudioControls"
	panel.position = Vector2(16.0, 16.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 100
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	for preset_name in [&"route_default", &"shop_stocked", &"battle_opening"]:
		var button := Button.new()
		button.name = "Preset_%s" % preset_name
		button.text = _catalog.preset_label(preset_name)
		button.pressed.connect(debug_apply_preset.bind(preset_name))
		row.add_child(button)
	var vfx_button := Button.new()
	vfx_button.name = "PlayPrefabSamples"
	vfx_button.text = "播放动效"
	vfx_button.pressed.connect(debug_play_motion.bind(&"prefab_samples"))
	row.add_child(vfx_button)


func _hide_player_only_widgets() -> void:
	for node_name in ["RunTools", "BazaarInfoPanel"]:
		var node := _game_view.find_child(node_name, true, false) as Control
		if node != null:
			node.hide()
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
