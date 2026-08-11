extends Control

## BattleArtScene page presentation coordinator. Game owns Session and routes
## semantic commands; this node only stages public Snapshot/Trace presentation.

signal command_requested(command: Dictionary)
signal session_operation_requested(operation: StringName, arguments: Dictionary)
signal trace_sequence_finished
signal button_shortcut_hints_visibility_changed(hints_visible: bool)
signal shortcut_bindings_changed(bindings: Dictionary)

const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const BattleTraceProjectionScript := preload("res://core_ui/scripts/battle/controllers/battle_trace_projection.gd")
const GameLogScript := preload("res://core/logging/game_log.gd")
const ShortcutCatalog := preload("res://core_ui/scripts/shared/shortcut_catalog.gd")
const NORMAL_BATTLE_SPEED := 1.0
const FAST_BATTLE_SPEED := 2.0
const SETTINGS_MODAL_BLOCKED_SHORTCUTS := [
	ShortcutCatalog.ACTION_AUTO_ARRANGE,
	ShortcutCatalog.ACTION_RESET_ARRANGE,
	ShortcutCatalog.ACTION_BATTLE_SPEED,
	ShortcutCatalog.ACTION_ATTACK_ORDER,
	ShortcutCatalog.ACTION_BATTLE_BAG,
	ShortcutCatalog.ACTION_ALL_OUT,
]
const TIMELINE_MODAL_BLOCKED_SHORTCUTS := [
	ShortcutCatalog.ACTION_AUTO_ARRANGE,
	ShortcutCatalog.ACTION_RESET_ARRANGE,
	ShortcutCatalog.ACTION_BATTLE_SPEED,
	ShortcutCatalog.ACTION_BATTLE_BAG,
	ShortcutCatalog.ACTION_ALL_OUT,
]

@onready var board: Control = $Board
@onready var vfx_host: Control = $Board/VfxHost
@onready var hud: Control = $Hud
@onready var overlay: Control = $OverlayHost
@onready var settings_menu: Control = $OverlayHost/SettingsMenu
@onready var map_controls: Control = $MapControls
@onready var map_debug_button: Button = $Hud/BattleActionPanel/Margin/Content/MapDebugButton
@onready var map_auto_arrange_button: TextureButton = $MapControls/AutoArrangeButton
@onready var map_reset_button: TextureButton = $MapControls/ResetButton
@onready var map_bag_button: TextureButton = $MapControls/BagButton
@onready var map_all_out_button: TextureButton = $MapControls/AllOutButton

var _assets: RefCounted = null
var _trace_projection := BattleTraceProjectionScript.new()
var _last_snapshot: Dictionary = {}
var _presented_snapshot: Dictionary = {}
var _rendered_trace_count := -1
var _pending_final_snapshot: Dictionary = {}
var _pending_enemy_move_final_cells := {}
var _battle_input_locked := false
var _debug_map_index := -1
var _combat_speed_enabled := false
var _all_out_trace_active := false
var _button_shortcut_hints_visible := true
var _announced_round := 0


