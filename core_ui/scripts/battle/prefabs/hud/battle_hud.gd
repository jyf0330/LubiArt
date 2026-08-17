extends Control
class_name BattleHud

## Authored battle HUD responsibility root. It consumes public Snapshots and
## emits semantic command requests; Game remains the only Session owner.

signal command_requested(command: Dictionary)

const BattleHudControllerScript := preload("res://core_ui/scripts/battle/controllers/battle_hud_controller.gd")
const BattleCommandBuilderScript := preload("res://core_ui/scripts/battle/controllers/battle_command_builder.gd")
const BattleSnapshotView := preload("res://core_ui/scripts/battle/controllers/battle_snapshot_view.gd")
const GameLogScript := preload("res://core/logging/game_log.gd")
const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")

@onready var auto_arrange_button: TextureButton = $BattlePrimaryActions/AutoArrangeButton
@onready var position_difficulty_button: Button = $BattleActionPanel/Margin/Content/PositionDifficultyButton
@onready var begin_turn_button: TextureButton = $BattlePrimaryActions/BeginTurnButton
@onready var action_panel: Control = $BattleActionPanel
@onready var debug_drawer_toggle_button: Button = $DebugDrawerToggleButton
@onready var attack_timeline_layer: CanvasLayer = $AttackTimelineLayer
@onready var attack_timeline: Control = $AttackTimelineLayer/AttackTimeline

const DEBUG_DRAWER_EXPANDED_PANEL_POSITION := Vector2(18.0, 150.0)
const DEBUG_DRAWER_COLLAPSED_PANEL_POSITION := Vector2(-462.0, 150.0)
const DEBUG_DRAWER_EXPANDED_TOGGLE_POSITION := Vector2(480.0, 174.0)
const DEBUG_DRAWER_COLLAPSED_TOGGLE_POSITION := Vector2(0.0, 174.0)
const DEBUG_DRAWER_TWEEN_DURATION := 0.18

var _snapshot: Dictionary = {}
var _input_locked := false
var _auto_position_feedback_pending := false
var _auto_position_feedback_visible := false
var _pending_state_version := -1
var _pending_command_log_size := -1
var _position_feedback_serial := 0
var _debug_drawer_collapsed := false
var _debug_drawer_tween: Tween = null
var _attack_timeline_obscured := false
var _hud_controller: RefCounted = BattleHudControllerScript.new()
var _command_builder := BattleCommandBuilderScript.new()


func _ready() -> void:
	RuntimeUiPolicy.install()
	auto_arrange_button.pressed.connect(_on_auto_arrange_pressed)
	position_difficulty_button.toggled.connect(_on_position_difficulty_toggled)
	begin_turn_button.pressed.connect(_on_begin_turn_pressed)
	debug_drawer_toggle_button.pressed.connect(_on_debug_drawer_toggle_pressed)
	if action_panel.has_signal("command_requested"):
		action_panel.connect("command_requested", Callable(self, "_on_child_command_requested"))
	if attack_timeline.has_signal("command_requested"):
		attack_timeline.connect("command_requested", Callable(self, "_on_child_command_requested"))
	if attack_timeline.has_signal("close_requested"):
		attack_timeline.connect("close_requested", Callable(self, "close_attack_timeline"))
	attack_timeline.visible = false
	visibility_changed.connect(_sync_attack_timeline_layer_visibility)
	_sync_attack_timeline_layer_visibility()
	_apply_position_difficulty_label("normal")
	_refresh_debug_drawer_toggle()
	_apply_command_availability()


