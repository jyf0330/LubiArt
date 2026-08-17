extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const DashboardScript := preload("res://core_ui/scripts/battle/prefabs/hud/battle_log_dashboard.gd")
const TEST_LOCAL_FILE := "user://smoke_battle_log_readability/latest_battle.txt"
const SAVED_LOCAL_FILE := "user://battle_logs/latest_battle.txt"

const SPECS := [
	{"key": "flare", "name": "焰牙", "element": "火", "hp": 46, "atk": 14, "shield": 0, "ap": 3, "move": 3, "shape": "01"},
	{"key": "tide", "name": "潮甲", "element": "水", "hp": 62, "atk": 8, "shield": 10, "ap": 3, "move": 3, "shape": "09"},
	{"key": "spark", "name": "迅雷", "element": "雷", "hp": 40, "atk": 12, "shield": 0, "ap": 5, "move": 5, "shape": "12"},
	{"key": "vine", "name": "藤阵", "element": "草", "hp": 50, "atk": 10, "shield": 4, "ap": 4, "move": 4, "shape": "16"},
]

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var keep_local_file := OS.get_cmdline_user_args().has("--keep-local-battle-file")
	var local_file_path := SAVED_LOCAL_FILE if keep_local_file else TEST_LOCAL_FILE
	var dashboard := DashboardScript.new()
	root.add_child(dashboard)
	await process_frame
	if not keep_local_file:
		dashboard.configure_local_file_for_test(TEST_LOCAL_FILE, true)
	var state := _mirror_state()
	_expect(state.dispatch({"type": "AUTO_POSITION_HEROES"}), "mirror fixture accepts formal auto position")
	var positioned_snapshot: Dictionary = state.snapshot()
	dashboard.render_snapshot(positioned_snapshot)
	var log_text := dashboard.get_node_or_null("Panel/Content/LogText") as RichTextLabel
	var title := dashboard.get_node_or_null("Panel/Content/Header/Title") as Label
	_expect(log_text != null and title != null, "dashboard creates readable text and title controls")
	if log_text == null or title == null:
		dashboard.queue_free()
		quit(1)
		return
	var positioned_text := log_text.get_parsed_text()
	var actual_moves := Array(Dictionary(positioned_snapshot.get("lastCommandResult", {})).get("moves", []))
	if actual_moves.is_empty():
		actual_moves = Array(Dictionary(Dictionary(positioned_snapshot.get("lastCommandResult", {})).get("plan", {})).get("moves", []))
	_expect(actual_moves.size() == SPECS.size(), "formal auto position returns one move for each mirrored player pet")
	for move_value in actual_moves:
		var move := Dictionary(move_value)
		var expected_move := "自动布置：%s从%s移动到%s" % [
			_unit_name(positioned_snapshot, String(move.get("unitId", move.get("unit_id", "")))),
			_position_text(Dictionary(move.get("from", {}))),
			_position_text(Dictionary(move.get("to", {}))),
		]
		_expect(positioned_text.contains(expected_move), "dashboard reads actual auto-position coordinates: %s" % expected_move)

	_expect(state.dispatch({"type": "RUN_COMBAT_ROUND"}), "mirror fixture executes the formal complete round")
	var round_snapshot: Dictionary = state.snapshot()
	dashboard.render_snapshot(round_snapshot)
	var round_text := log_text.get_parsed_text()
	_assert_trace_projection(round_snapshot, round_text)
	var local_text := FileAccess.get_file_as_string(local_file_path)
	_expect(local_text.contains("自动布置：焰牙从第6行第1列移动到"), "Debug local file retains actual automatic placement")
	_expect(local_text.contains("点伤害（生命") or local_text.contains("点伤害（护盾"), "Debug local file retains actual plain-language damage")
	_expect(local_text.find("自动布置：") < local_text.find("点伤害（"), "Debug local file is chronological instead of newest-first")
	_expect(title.text.begins_with("战斗过程 · 最新发生的在上面"), "dashboard title explains ordering in plain language")
	_expect(positioned_text.strip_edges() != "" and round_text.contains(positioned_text.split("\n")[0]), "complete scrollback retains automatic-placement details after a full round")
	_expect(not round_text.contains("R1C") and not round_text.contains("R2C") and not round_text.contains("HP "), "default player text contains no developer coordinate or HP abbreviations")
	_expect(not round_text.contains("触发第") and not positioned_text.contains("智能调整站位："), "default player text hides queue numbering and technical auto-position summary")

	var once_text := round_text
	dashboard.render_snapshot(state.snapshot())
	_expect(log_text.get_parsed_text() == once_text, "re-rendering the same Snapshot never duplicates structured lines")
	print("BATTLE_LOG_READABILITY_EXAMPLE_BEGIN")
	for line in positioned_text.split("\n"):
		print(String(line))
	print("--- 完整回合后的最新事件 ---")
	for line in round_text.split("\n").slice(0, mini(24, round_text.split("\n").size())):
		print(String(line))
	print("BATTLE_LOG_READABILITY_EXAMPLE_END")
	if OS.get_cmdline_user_args().has("--visible-hold"):
		dashboard.show()
		await process_frame
		await process_frame
		var screenshot_path := _argument_value("--screenshot=")
		if screenshot_path != "":
			var save_error := dashboard.get_viewport().get_texture().get_image().save_png(screenshot_path)
			_expect(save_error == OK, "visible dashboard screenshot is saved")
		print("BATTLE_LOG_READABILITY_VISIBLE_READY screenshot=%s" % screenshot_path)
		await create_timer(8.0).timeout
	dashboard.queue_free()
	if keep_local_file:
		print("BATTLE_LOG_LOCAL_FILE_SAVED path=%s" % ProjectSettings.globalize_path(local_file_path))
	else:
		_cleanup_local_file()
	if failed:
		quit(1)
		return
	print("SMOKE_BATTLE_LOG_READABILITY_OK")
	quit(0)