func _ready() -> void:
	_assets = BattleAssetRegistryScript.new()
	board.call("configure", _assets)
	overlay.call("configure", _assets)
	_connect_command_source(board)
	_connect_command_source(hud)
	if hud.has_signal("health_bar_tier_requested"):
		hud.connect(
			"health_bar_tier_requested",
			Callable(self, "_on_health_bar_tier_requested")
		)
	if board.has_signal("cell_detail_requested"):
		board.connect("cell_detail_requested", Callable(self, "_on_cell_detail_requested"))
	if vfx_host.has_method("configure"):
		vfx_host.call("configure", board.get_node("CellHost"), board.get_node("UnitHost"), _assets)
	_connect_vfx_signal("pets_reset_reveal_requested", "_on_pets_reset_reveal_requested")
	_connect_vfx_signal("trace_sequence_started", "_on_trace_sequence_started")
	_connect_vfx_signal("trace_sequence_finished", "_on_trace_sequence_finished")
	_connect_vfx_signal("enemy_move_projection_requested", "_on_enemy_move_projection_requested")
	if settings_menu.has_signal("session_operation_requested"):
		settings_menu.connect(
			"session_operation_requested",
			Callable(self, "_on_settings_session_operation_requested")
		)
	if settings_menu.has_signal("button_shortcut_hints_visibility_changed"):
		settings_menu.connect(
			"button_shortcut_hints_visibility_changed",
			Callable(self, "_on_button_shortcut_hints_visibility_changed")
		)
	if settings_menu.has_signal("shortcut_bindings_changed"):
		settings_menu.connect(
			"shortcut_bindings_changed",
			Callable(self, "_on_shortcut_bindings_changed")
		)
	settings_menu.visibility_changed.connect(_on_settings_menu_visibility_changed)
	_connect_map_controls()
	_configure_round_rewind_action({})
	set_button_shortcut_hints_visible(_button_shortcut_hints_visible)
	map_debug_button.pressed.connect(_on_map_debug_button_pressed)


func _exit_tree() -> void:
	# D 只允许影响战斗 Trace；离开战斗页时必须恢复全局正常速度。
	Engine.time_scale = NORMAL_BATTLE_SPEED


func get_runtime_view() -> Control:
	return self


func is_battle_input_locked() -> bool:
	return _battle_input_locked


func set_button_shortcut_hints_visible(hints_visible: bool) -> void:
	_button_shortcut_hints_visible = hints_visible
	if map_controls != null and map_controls.has_method("set_shortcut_hints_visible"):
		map_controls.call("set_shortcut_hints_visible", hints_visible)
	if settings_menu != null and settings_menu.has_method("set_button_shortcut_hints_visible"):
		settings_menu.call("set_button_shortcut_hints_visible", hints_visible)


func _on_health_bar_tier_requested(tier: String) -> void:
	if board != null and board.has_method("set_all_health_bar_tiers"):
		board.call("set_all_health_bar_tiers", tier)


func are_button_shortcut_hints_visible() -> bool:
	return _button_shortcut_hints_visible


func configure_trace_cursor(cursor: int) -> void:
	_rendered_trace_count = maxi(-1, cursor)


func get_trace_cursor() -> int:
	return _rendered_trace_count


func render_snapshot(snapshot: Dictionary) -> void:
	var incoming := snapshot.duplicate(true)
	var new_events := Array(_trace_projection.call("new_events", incoming, _rendered_trace_count))
	var stage_for_active_trace := not _presented_snapshot.is_empty() and (
		not new_events.is_empty()
		or not _pending_final_snapshot.is_empty()
		or _battle_input_locked
	)
	_last_snapshot = incoming
	var final_cells := Array(Dictionary(incoming.get("board", {})).get("cells", [])).duplicate(true)
	if stage_for_active_trace:
		_pending_final_snapshot = incoming.duplicate(true)
		_pending_enemy_move_final_cells.merge(
			Dictionary(_trace_projection.call("collect_enemy_move_final_cells", final_cells, new_events)),
			true
		)
		_refresh_pending_enemy_move_final_cells(final_cells)
	else:
		_pending_final_snapshot = {}
		var visible_cells := final_cells.duplicate(true)
		_pending_enemy_move_final_cells.merge(
			Dictionary(_trace_projection.call("defer_enemy_move_projection", visible_cells, new_events)),
			true
		)
		_commit_presentation_snapshot(
			incoming,
			visible_cells,
			Dictionary(_trace_projection.call("pending_reset_unit_ids", new_events))
		)
	if not new_events.is_empty():
		_all_out_trace_active = _latest_command_type(incoming) == "RUN_COMBAT_ROUND"
		_rendered_trace_count = Array(incoming.get("battleTrace", incoming.get("battle_trace", []))).size()
		_set_battle_input_locked(true)
		play_battle_trace(new_events)
	elif _rendered_trace_count < 0:
		_rendered_trace_count = Array(incoming.get("battleTrace", incoming.get("battle_trace", []))).size()


