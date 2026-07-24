extends RefCounted

## Mock-side Abstract Factory. It preserves the same composition seam as the
## production project while creating only the standalone JSON-backed session.

const MockGameSessionScript := preload("res://session/mock_game_session.gd")
const BoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")


static func create_local(options: Dictionary = {}) -> RefCounted:
	return MockGameSessionScript.new(options)


static func wrap_local_authority(_authority: RefCounted) -> RefCounted:
	return MockGameSessionScript.new()


static func command_line_board_dimensions(args: PackedStringArray = OS.get_cmdline_user_args()) -> Vector2i:
	for arg_value in args:
		var arg := String(arg_value).strip_edges()
		if not arg.begins_with("--board=") and not arg.begins_with("--board-size="):
			continue
		var raw := arg.split("=", false, 1)[1].to_lower().replace("×", "x")
		var parts := raw.split("x", false)
		if parts.size() == 2:
			return BoardDimensionsScript.normalized(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO
