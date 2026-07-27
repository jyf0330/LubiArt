extends RefCounted

## Pure labels and player feedback for the battle HUD.


func difficulty_label(difficulty: String) -> String:
	return "摆位难度：简单" if difficulty == "easy" else "摆位难度：普通"


func difficulty_tooltip() -> String:
	return "普通难度保持宠物原攻击方向；简单难度允许自动布置同时择优调整方向。"


func auto_position_feedback(snapshot: Dictionary, result: Dictionary) -> String:
	var difficulty_text := "简单" if String(snapshot.get("difficulty", "normal")) == "easy" else "普通"
	if not bool(result.get("ok", false)):
		return "%s摆位：失败" % difficulty_text
	var move_count := Array(result.get("moves", [])).size()
	return "%s摆位：已移动%d只" % [difficulty_text, move_count] if move_count > 0 else "%s摆位：当前已最优" % difficulty_text