func render_command_response(command: Dictionary, response: Dictionary) -> void:
	if hud.has_method("render_command_response"):
		hud.call("render_command_response", command, response)
	var response_snapshot_value: Variant = response.get("snapshot", {})
	var availability_snapshot := (
		Dictionary(response_snapshot_value)
		if response_snapshot_value is Dictionary and not Dictionary(response_snapshot_value).is_empty()
		else _last_snapshot
	)
	_update_map_control_availability(availability_snapshot)
	_log_button_command_response(command, response, availability_snapshot)


func play_battle_trace(events: Array) -> void:
	if events.is_empty():
		return
	if vfx_host == null or not vfx_host.has_method("play_trace"):
		GameLogScript.warning("表现/战斗事件", "VFX 不可用，直接应用最终快照")
		_apply_staged_final_snapshot()
		return
	vfx_host.call("play_trace", events)


func _connect_command_source(source: Node) -> void:
	if source == null or not source.has_signal("command_requested"):
		return
	var callback := Callable(self, "_on_command_requested")
	if not source.is_connected("command_requested", callback):
		source.connect("command_requested", callback)


func _connect_vfx_signal(signal_name: StringName, method_name: StringName) -> void:
	if vfx_host == null or not vfx_host.has_signal(signal_name):
		return
	var callback := Callable(self, method_name)
	if not vfx_host.is_connected(signal_name, callback):
		vfx_host.connect(signal_name, callback)


func _on_command_requested(command: Dictionary) -> void:
	if _battle_input_locked or command.is_empty():
		return
	if String(command.get("type", "")).strip_edges().to_upper() == "RUN_COMBAT_ROUND" \
			and board != null and board.has_method("clear_transient_state"):
		board.call("clear_transient_state")
	command_requested.emit(command.duplicate(true))


func _on_cell_detail_requested(grid: Vector2i, unit_id: String) -> void:
	if grid.x < 0 or grid.y < 0:
		overlay.call("clear")
		return
	overlay.call("request_detail", grid, unit_id)


func _on_enemy_move_projection_requested(event: Dictionary) -> void:
	var actor := Dictionary(event.get("actor", {}))
	var unit_id := String(event.get("unitId", actor.get("id", "")))
	var final_cell := Dictionary(_pending_enemy_move_final_cells.get(unit_id, {}))
	if unit_id == "" or final_cell.is_empty():
		return
	board.call("apply_enemy_move_final_cell", unit_id, final_cell)
	_pending_enemy_move_final_cells.erase(unit_id)


func _on_pets_reset_reveal_requested(units: Array) -> void:
	board.call("reveal_reset_units", units)


func _on_trace_sequence_started() -> void:
	_set_battle_input_locked(true)
	_apply_combat_speed()
	if _all_out_trace_active:
		GameLogScript.info("战斗按键/D", "全军出击战斗演出开始", {
			"播放速度": "2倍" if _combat_speed_enabled else "1倍",
		})


func _on_trace_sequence_finished() -> void:
	Engine.time_scale = NORMAL_BATTLE_SPEED
	if _all_out_trace_active:
		GameLogScript.info("战斗按键/D", "全军出击战斗演出结束，播放速度已恢复为1倍")
	_all_out_trace_active = false
	_apply_staged_final_snapshot()


func _apply_staged_final_snapshot() -> void:
	if not _pending_final_snapshot.is_empty():
		var final_snapshot := _pending_final_snapshot.duplicate(true)
		_pending_final_snapshot = {}
		var final_cells := Array(Dictionary(final_snapshot.get("board", {})).get("cells", [])).duplicate(true)
		_commit_presentation_snapshot(final_snapshot, final_cells, {}, true)
	else:
		for unit_id_value in _pending_enemy_move_final_cells.keys():
			board.call("apply_enemy_move_final_cell", String(unit_id_value), Dictionary(_pending_enemy_move_final_cells[unit_id_value]))
	_pending_enemy_move_final_cells.clear()
	_set_battle_input_locked(false)
	trace_sequence_finished.emit()


