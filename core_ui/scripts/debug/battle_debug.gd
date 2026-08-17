extends Control

const SingleplayerScene := preload("res://art/scenes/app/game.tscn")
const DebugBattleSetupPanelScene := preload("res://art/scenes/debug/debug_battle_setup_panel.tscn")
const SessionFactoryScript := preload("res://session/session_factory.gd")
const DEFAULT_DEBUG_SEED := "ysbzs-debug-first-battle-v1"

var game_view: Control
var game_session: RefCounted
var setup_panel: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	game_view = SingleplayerScene.instantiate() as Control
	game_view.name = "BattleDebugGameView"
	game_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game_view)
	await get_tree().process_frame
	_install_debug_header()
	_install_setup_panel()
	_prepare_debug_configuration()

func _install_debug_header() -> void:
	var title := game_view.find_child("TitleLabel", true, false)
	if title is Label:
		title.text = "战斗调试"


func _install_setup_panel() -> void:
	setup_panel = find_child("DebugBattleSetupPanel", true, false) as Control
	if setup_panel == null:
		var overlay := get_node_or_null("DebugOverlay") as CanvasLayer
		if overlay == null:
			overlay = CanvasLayer.new()
			overlay.name = "DebugOverlay"
			overlay.layer = 100
			add_child(overlay)
		setup_panel = DebugBattleSetupPanelScene.instantiate() as Control
		setup_panel.name = "DebugBattleSetupPanel"
		overlay.add_child(setup_panel)
	if not setup_panel.is_connected("start_requested", _on_start_debug_battle_requested):
		setup_panel.connect("start_requested", _on_start_debug_battle_requested)
	if not setup_panel.is_connected("reopen_requested", _on_reset_debug_battle_pressed):
		setup_panel.connect("reopen_requested", _on_reset_debug_battle_pressed)


func _prepare_debug_configuration() -> void:
	var creation := Dictionary(SessionFactoryScript.create_isolated_developer_result({
		"run_seed": DEFAULT_DEBUG_SEED,
	}))
	if not bool(creation.get("ok", false)):
		push_error("BATTLE_DEBUG_SESSION_INIT_FAILED:%s" % JSON.stringify(creation.get("initialization", {})))
		return
	game_session = creation.get("session") as RefCounted
	game_view.call("set_game_session", game_session)
	var catalog_response := Dictionary(game_session.call("submit_command", {"type": "GET_DEVELOPER_OBJECT_CATALOG"}))
	if not bool(catalog_response.get("accepted", false)):
		var catalog_error := Dictionary(catalog_response.get("error", {}))
		setup_panel.call("set_error", String(catalog_error.get("message", "无法读取正式宠物目录。")))
		return
	setup_panel.call("set_catalog", Dictionary(catalog_response.get("result", {})), DEFAULT_DEBUG_SEED)
	setup_panel.call("show_configuration")
	_render_game_view()


func _on_start_debug_battle_requested(seed: String, player_pet_ids: Array, enemy_pet_ids: Array) -> void:
	var battle_start := Dictionary(game_session.call("submit_command", {
		"type": "START_DEVELOPER_SCENARIO",
		"scenarioId": "debug_first_battle",
		"seed": seed,
		"playerRefs": _pet_refs(player_pet_ids),
		"enemyRefs": _pet_refs(enemy_pet_ids),
	}))
	if not bool(battle_start.get("accepted", false)):
		var battle_error := Dictionary(battle_start.get("error", {}))
		setup_panel.call("set_error", String(battle_error.get("message", "第一场战斗配置被规则拒绝。")))
		return
	setup_panel.call("enter_battle_mode")
	_apply_opening_focus()
	_clear_dynamic_children_now()
	_render_game_view()


func _pet_refs(pet_ids: Array) -> Array:
	var refs: Array = []
	for pet_id_value in pet_ids:
		refs.append({"kind": "pet", "id": String(pet_id_value)})
	return refs


func _start_fixed_seed_battle() -> void:
	_on_start_debug_battle_requested(
		DEFAULT_DEBUG_SEED,
		["pal_002", "pal_011", "pal_028", "pal_030"],
		["pal_001", "pal_042", "pal_006", "pal_003"]
	)

func _render_game_view() -> void:
	if game_view.has_method("render_current_view"):
		game_view.call("render_current_view")

func _apply_opening_focus() -> void:
	var snap := Dictionary(game_session.call("current_snapshot"))
	for unit_value in Array(snap.get("units", [])):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != "player":
			continue
		var unit_id := String(unit.get("id", unit.get("pet_id", "")))
		if unit_id == "":
			return
		game_session.call("submit_command", {"type": "SELECT_UNIT", "unitId": unit_id})
		game_session.call("submit_command", {"type": "SELECT_ACTION_SLOT", "slotId": 0})
		game_session.call("submit_command", {"type": "SET_ACTION_DIRECTION", "unitId": unit_id, "slotId": 0, "dir": "right"})
		game_session.call("submit_command", {
			"type": "SET_ACTION_AP",
			"unitId": unit_id,
			"slotId": 0,
			"ap": min(2, int(Dictionary(game_session.call("current_snapshot")).get("ap", 1))),
		})
		return

func _on_reset_debug_battle_pressed() -> void:
	_prepare_debug_configuration()

func _clear_dynamic_children_now() -> void:
	for property_name in ["content", "log_box"]:
		var node := game_view.get(property_name) as Control
		if node == null:
			continue
		for child in node.get_children():
			child.free()
