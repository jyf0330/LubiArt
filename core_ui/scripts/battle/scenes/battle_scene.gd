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
const BattleCommandBuilderScript := preload("res://core_ui/scripts/battle/controllers/battle_command_builder.gd")
const BattleLogDashboardScript := preload("res://core_ui/scripts/battle/prefabs/hud/battle_log_dashboard.gd")
const BattleSnapshotView := preload("res://core_ui/scripts/battle/controllers/battle_snapshot_view.gd")
const GameLogScript := preload("res://core/logging/game_log.gd")
const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")
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

@onready var board: BattleBoard = $Board
@onready var vfx_host: BattleVfxController = $Board/VfxHost
@onready var hud: BattleHud = $Hud
@onready var overlay: BattleOverlay = $OverlayHost
@onready var settings_menu: BattleSettingsMenu = $OverlayHost/SettingsMenu
@onready var map_controls: BattleMapControls = $MapControls
@onready var map_debug_button: Button = $Hud/BattleActionPanel/Margin/Content/MapDebugButton
@onready var map_auto_arrange_button: TextureButton = $MapControls/AutoArrangeButton
@onready var map_reset_button: TextureButton = $MapControls/ResetButton
@onready var map_speed_button: TextureButton = $MapControls/SpeedButton
@onready var map_attack_order_button: TextureButton = $MapControls/AttackOrderButton
@onready var map_bag_button: TextureButton = $MapControls/BagButton
@onready var map_all_out_button: TextureButton = $MapControls/AllOutButton

var _assets: BattleAssetRegistry = null
var _trace_projection := BattleTraceProjectionScript.new()
var _commands := BattleCommandBuilderScript.new()
var _presented_snapshot: Dictionary = {}
var _rendered_trace_count := -1
var _pending_final_snapshot: Dictionary = {}
var _pending_enemy_move_final_cells := {}
var _battle_input_locked := false
var _last_snapshot: Dictionary = {}
var _debug_map_index := -1
var _combat_speed_enabled := false
var _all_out_trace_active := false
var _button_shortcut_hints_visible := true
var _log_dashboard: BattleLogDashboard = null


func _ready() -> void:
	_assets = BattleAssetRegistryScript.new()
	board.configure(_assets)
	overlay.configure(_assets)
	_log_dashboard = BattleLogDashboardScript.new()
	_log_dashboard.name = "BattleLogDashboard"
	overlay.add_child(_log_dashboard)
	_log_dashboard.close_requested.connect(_on_log_dashboard_close_requested)
	_log_dashboard.speed_toggled.connect(_on_log_dashboard_speed_toggled)
	_connect_command_source(board)
	_connect_command_source(hud)
	board.cell_detail_requested.connect(_on_cell_detail_requested)
	vfx_host.configure(board.get_node("CellHost"), board.get_node("UnitHost"), _assets)
	_connect_vfx_signal("pets_reset_reveal_requested", "_on_pets_reset_reveal_requested")
	_connect_vfx_signal("trace_sequence_started", "_on_trace_sequence_started")
	_connect_vfx_signal("trace_sequence_finished", "_on_trace_sequence_finished")
	_connect_vfx_signal("enemy_move_projection_requested", "_on_enemy_move_projection_requested")
	settings_menu.session_operation_requested.connect(_on_settings_session_operation_requested)
	settings_menu.configure_formal_session_mode()
	settings_menu.button_shortcut_hints_visibility_changed.connect(
		_on_button_shortcut_hints_visibility_changed
	)
	settings_menu.shortcut_bindings_changed.connect(_on_shortcut_bindings_changed)
	settings_menu.visibility_changed.connect(_on_settings_menu_visibility_changed)
	_connect_map_controls()
	var developer_tools_enabled := RuntimeUiPolicy.developer_tools_enabled()
	map_debug_button.visible = developer_tools_enabled
	if developer_tools_enabled:
		map_debug_button.pressed.connect(_on_map_debug_button_pressed)
	_configure_round_rewind_action({})
	set_button_shortcut_hints_visible(_button_shortcut_hints_visible)


func _exit_tree() -> void:
	# D 只允许影响战斗 Trace；离开战斗页时必须恢复全局正常速度。
	Engine.time_scale = NORMAL_BATTLE_SPEED