func _commit_presentation_snapshot(
	snapshot: Dictionary,
	cells: Array,
	pending_reset_ids: Dictionary = {},
	reconcile_unit_presentation: bool = false
) -> void:
	board.call(
		"render_snapshot",
		snapshot,
		cells,
		pending_reset_ids,
		reconcile_unit_presentation
	)
	hud.call("render_snapshot", snapshot)
	overlay.call("render_snapshot", snapshot)
	_sync_map_controls(snapshot)
	_presented_snapshot = snapshot.duplicate(true)
	_announce_round_if_needed(snapshot)


func _announce_round_if_needed(snapshot: Dictionary) -> void:
	if String(snapshot.get("phase", "")) != "battle":
		return
	var round_number := int(snapshot.get("battle_round", snapshot.get("battleRound", 0)))
	if round_number <= 0 or round_number == _announced_round:
		return
	_announced_round = round_number
	if vfx_host != null and vfx_host.has_method("play_round_banner"):
		vfx_host.call("play_round_banner", round_number, "player")


func _refresh_pending_enemy_move_final_cells(final_cells: Array) -> void:
	if _pending_enemy_move_final_cells.is_empty():
		return
	for cell_value in final_cells:
		var cell := Dictionary(cell_value)
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		if _pending_enemy_move_final_cells.has(unit_id):
			_pending_enemy_move_final_cells[unit_id] = cell.duplicate(true)


func _set_battle_input_locked(locked: bool) -> void:
	_battle_input_locked = locked
	board.call("set_input_locked", locked)
	hud.call("set_input_locked", locked)
	_update_map_control_availability(_last_snapshot)


func _input(event: InputEvent) -> void:
	if settings_menu != null \
			and settings_menu.has_method("is_capturing_shortcut") \
			and bool(settings_menu.call("is_capturing_shortcut")):
		return
	if not event is InputEventKey and not event is InputEventMouseButton:
		return
	var action_id := ShortcutCatalog.action_for_event(event)
	if action_id == &"":
		return
	var pressed := (
		(event as InputEventKey).pressed
		if event is InputEventKey
		else (event as InputEventMouseButton).pressed
	)
	var is_echo := event is InputEventKey and (event as InputEventKey).echo
	if _settings_menu_is_open() and action_id in SETTINGS_MODAL_BLOCKED_SHORTCUTS:
		if not pressed and map_controls.has_method("handle_shortcut_input"):
			map_controls.call("handle_shortcut_input", event, false)
		get_viewport().set_input_as_handled()
		return
	if _attack_timeline_is_open() and action_id in TIMELINE_MODAL_BLOCKED_SHORTCUTS:
		if not pressed and map_controls.has_method("handle_shortcut_input"):
			map_controls.call("handle_shortcut_input", event, false)
		get_viewport().set_input_as_handled()
		return
	if action_id not in [ShortcutCatalog.ACTION_SETTINGS, ShortcutCatalog.ACTION_ATTACK_ORDER]:
		return
	if map_controls.has_method("handle_shortcut_input"):
		map_controls.call("handle_shortcut_input", event, false)
	if not pressed or is_echo:
		get_viewport().set_input_as_handled()
		return
	match action_id:
		ShortcutCatalog.ACTION_SETTINGS:
			_on_map_settings_requested()
		ShortcutCatalog.ACTION_ATTACK_ORDER:
			_on_map_attack_order_requested()
		_:
			return
	get_viewport().set_input_as_handled()


func _settings_menu_is_open() -> bool:
	return settings_menu != null and bool(settings_menu.call("is_open"))


