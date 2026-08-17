extends RefCounted

## Canonical element vocabulary and deterministic settlement presentation.
## ElementFieldService owns storage mutations; it deliberately does not own
## these domain rules.

const ACTIVE_ELEMENTS := ["无", "火", "水", "草", "雷", "冰", "地", "暗", "龙"]
const ALIASES := {
	"neutral": "无", "fire": "火", "water": "水", "grass": "草", "electric": "雷",
	"ice": "冰", "ground": "地", "earth": "地", "dark": "暗", "dragon": "龙",
	"风": "无", "wind": "无", "土": "地"
}
const SETTLEMENT_ELEMENTS := ACTIVE_ELEMENTS
const SETTLEMENT_DAMAGE_LABELS := {
	"无": "无相冲击",
	"火": "火爆",
	"水": "水击",
	"草": "草袭",
	"雷": "雷击",
	"冰": "冰裂",
	"地": "地崩",
	"暗": "暗蚀",
	"龙": "龙震"
}


static func active_elements() -> Array:
	return ACTIVE_ELEMENTS.duplicate()


static func canonical(value: String) -> String:
	var text := value.strip_edges()
	var element := String(ALIASES.get(text, text))
	return element if ACTIVE_ELEMENTS.has(element) else ""


static func empty_layers() -> Dictionary:
	var elements := {}
	for element in ACTIVE_ELEMENTS:
		elements[element] = 0
	return elements


static func normalize_layers(raw: Dictionary) -> Dictionary:
	var elements := empty_layers()
	for key in raw.keys():
		var element := canonical(String(key))
		if element != "":
			elements[element] = max(0, int(elements.get(element, 0)) + int(raw[key]))
	return elements


static func settlement_damage_label(element: String) -> String:
	return String(SETTLEMENT_DAMAGE_LABELS.get(element, element))