func render_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	if action_panel.has_method("render_snapshot"):
		action_panel.call("render_snapshot", _snapshot)
	debug_drawer_toggle_button.visible = action_panel.visible
	if attack_timeline.has_method("render_snapshot"):
		attack_timeline.call("render_snapshot", _snapshot)
	if _auto_position_feedback_pending:
		_consume_auto_position_feedback(_snapshot)
	elif not _auto_position_feedback_visible:
		_apply_position_difficulty_label(String(_snapshot.get("difficulty", "normal")))
	_apply_command_availability()


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if action_panel.has_method("set_input_locked"):
		action_panel.call("set_input_locked", locked)
	if attack_timeline.has_method("set_interaction_locked"):
		attack_timeline.call("set_interaction_locked", locked)
	_apply_command_availability()


func render_command_response(command: Dictionary, response: Dictionary) -> void:
	if _command_type(command) != "AUTO_POSITION_HEROES" \
			or not _auto_position_feedback_pending:
		return
	var response_snapshot_value: Variant = response.get("snapshot", {})
	var response_snapshot := (
		Dictionary(response_snapshot_value).duplicate(true)
		if response_snapshot_value is Dictionary and not Dictionary(response_snapshot_value).is_empty()
		else _snapshot.duplicate(true)
	)
	var result_value: Variant = response.get("result", {})
	var result := (
		Dictionary(result_value).duplicate(true)
		if result_value is Dictionary
		else {}
	)
	var feedback_text := ""
	if bool(result.get("mock_noop", false)):
		feedback_text = String(_hud_controller.call(
			"auto_position_skipped_feedback",
			response_snapshot
		))
		_complete_auto_position_feedback(
			response_snapshot,
			result,
			feedback_text,
			"未执行"
		)
		return
	if not result.has("ok"):
		result["ok"] = (
			bool(response.get("accepted", false))
			and bool(response.get("ok", response.get("accepted", false)))
		)
	feedback_text = String(_hud_controller.call(
		"auto_position_feedback",
		response_snapshot,
		result
	))
	_complete_auto_position_feedback(response_snapshot, result, feedback_text)


func _on_auto_arrange_pressed() -> void:
	if _input_locked or _auto_position_feedback_pending or not _phase_is_battle():
		GameLogScript.warning("表现/自动布置", "点击未发送：当前已有操作处理中", {
			"输入锁定": _input_locked,
			"正在计算": _auto_position_feedback_pending,
		})
		return
	_auto_position_feedback_pending = true
	_auto_position_feedback_visible = false
	_pending_state_version = _snapshot_state_version(_snapshot)
	_pending_command_log_size = _snapshot_command_log(_snapshot).size()
	_position_feedback_serial += 1
	position_difficulty_button.text = RuntimeUiPolicy.text("UI_POSITION_CALCULATING")
	auto_arrange_button.modulate = Color("#fff0ad")
	var pulse := create_tween()
	pulse.tween_property(auto_arrange_button, "modulate", Color.WHITE, 0.35)
	_apply_command_availability()
	GameLogScript.info("表现/自动布置", "玩家点击自动布置，界面进入计算状态", {
		"难度": String(_snapshot.get("difficulty", "normal")),
		"回合": BattleSnapshotView.battle_round(_snapshot),
		"基线版本": _pending_state_version,
		"基线命令数": _pending_command_log_size,
	})
	_request_auto_position.call_deferred()


func _request_auto_position() -> void:
	if not _auto_position_feedback_pending:
		return
	if _input_locked:
		_cancel_auto_position_request("延迟发送前发现输入已锁定，取消本次请求")
		return
	var command := Dictionary(_command_builder.call(
		"build",
		"AUTO_POSITION_HEROES",
		_snapshot
	))
	if command.is_empty():
		_cancel_auto_position_request("自动布置命令构造失败，取消本次请求")
		return
	GameLogScript.debug("表现/自动布置", "向核心发送自动布置命令")
	command_requested.emit(command)


func _cancel_auto_position_request(message: String) -> void:
	_auto_position_feedback_pending = false
	_pending_state_version = -1
	_pending_command_log_size = -1
	_apply_position_difficulty_label(String(_snapshot.get("difficulty", "normal")))
	_apply_command_availability()
	GameLogScript.warning("表现/自动布置", message)


