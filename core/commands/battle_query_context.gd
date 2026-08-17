extends RefCounted

## Immutable-by-convention value context for battle projections. build() creates
## a deep value copy; validate() rejects incomplete or authority-bearing values.

const SCHEMA := "ysbzs.battle-query-context.v1"
const REQUIRED_KEYS: Array[String] = [
	"phase",
	"stateVersion",
	"battleRound",
	"difficulty",
	"board",
	"selection",
	"units",
	"defeatedUnits",
	"leaders",
	"cellElements",
	"boardTraces",
	"actionDirections",
	"actionApChoices",
	"placementDamageByUnit",
	"gameData",
]


static func build(values: Dictionary) -> Dictionary:
	return {
		"schema": SCHEMA,
		"phase": String(values.get("phase", "")),
		"stateVersion": int(values.get("stateVersion", 0)),
		"battleRound": int(values.get("battleRound", 0)),
		"difficulty": String(values.get("difficulty", "")),
		"board": Dictionary(values.get("board", {})).duplicate(true),
		"selection": Dictionary(values.get("selection", {})).duplicate(true),
		"units": Array(values.get("units", [])).duplicate(true),
		"defeatedUnits": Array(values.get("defeatedUnits", [])).duplicate(true),
		"leaders": Dictionary(values.get("leaders", {})).duplicate(true),
		"cellElements": Dictionary(values.get("cellElements", {})).duplicate(true),
		"boardTraces": Dictionary(values.get("boardTraces", {})).duplicate(true),
		"actionDirections": Dictionary(values.get("actionDirections", {})).duplicate(true),
		"actionApChoices": Dictionary(values.get("actionApChoices", {})).duplicate(true),
		"placementDamageByUnit": Dictionary(values.get("placementDamageByUnit", {})).duplicate(true),
		"gameData": Dictionary(values.get("gameData", {})).duplicate(true),
	}


static func validate(context: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_KEYS:
		if not context.has(key):
			errors.append("BATTLE_QUERY_CONTEXT_MISSING:%s" % key)
	var board_value: Variant = context.get("board")
	if typeof(board_value) != TYPE_DICTIONARY:
		errors.append("BATTLE_QUERY_BOARD_INVALID")
	else:
		var board := Dictionary(board_value)
		if int(board.get("width", 0)) <= 0 or int(board.get("height", 0)) <= 0:
			errors.append("BATTLE_QUERY_BOARD_INVALID")
	if _contains_forbidden_value(context):
		errors.append("BATTLE_QUERY_CONTEXT_FORBIDDEN_VALUE")
	return errors


static func _contains_forbidden_value(value: Variant) -> bool:
	if value is Callable or value is Object:
		return true
	if typeof(value) == TYPE_ARRAY:
		for item in Array(value):
			if _contains_forbidden_value(item):
				return true
	elif typeof(value) == TYPE_DICTIONARY:
		for item in Dictionary(value).values():
			if _contains_forbidden_value(item):
				return true
	return false