func get_runtime_view() -> Control:
	return self


func is_battle_input_locked() -> bool:
	return _battle_input_locked


func set_button_shortcut_hints_visible(hints_visible: bool) -> void:
	_button_shortcut_hints_visible = hints_visible
	map_controls.set_shortcut_hints_visible(hints_visible)
	settings_menu.set_button_shortcut_hints_visible(hints_visible)


func are_button_shortcut_hints_visible() -> bool:
	return _button_shortcut_hints_visible


func configure_trace_cursor(cursor: int) -> void:
	_rendered_trace_count = maxi(-1, cursor)


func get_trace_cursor() -> int:
	return _rendered_trace_count


func render_snapshot(snapshot: Dictionary) -> void:
	var incoming := snapshot.duplicate(true)
	# The page owns the one defensive copy. Children receive the same read-only
	# presentation snapshot instead of cloning the full trace and board again.
	_last_snapshot = incoming
	var new_events := _trace_projection.new_events(incoming, _rendered_trace_count)
	var stage_for_active_trace := not _presented_snapshot.is_empty() and (
		not new_events.is_empty()
		or not _pending_final_snapshot.is_empty()
		or _battle_input_locked
	)
	var final_cells := BattleSnapshotView.board_cells(incoming).duplicate(true)
	if stage_for_active_trace:
		_pending_final_snapshot = incoming
		_pending_enemy_move_final_cells.merge(
			_trace_projection.collect_enemy_move_final_cells(final_cells, new_events),
			true
		)
		_refresh_pending_enemy_move_final_cells(final_cells)
	else:
		_pending_final_snapshot = {}
		var visible_cells := final_cells.duplicate(true)
		_pending_enemy_move_final_cells.merge(
			_trace_projection.defer_enemy_move_projection(visible_cells, new_events),
			true
		)
		_commit_presentation_snapshot(
			incoming,
			visible_cells,
			_trace_projection.pending_reset_unit_ids(new_events)
		)
	if not new_events.is_empty():
		_all_out_trace_active = _latest_command_type(incoming) == "RUN_COMBAT_ROUND"
		_rendered_trace_count = BattleSnapshotView.trace_events(incoming).size()
		_set_battle_input_locked(true)
		play_battle_trace(new_events)
	elif _rendered_trace_count < 0:
		_rendered_trace_count = BattleSnapshotView.trace_events(incoming).size()


func render_command_response(command: Dictionary, response: Dictionary) -> void:
	hud.render_command_response(command, response)
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
	if vfx_host == null:
		GameLogScript.warning("表现/战斗事件", "VFX 不可用，直接应用最终快照")
		_apply_staged_final_snapshot()
		return
	vfx_host.play_trace(events)


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
	command_requested.emit(command.duplicate(true))


func _on_cell_detail_requested(grid: Vector2i, unit_id: String) -> void:
	if grid.x < 0 or grid.y < 0:
		overlay.clear()
		return
	overlay.request_detail(grid, unit_id)


func _on_enemy_move_projection_requested(event: Dictionary) -> void:
	var actor := Dictionary(event.get("actor", {}))
	var unit_id := String(event.get("unitId", actor.get("id", "")))
	var final_cell := Dictionary(_pending_enemy_move_final_cells.get(unit_id, {}))
	if unit_id == "" or final_cell.is_empty():
		return
	board.apply_enemy_move_final_cell(unit_id, final_cell)
	_pending_enemy_move_final_cells.erase(unit_id)


func _on_pets_reset_reveal_requested(units: Array) -> void:
	board.reveal_reset_units(units)


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
		var final_cells := BattleSnapshotView.board_cells(final_snapshot).duplicate(true)
		_commit_presentation_snapshot(final_snapshot, final_cells, {}, true)
	else:
		for unit_id_value in _pending_enemy_move_final_cells.keys():
			board.apply_enemy_move_final_cell(String(unit_id_value), Dictionary(_pending_enemy_move_final_cells[unit_id_value]))
	_pending_enemy_move_final_cells.clear()
	_set_battle_input_locked(false)
	trace_sequence_finished.emit()