func _consume_auto_position_feedback(snapshot: Dictionary) -> void:
	if not _auto_position_feedback_pending:
		return
	var incoming_version := _snapshot_state_version(snapshot)
	var command_log := _snapshot_command_log(snapshot)
	if incoming_version <= _pending_state_version \
			or command_log.size() <= _pending_command_log_size:
		return
	var completed := Dictionary(command_log.back())
	if _command_type(completed) != "AUTO_POSITION_HEROES":
		return
	var result_value: Variant = snapshot.get(
		"lastCommandResult",
		snapshot.get("last_command_result", {})
	)
	if not (result_value is Dictionary) or not Dictionary(result_value).has("ok"):
		return
	var result := Dictionary(result_value).duplicate(true)
	var feedback_text := String(_hud_controller.call(
		"auto_position_feedback",
		snapshot,
		result
	))
	_complete_auto_position_feedback(snapshot, result, feedback_text)


func _complete_auto_position_feedback(
	snapshot: Dictionary,
	result: Dictionary,
	feedback_text: String,
	outcome: String = ""
) -> void:
	_auto_position_feedback_pending = false
	_pending_state_version = -1
	_pending_command_log_size = -1
	var difficulty := String(snapshot.get("difficulty", "normal"))
	GameLogScript.info("表现/自动布置", "核心结果已显示给玩家", {
		"结果": outcome if not outcome.is_empty() else (
			"成功" if bool(result.get("ok", false)) else "失败"
		),
		"提示": feedback_text,
		"移动宠物": Array(result.get("moves", [])).size(),
		"难度": difficulty,
	})
	_show_auto_position_feedback(feedback_text, difficulty)


func _show_auto_position_feedback(text: String, difficulty: String) -> void:
	_position_feedback_serial += 1
	var serial := _position_feedback_serial
	_auto_position_feedback_visible = true
	position_difficulty_button.text = text
	position_difficulty_button.modulate = Color("#d9ffc9")
	var fade := create_tween()
	fade.tween_property(position_difficulty_button, "modulate", Color.WHITE, 0.45)
	_apply_command_availability()
	await get_tree().create_timer(3.0, true, false, true).timeout
	if serial != _position_feedback_serial or not is_inside_tree():
		return
	_auto_position_feedback_visible = false
	_apply_position_difficulty_label(String(_snapshot.get("difficulty", difficulty)))
	_apply_command_availability()


func _on_position_difficulty_toggled(use_easy: bool) -> void:
	if _input_locked or _auto_position_feedback_pending or not _phase_is_battle():
		_apply_position_difficulty_label(String(_snapshot.get("difficulty", "normal")))
		return
	_position_feedback_serial += 1
	_auto_position_feedback_visible = false
	var difficulty := "easy" if use_easy else "normal"
	_apply_position_difficulty_label(difficulty)
	command_requested.emit(_command_builder.set_difficulty(difficulty))


func _on_debug_drawer_toggle_pressed() -> void:
	_set_debug_drawer_collapsed(not _debug_drawer_collapsed)


func _set_debug_drawer_collapsed(collapsed: bool, animate: bool = true) -> void:
	_debug_drawer_collapsed = collapsed
	if _debug_drawer_tween != null and _debug_drawer_tween.is_valid():
		_debug_drawer_tween.kill()
	var panel_target := (
		DEBUG_DRAWER_COLLAPSED_PANEL_POSITION
		if collapsed
		else DEBUG_DRAWER_EXPANDED_PANEL_POSITION
	)
	var toggle_target := (
		DEBUG_DRAWER_COLLAPSED_TOGGLE_POSITION
		if collapsed
		else DEBUG_DRAWER_EXPANDED_TOGGLE_POSITION
	)
	if animate and is_inside_tree():
		_debug_drawer_tween = create_tween().set_parallel(true)
		_debug_drawer_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_debug_drawer_tween.tween_property(
			action_panel,
			"position",
			panel_target,
			DEBUG_DRAWER_TWEEN_DURATION
		)
		_debug_drawer_tween.tween_property(
			debug_drawer_toggle_button,
			"position",
			toggle_target,
			DEBUG_DRAWER_TWEEN_DURATION
		)
	else:
		action_panel.position = panel_target
		debug_drawer_toggle_button.position = toggle_target
	_refresh_debug_drawer_toggle()


