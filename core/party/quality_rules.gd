extends RefCounted

## Pure quality naming, progression summaries, and economy values.

const ORDER := ["青铜", "白银", "黄金", "钻石"]
const KEYS := {
	"青铜": "bronze",
	"白银": "silver",
	"黄金": "gold",
	"钻石": "diamond",
	"bronze": "bronze",
	"silver": "silver",
	"gold": "gold",
	"diamond": "diamond"
}
const EVOLUTION_POINT_TOTALS := {
	"bronze": 0,
	"silver": 2,
	"gold": 5,
	"diamond": 9
}
const EVOLUTION_POINT_CATEGORIES := [
	{"id": "hp", "label": "生命进化点", "description": "增加 5~10 点生命值"},
	{"id": "attack", "label": "攻击进化点", "description": "增加 1 点攻击力"},
	{"id": "defense", "label": "防御进化点", "description": "增加 1 点防御力"},
	{"id": "element", "label": "元素进化点", "description": "本身已有的某个元素槽增加 1 层元素"}
]


static func normalize(quality: String, order: Array = ORDER) -> String:
	var text := quality.strip_edges()
	if text == "" or text == "bronze":
		return "青铜"
	if text == "silver":
		return "白银"
	if text == "gold":
		return "黄金"
	if text == "diamond":
		return "钻石"
	return text if order.has(text) else "青铜"


static func key(quality: String, order: Array = ORDER, keys: Dictionary = KEYS) -> String:
	return String(keys.get(normalize(quality, order), keys.get(quality.strip_edges(), "bronze")))


static func next(quality: String, order: Array = ORDER) -> String:
	var index := order.find(normalize(quality, order))
	return String(order[index + 1]) if index >= 0 and index < order.size() - 1 else ""


static func existing_category_hit_probability(existing_count: int, categories: Array) -> float:
	var count: int = clamp(existing_count, 0, categories.size())
	if count >= categories.size():
		return 1.0
	if count <= 0:
		return 0.0
	return 1.0 - pow(0.5, count)


static func known_categories(values: Array, categories: Array) -> Array:
	var seen := {}
	for raw in values:
		seen[String(raw)] = true
	var result: Array = []
	for row in categories:
		var category := String(Dictionary(row).get("id", ""))
		if seen.has(category):
			result.append(category)
	return result


static func summarize_evolution_points(points: Array) -> Dictionary:
	var summary := {
		"hp_bonus": 0,
		"attack_bonus": 0,
		"defense_bonus": 0,
		"element_layers": {}
	}
	var layers := {}
	for item in points:
		var point := Dictionary(item)
		match String(point.get("category", "")):
			"hp":
				summary["hp_bonus"] = int(summary["hp_bonus"]) + int(point.get("amount", 0))
			"attack":
				summary["attack_bonus"] = int(summary["attack_bonus"]) + 1
			"defense":
				summary["defense_bonus"] = int(summary["defense_bonus"]) + 1
			"element":
				var element := String(point.get("element", ""))
				if element != "":
					layers[element] = int(layers.get(element, 0)) + 1
	summary["element_layers"] = layers
	return summary


static func sell_value(quality: String, order: Array = ORDER) -> int:
	match normalize(quality, order):
		"青铜":
			return 2
		"白银":
			return 4
		"黄金":
			return 6
		"钻石":
			return 8
	return 1