func _commit_presentation_snapshot(
	snapshot: Dictionary,
	cells: Array,
	pending_reset_ids: Dictionary = {},
	reconcile_unit_presentation: bool = false
) -> void:
	board.render_snapshot(
		snapshot,
		cells,
		pending_reset_ids,
		reconcile_unit_presentation
	)
	hud.render_snapshot(snapshot)
	overlay.render_snapshot(snapshot)
	_log_dashboard.render_snapshot(snapshot)
	_sync_map_controls(snapshot)
	_presented_snapshot = snapshot


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
	board.set_input_locked(locked)
	hud.set_input_locked(locked)
	_update_map_control_availability(_last_snapshot)


func _input(event: InputEvent) -> void:
	if settings_menu != null and settings_menu.is_capturing_shortcut():
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
		if not pressed:
			map_controls.handle_shortcut_input(event, false)
		get_viewport().set_input_as_handled()
		return
	if _attack_timeline_is_open() and action_id in TIMELINE_MODAL_BLOCKED_SHORTCUTS:
		if not pressed:
			map_controls.handle_shortcut_input(event, false)
		get_viewport().set_input_as_handled()
		return
	if action_id not in [ShortcutCatalog.ACTION_SETTINGS, ShortcutCatalog.ACTION_ATTACK_ORDER]:
		return
	map_controls.handle_shortcut_input(event, false)
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
	return settings_menu != null and settings_menu.is_open()


func _attack_timeline_is_open() -> bool:
	return hud != null and hud.debug_is_attack_timeline_open()


func _connect_map_controls() -> void:
	var connections := {
		"settings_requested": Callable(self, "_on_map_settings_requested"),
		"attack_order_requested": Callable(self, "_on_map_attack_order_requested"),
		"bag_requested": Callable(self, "_on_map_bag_requested"),
		"auto_arrange_requested": Callable(self, "_on_map_auto_arrange_requested"),
		"reset_requested": Callable(self, "_on_map_reset_requested"),
		"log_requested": Callable(self, "_on_map_log_requested"),
		"all_out_requested": Callable(self, "_on_map_all_out_requested"),
		"shortcut_blocked": Callable(self, "_on_map_shortcut_blocked"),
	}
	for signal_name in connections:
		var callback := connections[signal_name] as Callable
		if map_controls.has_signal(signal_name) and not map_controls.is_connected(signal_name, callback):
			map_controls.connect(signal_name, callback)


func _configure_round_rewind_action(snapshot: Dictionary) -> void:
	var phase_is_battle := BattleSnapshotView.phase(snapshot) == "battle"
	var rewind_state := BattleSnapshotView.round_rewind_state(snapshot)
	var can_rewind := phase_is_battle and bool(rewind_state.get("canRewind", false))
	map_bag_button.disabled = _battle_input_locked or not can_rewind
	if can_rewind:
		map_bag_button.tooltip_text = "回撤：恢复到第 %d 回合开始。（快捷键 B）" % int(rewind_state.get("targetRound", 0))
	else:
		map_bag_button.tooltip_text = "回撤：当前没有可回撤的上一回合。（快捷键 B）"


func _sync_map_controls(snapshot: Dictionary) -> void:
	if _assets != null:
		var map_id := String(_assets.battle_background_key(snapshot))
		if map_controls.set_map_by_id(map_id):
			_debug_map_index = map_controls.get_map_index()
			if map_debug_button.visible:
				_update_map_debug_button_label()
	_update_map_control_availability(snapshot)


func _update_map_control_availability(snapshot: Dictionary) -> void:
	var phase_is_battle := BattleSnapshotView.phase(snapshot) == "battle"
	map_auto_arrange_button.disabled = _battle_input_locked or not phase_is_battle
	map_all_out_button.disabled = _battle_input_locked or not phase_is_battle
	map_attack_order_button.disabled = _battle_input_locked or not phase_is_battle
	var reset_state := BattleSnapshotView.player_reset_state(snapshot)
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
	map_controls.set_reset_charge_state(reset_charges, rounds_until_next_charge)
	_configure_round_rewind_action(snapshot)


func _on_map_settings_requested() -> void:
	if _settings_menu_is_open():
		settings_menu.handle_cancel()
		GameLogScript.info("战斗按键/Esc", "已关闭战斗菜单")
	else:
		_close_secondary_interfaces()
		settings_menu.open_menu()
		GameLogScript.info("战斗按键/Esc", "已打开战斗菜单")