func _refresh_debug_drawer_toggle() -> void:
	debug_drawer_toggle_button.text = "›" if _debug_drawer_collapsed else "‹"
	debug_drawer_toggle_button.tooltip_text = (
		"展开调试菜单" if _debug_drawer_collapsed else "收起调试菜单"
	)


func _on_begin_turn_pressed() -> void:
	if _input_locked or not _phase_is_battle():
		return
	command_requested.emit(_command_builder.build("RUN_COMBAT_ROUND", _snapshot))


func request_auto_arrange() -> void:
	_on_auto_arrange_pressed()


func request_begin_turn() -> void:
	_on_begin_turn_pressed()


func _on_child_command_requested(command: Dictionary) -> void:
	if _input_locked or not _phase_is_battle() or command.is_empty():
		return
	command_requested.emit(command.duplicate(true))


func _apply_position_difficulty_label(difficulty: String) -> void:
	var normalized := "easy" if difficulty == "easy" else "normal"
	position_difficulty_button.set_pressed_no_signal(normalized == "easy")
	position_difficulty_button.text = String(_hud_controller.call(
		"difficulty_label",
		normalized
	))
	position_difficulty_button.tooltip_text = String(_hud_controller.call(
		"difficulty_tooltip"
	))


func _apply_command_availability() -> void:
	if not is_node_ready():
		return
	var phase_is_battle := _phase_is_battle()
	auto_arrange_button.disabled = (
		_input_locked or _auto_position_feedback_pending or not phase_is_battle
	)
	position_difficulty_button.disabled = (
		_input_locked or _auto_position_feedback_pending or not phase_is_battle
	)
	begin_turn_button.disabled = _input_locked or not phase_is_battle


func _snapshot_state_version(snapshot: Dictionary) -> int:
	return BattleSnapshotView.state_version(snapshot)


func _phase_is_battle() -> bool:
	return BattleSnapshotView.phase(_snapshot) == "battle"


func _snapshot_command_log(snapshot: Dictionary) -> Array:
	return BattleSnapshotView.command_log(snapshot)


func _command_type(entry: Dictionary) -> String:
	var command_value: Variant = entry.get("command", {})
	var nested := Dictionary(command_value) if command_value is Dictionary else {}
	return String(entry.get("type", nested.get("type", ""))).strip_edges().to_upper()


func get_attack_timeline() -> Control:
	return attack_timeline


func toggle_attack_timeline() -> void:
	_toggle_attack_timeline()


func close_attack_timeline() -> void:
	attack_timeline.visible = false


func set_attack_timeline_obscured(obscured: bool) -> void:
	_attack_timeline_obscured = obscured
	_sync_attack_timeline_layer_visibility()


func _toggle_attack_timeline() -> void:
	# The legacy action HUD can be hidden while its authored CanvasLayer remains
	# the public attack-order overlay used by MapControls/Tab.
	if not is_inside_tree() or _input_locked:
		return
	attack_timeline.visible = not attack_timeline.visible
	_sync_attack_timeline_layer_visibility()


func _sync_attack_timeline_layer_visibility() -> void:
	var timeline_host_available := is_inside_tree()
	attack_timeline_layer.visible = timeline_host_available and not _attack_timeline_obscured
	if not timeline_host_available:
		attack_timeline.visible = false


func debug_is_attack_timeline_open() -> bool:
	return attack_timeline.visible


func debug_is_action_panel_collapsed() -> bool:
	return _debug_drawer_collapsed