func _attack_timeline_is_open() -> bool:
	return hud != null and bool(hud.call("debug_is_attack_timeline_open"))


func _connect_map_controls() -> void:
	var connections := {
		"settings_requested": Callable(self, "_on_map_settings_requested"),
		"attack_order_requested": Callable(self, "_on_map_attack_order_requested"),
		"bag_requested": Callable(self, "_on_map_bag_requested"),
		"auto_arrange_requested": Callable(self, "_on_map_auto_arrange_requested"),
		"reset_requested": Callable(self, "_on_map_reset_requested"),
		"speed_toggled": Callable(self, "_on_map_speed_toggled"),
		"all_out_requested": Callable(self, "_on_map_all_out_requested"),
		"shortcut_blocked": Callable(self, "_on_map_shortcut_blocked"),
	}
	for signal_name in connections:
		var callback := connections[signal_name] as Callable
		if map_controls.has_signal(signal_name) and not map_controls.is_connected(signal_name, callback):
			map_controls.connect(signal_name, callback)


func _configure_round_rewind_action(snapshot: Dictionary) -> void:
	var phase_is_battle := String(snapshot.get("phase", "")) == "battle"
	var rewind_state := Dictionary(snapshot.get("round_rewind", snapshot.get("roundRewind", {})))
	var can_rewind := phase_is_battle and bool(rewind_state.get("canRewind", false))
	map_bag_button.disabled = _battle_input_locked or not can_rewind
	if can_rewind:
		map_bag_button.tooltip_text = "回撤：恢复到第 %d 回合开始。（快捷键 B）" % int(rewind_state.get("targetRound", 0))
	else:
		map_bag_button.tooltip_text = "回撤：当前没有可回撤的上一回合。（快捷键 B）"


func _sync_map_controls(snapshot: Dictionary) -> void:
	if _assets != null and _assets.has_method("battle_background_key"):
		var map_id := String(_assets.call("battle_background_key", snapshot))
		if bool(map_controls.call("set_map_by_id", map_id)):
			_debug_map_index = int(map_controls.call("get_map_index"))
			_update_map_debug_button_label()
	_update_map_control_availability(snapshot)


func _update_map_control_availability(snapshot: Dictionary) -> void:
	var phase_is_battle := String(snapshot.get("phase", "")) == "battle"
	map_auto_arrange_button.disabled = _battle_input_locked or not phase_is_battle
	map_all_out_button.disabled = _battle_input_locked or not phase_is_battle
	var reset_state := Dictionary(Dictionary(snapshot.get("pet_reset", {})).get("player", {}))
	var reset_charges := int(reset_state.get("charges", 0))
	var rounds_until_next_charge := int(reset_state.get(
		"roundsUntilNextCharge",
		reset_state.get("cooldownRemaining", 0)
	))
	# Keep the reset control mouse-interactive while it is waiting for its
	# gameplay condition. Keyboard shortcuts already show pressed feedback in
	# this state; leaving the TextureButton disabled made mouse clicks appear
	# completely dead. The handler below still guards the semantic command.
	map_reset_button.disabled = _battle_input_locked or not phase_is_battle
	if map_controls.has_method("set_reset_charge_state"):
		map_controls.call(
			"set_reset_charge_state",
			reset_charges,
			rounds_until_next_charge
		)
	_configure_round_rewind_action(snapshot)


func _on_map_settings_requested() -> void:
	if _settings_menu_is_open():
		settings_menu.call("handle_cancel")
		GameLogScript.info("战斗按键/Esc", "已关闭战斗菜单")
	else:
		_close_secondary_interfaces()
		settings_menu.call("open_menu")
		GameLogScript.info("战斗按键/Esc", "已打开战斗菜单")


func _close_secondary_interfaces() -> void:
	if hud.has_method("close_attack_timeline"):
		hud.call("close_attack_timeline")
	if overlay.has_method("clear"):
		overlay.call("clear")


