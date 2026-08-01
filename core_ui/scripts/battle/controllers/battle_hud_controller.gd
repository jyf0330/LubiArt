extends RefCounted

## Pure labels and player feedback for the battle HUD.

const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")


func difficulty_label(difficulty: String) -> String:
	var key := "UI_DIFFICULTY_EASY" if difficulty == "easy" else "UI_DIFFICULTY_NORMAL"
	return RuntimeUiPolicy.text("UI_DIFFICULTY_LABEL", [RuntimeUiPolicy.text(key)])


func difficulty_tooltip() -> String:
	return RuntimeUiPolicy.text("UI_DIFFICULTY_TOOLTIP")


func auto_position_feedback(snapshot: Dictionary, result: Dictionary) -> String:
	var difficulty_text := RuntimeUiPolicy.text("UI_DIFFICULTY_EASY" if String(snapshot.get("difficulty", "normal")) == "easy" else "UI_DIFFICULTY_NORMAL")
	if not bool(result.get("ok", false)):
		return RuntimeUiPolicy.text("UI_POSITION_FAILED", [difficulty_text])
	var move_count := Array(result.get("moves", [])).size()
	return RuntimeUiPolicy.text("UI_POSITION_MOVED", [difficulty_text, move_count]) if move_count > 0 else RuntimeUiPolicy.text("UI_POSITION_OPTIMAL", [difficulty_text])