func _mirror_state() -> RefCounted:
	var state := StateScript.new()
	state.run_seed = "smoke-battle-log-readability"
	state.start_battle()
	var template := Dictionary(state.units[0]).duplicate(true)
	var player_templates := _team(template, StateScript.PLAYER)
	var enemy_templates := _team(template, StateScript.ENEMY)
	state.units = []
	for unit_value in player_templates:
		state.units.append(Dictionary(unit_value).duplicate(true))
	for unit_value in enemy_templates:
		state.units.append(Dictionary(unit_value).duplicate(true))
	state.battle_roster_templates = {
		StateScript.PLAYER: player_templates.duplicate(true),
		StateScript.ENEMY: enemy_templates.duplicate(true),
	}
	state.call("_initialize_skill_control_orders")
	state.ap = int(state.call("_player_round_action_budget"))
	state.pet_reset_charges = {StateScript.PLAYER: 0, StateScript.ENEMY: 0}
	state.pet_reset_next_charge_round = {StateScript.PLAYER: 999, StateScript.ENEMY: 999}
	state.pet_reset_eligible = {StateScript.PLAYER: false, StateScript.ENEMY: false}
	state.battle_trace.clear()
	state.log_lines.clear()
	return state


func _assert_trace_projection(snapshot: Dictionary, dashboard_text: String) -> void:
	var found_element := false
	var found_damage := false
	var found_skill := false
	for event_value in Array(snapshot.get("battleTrace", [])):
		var event := Dictionary(event_value)
		var event_type := String(event.get("type", ""))
		if event_type == "ELEMENT_APPLIED" and not found_element:
			var payload := Dictionary(event.get("payload", {}))
			var changes: Array[String] = []
			for target_value in Array(payload.get("targets", [])):
				changes.append("%s（+%d层）" % [
					_position_text(Dictionary(target_value)),
					maxi(1, int(payload.get("layers", 1))),
				])
			var expected_changes := "铺设%d层%s：%s" % [
				maxi(1, int(payload.get("layers", 1))),
				String(payload.get("element", "")),
				"、".join(changes),
			]
			_expect(not changes.is_empty() and dashboard_text.contains(expected_changes), "dashboard prints every actual ELEMENT_APPLIED target: %s" % expected_changes)
			found_element = true
		elif event_type == "DAMAGE_APPLIED" and not found_damage:
			var actor := Dictionary(event.get("actor", {}))
			var target := Dictionary(event.get("target", {}))
			var payload := Dictionary(event.get("payload", {}))
			var actor_text := "%s%s" % [_side_text(String(actor.get("side", ""))), String(actor.get("name", ""))]
			var target_text := "%s%s" % [_side_text(String(target.get("side", ""))), String(target.get("name", ""))]
			var values_text := "生命%d→%d" % [int(payload.get("hpFrom", 0)), int(payload.get("hpTo", 0))]
			_expect(dashboard_text.contains(actor_text) and dashboard_text.contains(target_text), "dashboard disambiguates mirrored same-name pets by side")
			_expect(dashboard_text.contains(values_text), "dashboard keeps authoritative damage before/after values")
			found_damage = true
		elif event_type == "SKILL_TRIGGERED" and not found_skill:
			var actor := Dictionary(event.get("actor", {}))
			var payload := Dictionary(event.get("payload", {}))
			var expected_skill := "%s%s发动技能【%s】" % [
				_side_text(String(actor.get("side", ""))),
				String(actor.get("name", "")),
				String(payload.get("skillName", "")),
			]
			_expect(dashboard_text.contains(expected_skill), "dashboard describes skill activation without queue numbering")
			found_skill = true
		elif event_type == "MOVE_MONSTER":
			var actor := Dictionary(event.get("actor", {}))
			var expected_move := "%s%s从%s移动到%s" % [
				_side_text(String(actor.get("side", ""))),
				String(actor.get("name", "")),
				_position_text(Dictionary(event.get("from", {}))),
				_position_text(Dictionary(event.get("to", {}))),
			]
			_expect(dashboard_text.contains(expected_move), "dashboard prints actual enemy movement in plain-language coordinates")
	_expect(found_element, "formal mirrored round emits ELEMENT_APPLIED trace data")
	_expect(found_damage, "formal mirrored round emits DAMAGE_APPLIED trace data")
	_expect(found_skill, "formal mirrored round emits player-readable skill trace data")