func _on_settings_menu_visibility_changed() -> void:
	if hud.has_method("set_attack_timeline_obscured"):
		hud.call("set_attack_timeline_obscured", settings_menu.visible)


func _on_map_attack_order_requested() -> void:
	if hud.has_method("toggle_attack_timeline"):
		hud.call("toggle_attack_timeline")
		var opened := bool(hud.call("debug_is_attack_timeline_open"))
		GameLogScript.info("战斗按键/Tab", "攻击顺序界面已%s" % ("打开" if opened else "关闭"))


func _on_map_bag_requested() -> void:
	if _battle_input_locked or map_bag_button.disabled:
		_on_map_shortcut_blocked("B", "BagButton")
		return
	var rewind_state := Dictionary(_last_snapshot.get("round_rewind", _last_snapshot.get("roundRewind", {})))
	GameLogScript.info("战斗按键/B", "已请求回撤到上一回合开始", {
		"目标回合": int(rewind_state.get("targetRound", 0)),
	})
	command_requested.emit({"type": "REWIND_TO_PREVIOUS_ROUND_START"})


func _on_map_speed_toggled(active: bool) -> void:
	_combat_speed_enabled = active
	_apply_combat_speed()
	GameLogScript.info("战斗按键/D", "二倍战斗速度已%s" % ("开启" if active else "关闭"), {
		"当前是否处于战斗演出": _battle_input_locked,
		"当前实际速度": Engine.time_scale,
	})


func _on_map_auto_arrange_requested() -> void:
	if _battle_input_locked or map_auto_arrange_button.disabled:
		return
	map_auto_arrange_button.disabled = true
	if hud.has_method("request_auto_arrange"):
		hud.call("request_auto_arrange")


func _on_map_reset_requested() -> void:
	if _battle_input_locked or map_reset_button.disabled:
		return
	var reset_state := Dictionary(Dictionary(_last_snapshot.get("pet_reset", {})).get("player", {}))
	if not bool(reset_state.get("eligible", false)):
		_on_map_shortcut_blocked("点击/R", "ResetButton")
		return
	GameLogScript.info("战斗按键/R", "已请求回溯我方精灵到本场战斗入场状态")
	command_requested.emit({"type": "RESET_PETS"})


func _on_map_all_out_requested() -> void:
	if _battle_input_locked or map_all_out_button.disabled:
		return
	GameLogScript.info("战斗按键/Space", "已请求全军出击")
	if hud.has_method("request_begin_turn"):
		hud.call("request_begin_turn")


func _on_map_shortcut_blocked(shortcut: String, button_name: String) -> void:
	var reason := "当前不可用"
	if _battle_input_locked:
		reason = "战斗演出正在进行"
	elif String(_last_snapshot.get("phase", "")) != "battle":
		reason = "当前不在战斗阶段"
	elif button_name == "ResetButton":
		var reset_state := Dictionary(Dictionary(_last_snapshot.get("pet_reset", {})).get("player", {}))
		var rounds_until_next_charge := int(reset_state.get(
			"roundsUntilNextCharge",
			reset_state.get("cooldownRemaining", 0)
		))
		reason = "回溯次数不足或使用条件未满足"
		GameLogScript.warning("战斗按键/%s" % shortcut, "按键未生效", {
			"原因": reason,
			"当前次数": int(reset_state.get("charges", 0)),
			"距下次充能回合": rounds_until_next_charge,
		})
		return
	elif button_name == "BagButton":
		reason = "当前没有可回撤的上一回合"
	GameLogScript.warning("战斗按键/%s" % shortcut, "按键未生效", {"原因": reason})


func _apply_combat_speed() -> void:
	Engine.time_scale = (
		FAST_BATTLE_SPEED
		if _battle_input_locked and _all_out_trace_active and _combat_speed_enabled
		else NORMAL_BATTLE_SPEED
	)


