extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var _failed := false


func _init() -> void:
	var state = StateScript.new()
	_expect(bool(state.call("is_initialized")), "production state initializes from the formal content pack")
	var roster := Array(state.get("roster"))
	_expect(roster.size() == 1, "production startup keeps only the one upstream-enabled initial pet")
	if roster.size() == 1:
		var pet := Dictionary(roster[0])
		_expect(String(pet.get("id", "")) == "pal_002", "production startup keeps the upstream pal_002 starter")
		_expect(String(pet.get("name", "")) == "灰尾狸", "production startup uses the current exported starter identity")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