func _close_secondary_interfaces() -> void:
	hud.close_attack_timeline()
	overlay.clear()
	if _log_dashboard != null:
		_log_dashboard.close()


func _on_settings_menu_visibility_changed() -> void:
	hud.set_attack_timeline_obscured(settings_menu.visible)


func _on_map_attack_order_requested() -> void:
	if _battle_input_locked or map_attack_order_button.disabled:
		return
	if _log_dashboard != null:
		_log_dashboard.close()
	hud.toggle_attack_timeline()
	var opened := hud.debug_is_attack_timeline_open()
	GameLogScript.info("战斗按键/Tab", "攻击顺序界面已%s" % ("打开" if opened else "关闭"))


func _on_map_bag_requested() -> void:
	if _battle_input_locked or map_bag_button.disabled:
		_on_map_shortcut_blocked("B", "BagButton")
		return
	var rewind_state := BattleSnapshotView.round_rewind_state(_last_snapshot)
	GameLogScript.info("战斗按键/B", "已请求回撤到上一回合开始", {
		"目标回合": int(rewind_state.get("targetRound", 0)),
	})
	command_requested.emit(_commands.build("REWIND_TO_PREVIOUS_ROUND_START", _last_snapshot))


func _on_map_log_requested() -> void:
	if _log_dashboard == null:
		return
	if not _log_dashboard.is_open():
		_close_secondary_interfaces()
	_log_dashboard.toggle()
	GameLogScript.info("战斗按键/D", "战斗日志看板已%s" % ("打开" if _log_dashboard.is_open() else "关闭"))


func _on_log_dashboard_close_requested() -> void:
	if _log_dashboard != null:
		_log_dashboard.close()


func _on_log_dashboard_speed_toggled(active: bool) -> void:
	_combat_speed_enabled = active
	_apply_combat_speed()
	GameLogScript.info("战斗日志看板", "二倍战斗速度已%s" % ("开启" if active else "关闭"), {
		"当前是否处于战斗演出": _battle_input_locked,
		"当前实际速度": Engine.time_scale,
	})


func _on_map_auto_arrange_requested() -> void:
	if _battle_input_locked or map_auto_arrange_button.disabled:
		return
	map_auto_arrange_button.disabled = true
	hud.request_auto_arrange()


func _on_map_reset_requested() -> void:
	if _battle_input_locked or map_reset_button.disabled:
		return
	var reset_state := BattleSnapshotView.player_reset_state(_last_snapshot)
	if not bool(reset_state.get("eligible", false)):
		_on_map_shortcut_blocked("点击/R", "ResetButton")
		return
	GameLogScript.info("战斗按键/R", "已请求回溯我方精灵到本场战斗入场状态")
	command_requested.emit(_commands.build("RESET_PETS", _last_snapshot))


func _on_map_all_out_requested() -> void:
	if _battle_input_locked or map_all_out_button.disabled:
		return
	GameLogScript.info("战斗按键/Space", "已请求全军出击")
	hud.request_begin_turn()


func _on_map_shortcut_blocked(shortcut: String, button_name: String) -> void:
	var reason := "当前不可用"
	if _battle_input_locked:
		reason = "战斗演出正在进行"
	elif BattleSnapshotView.phase(_last_snapshot) != "battle":
		reason = "当前不在战斗阶段"
	elif button_name == "ResetButton":
		var reset_state := BattleSnapshotView.player_reset_state(_last_snapshot)
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
	var command_log := BattleSnapshotView.command_log(snapshot)
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
	var map_ids := map_controls.get_map_ids()
	if map_ids.is_empty():
		return
	_debug_map_index = (_debug_map_index + 1) % map_ids.size()
	if not map_controls.set_map_by_index(_debug_map_index):
		return
	var texture := map_controls.get_map_texture()
	if texture != null:
		board.set_background_texture(texture)
	_update_map_debug_button_label()


func _update_map_debug_button_label() -> void:
	map_debug_button.text = "调试地图：%s" % map_controls.get_map_display_name()


func _on_settings_session_operation_requested(
	operation: StringName,
	arguments: Dictionary
) -> void:
	session_operation_requested.emit(operation, arguments.duplicate(true))
