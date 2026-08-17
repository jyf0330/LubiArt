extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := StateScript.new()
	var requested_seed := _seed_from_args()
	if requested_seed != "":
		state.set_run_seed(requested_seed)
	var snapshot := state.snapshot()
	var plan := Dictionary(snapshot.get("run_plan", {}))
	if plan.is_empty():
		push_error("Run plan is empty.")
		quit(1)
		return
	var seed := String(snapshot.get("run_seed", plan.get("seed", "ysbzs-local")))
	var output_path := "res://output/run_plan_%s.md" % _safe_file_token(seed)
	var output_dir := ProjectSettings.globalize_path("res://output")
	var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if dir_error != OK:
		push_error("Could not create output directory: %s" % output_dir)
		quit(1)
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open output file: %s" % output_path)
		quit(1)
		return
	file.store_string(_build_markdown(snapshot, plan))
	file.close()
	print("RUN_PLAN_READABLE_OK %s" % output_path)
	quit(0)

func _seed_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--seed="):
			return text.substr("--seed=".length()).strip_edges()
	return ""

func _build_markdown(snapshot: Dictionary, plan: Dictionary) -> String:
	var entries := Array(plan.get("entries", []))
	var lines: Array[String] = []
	lines.append("# Run Plan")
	lines.append("")
	lines.append("- 种子：`%s`" % String(snapshot.get("run_seed", plan.get("seed", ""))))
	lines.append("- 计划哈希：`%s`" % String(snapshot.get("run_plan_hash", plan.get("plan_hash", ""))))
	lines.append("- 数据版本：`%s`" % String(plan.get("dataVersion", "")))
	lines.append("- 节点数：`%d`" % entries.size())
	lines.append("")
	lines.append("## 总览")
	lines.append("")
	lines.append("| 天 | 节点 | 日程 | 类型 | 选项 |")
	lines.append("|---:|---:|---|---|---|")
	for item in entries:
		var entry := Dictionary(item)
		var schedule := Dictionary(entry.get("schedule", {}))
		var options := Array(entry.get("options", []))
		lines.append("| %d | %d | %s | %s | %s |" % [
			int(entry.get("day", 0)),
			int(entry.get("step", 0)),
			_escape_cell(String(schedule.get("label", entry.get("id", "")))),
			_escape_cell(_kind_label(String(entry.get("kind", "")))),
			_escape_cell(_option_summary(options))
		])
	lines.append("")
	lines.append("## 详情")
	for item in entries:
		var entry := Dictionary(item)
		var schedule := Dictionary(entry.get("schedule", {}))
		var options := Array(entry.get("options", []))
		lines.append("")
		lines.append("### Day %d / Node %d：%s" % [
			int(entry.get("day", 0)),
			int(entry.get("step", 0)),
			String(schedule.get("label", entry.get("id", "")))
		])
		lines.append("")
		lines.append("- 类型：%s" % _kind_label(String(entry.get("kind", ""))))
		lines.append("- 日程ID：`%s`" % String(schedule.get("id", entry.get("id", ""))))
		lines.append("- 日程说明：%s" % _empty_dash(String(schedule.get("note", ""))))
		lines.append("")
		lines.append("| 序号 | 选项ID | 类型 | 标题 | 说明 | 来源 |")
		lines.append("|---:|---|---|---|---|---|")
		for index in range(options.size()):
			var option := Dictionary(options[index])
			lines.append("| %d | `%s` | %s | %s | %s | %s |" % [
				index + 1,
				String(option.get("optionId", option.get("id", ""))),
				_escape_cell(_kind_label(String(option.get("kind", "")))),
				_escape_cell(String(option.get("title", option.get("id", "")))),
				_escape_cell(_empty_dash(String(option.get("desc", "")))),
				_escape_cell(_option_source(option))
			])
	lines.append("")
	return "\n".join(lines)

func _option_summary(options: Array) -> String:
	var parts: Array[String] = []
	for item in options:
		var option := Dictionary(item)
		parts.append("%s: %s" % [
			_kind_label(String(option.get("kind", ""))),
			String(option.get("title", option.get("id", "")))
		])
	return " / ".join(parts)

func _option_source(option: Dictionary) -> String:
	var node_id := String(option.get("nodeId", ""))
	if node_id != "":
		return "nodeId `%s`" % node_id
	var encounter_id := String(option.get("encounterId", ""))
	if encounter_id != "":
		return "encounterId `%s`" % encounter_id
	return "`%s`" % String(option.get("id", ""))

func _kind_label(kind: String) -> String:
	match kind:
		"node_choice":
			return "3选1节点"
		"battle_choice":
			return "战斗3选1"
		"fixed_battle":
			return "固定战斗"
		"reward":
			return "奖励"
		"shop":
			return "商店"
		"event":
			return "事件"
		"battle":
			return "战斗"
		_:
			return kind if kind != "" else "-"

func _escape_cell(value: String) -> String:
	return _empty_dash(value).replace("|", "\\|").replace("\n", "<br>")

func _empty_dash(value: String) -> String:
	var text := value.strip_edges()
	return text if text != "" else "-"

func _safe_file_token(value: String) -> String:
	var token := ""
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			token += value.substr(index, 1)
		elif code == 45 or code == 95:
			token += value.substr(index, 1)
		else:
			token += "_"
	if token.strip_edges() == "":
		return "seed"
	return token