func _unit_name(snapshot: Dictionary, unit_id: String) -> String:
	for unit_value in Array(snapshot.get("units", [])):
		var unit := Dictionary(unit_value)
		if String(unit.get("id", "")) == unit_id:
			return String(unit.get("name", unit_id))
	return unit_id


func _position_text(position: Dictionary) -> String:
	return "第%d行第%d列" % [int(position.get("y", -1)) + 1, int(position.get("x", -1)) + 1]


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with(prefix):
			return String(argument).trim_prefix(prefix)
	return ""


func _cleanup_local_file() -> void:
	if FileAccess.file_exists(TEST_LOCAL_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_LOCAL_FILE))
	var directory := ProjectSettings.globalize_path(TEST_LOCAL_FILE).get_base_dir()
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)


func _side_text(side: String) -> String:
	return "我方" if side == StateScript.PLAYER else "敌方" if side == StateScript.ENEMY else ""


func _team(template: Dictionary, side: String) -> Array:
	var result: Array = []
	var xs := [0, 2, 4, 6] if side == StateScript.PLAYER else [1, 3, 5, 7]
	var y := 5 if side == StateScript.PLAYER else 1
	for index in range(SPECS.size()):
		var spec := Dictionary(SPECS[index])
		var unit := template.duplicate(true)
		unit["id"] = "%s_%s" % [side, String(spec["key"])]
		unit["pet_id"] = "mirror_%s" % String(spec["key"])
		unit["name"] = String(spec["name"])
		unit["side"] = side
		unit["x"] = xs[index]
		unit["y"] = y
		unit["hp"] = int(spec["hp"])
		unit["max_hp"] = int(spec["hp"])
		unit["maxHp"] = int(spec["hp"])
		unit["atk"] = int(spec["atk"])
		unit["def"] = 0
		unit["shield"] = int(spec["shield"])
		unit["starting_shield"] = int(spec["shield"])
		unit["ap"] = int(spec["ap"])
		unit["move_range"] = int(spec["move"])
		unit["moveRange"] = int(spec["move"])
		unit["attack_count"] = 1
		unit["base_layers"] = 1
		unit["element"] = String(spec["element"])
		unit["element_types"] = [String(spec["element"])]
		unit["secondary_elements"] = []
		unit["slot_elements"] = [String(spec["element"]), String(spec["element"]), String(spec["element"])]
		unit["shape_id"] = String(spec["shape"])
		unit["shape"] = "形状%s" % String(spec["shape"])
		unit["skills"] = ["skill_vanguard", "skill_flank"]
		unit["traits"] = []
		unit["mechanism_id"] = "none"
		unit["quality"] = "青铜"
		unit["slot_count"] = 3
		unit["action_slots_used"] = {}
		unit["has_attacked"] = false
		result.append(unit)
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_BATTLE_LOG_READABILITY_FAIL: %s" % message)