func _latest_command_type(snapshot: Dictionary) -> String:
	var command_log := Array(snapshot.get("command_log", snapshot.get("commandLog", [])))
	if command_log.is_empty():
		return ""
	var latest_value: Variant = command_log.back()
	if not (latest_value is Dictionary):
		return ""
	var latest := Dictionary(latest_value)
	var nested_value: Variant = latest.get("command", {})
	var nested := Dictionary(nested_value) if nested_value is Dictionary else {}
	return String(latest.get("type", nested.get("type", ""))).strip_edges().to_upper()


func _log_button_command_response(
	command: Dictionary,
	response: Dictionary,
	snapshot: Dictionary
) -> void:
	var command_type := String(command.get("type", "")).strip_edges().to_upper()
	if command_type not in ["RESET_PETS", "SET_SKILL_CONTROL_ORDER", "RUN_COMBAT_ROUND", "REWIND_TO_PREVIOUS_ROUND_START"]:
		return
	var result_value: Variant = response.get("result", {})
	var result := Dictionary(result_value) if result_value is Dictionary else {}
	var accepted := bool(response.get("accepted", false))
	var mock_noop := bool(result.get("mock_noop", false))
	var area: String = String({
		"RESET_PETS": "战斗按键/R",
		"SET_SKILL_CONTROL_ORDER": "战斗按键/Tab",
		"RUN_COMBAT_ROUND": "战斗按键/Space",
		"REWIND_TO_PREVIOUS_ROUND_START": "战斗按键/B",
	}.get(command_type, "战斗按键"))
	var message := "操作已生效"
	if mock_noop:
		message = "操作未执行：当前离线回放没有对应的正式操作结果"
	elif not accepted or not bool(result.get("ok", accepted)):
		message = "操作被拒绝"
	var context := {
		"命令": command_type,
		"正式接口已接受": accepted,
		"回合": int(snapshot.get("battle_round", snapshot.get("battleRound", 0))),
	}
	if command_type == "RESET_PETS":
		var reset_state := Dictionary(Dictionary(snapshot.get("pet_reset", {})).get("player", {}))
		context["当前次数"] = int(reset_state.get("charges", 0))
		context["距下次充能回合"] = int(reset_state.get(
			"roundsUntilNextCharge",
			reset_state.get("cooldownRemaining", 0)
		))
		context["当前可用"] = bool(reset_state.get("eligible", false))
	elif command_type == "REWIND_TO_PREVIOUS_ROUND_START":
		context["目标回合"] = int(result.get("targetRound", snapshot.get("battle_round", 0)))
	if mock_noop or not accepted:
		GameLogScript.warning(String(area), message, context)
	else:
		GameLogScript.info(String(area), message, context)


func _on_button_shortcut_hints_visibility_changed(hints_visible: bool) -> void:
	set_button_shortcut_hints_visible(hints_visible)
	button_shortcut_hints_visibility_changed.emit(hints_visible)


func _on_shortcut_bindings_changed(bindings: Dictionary) -> void:
	shortcut_bindings_changed.emit(bindings.duplicate(true))


func _on_map_debug_button_pressed() -> void:
	var map_ids := map_controls.call("get_map_ids") as PackedStringArray
	if map_ids.is_empty():
		return
	_debug_map_index = (_debug_map_index + 1) % map_ids.size()
	if not bool(map_controls.call("set_map_by_index", _debug_map_index)):
		return
	var texture := map_controls.call("get_map_texture") as Texture2D
	if texture != null and board.has_method("set_background_texture"):
		board.call("set_background_texture", texture)
	_update_map_debug_button_label()


func _update_map_debug_button_label() -> void:
	map_debug_button.text = "调试地图：%s" % String(map_controls.call("get_map_display_name"))


func _on_settings_session_operation_requested(
	operation: StringName,
	arguments: Dictionary
) -> void:
	session_operation_requested.emit(operation, arguments.duplicate(true))
