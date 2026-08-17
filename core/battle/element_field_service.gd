extends RefCounted

## Owns deterministic element-field storage operations. Canonical element names
## and settlement effects remain supplied by the authoritative battle rules.


func elements_at(field: Dictionary, key: String, normalize: Callable) -> Dictionary:
	return Dictionary(normalize.call(Dictionary(field.get(key, {}))))


func add_to_field(field: Dictionary, key: String, element: String, layers: int, normalize: Callable) -> Dictionary:
	var elements := elements_at(field, key, normalize)
	elements[element] = int(elements.get(element, 0)) + max(1, layers)
	field[key] = elements
	return elements


func clear_from_field(field: Dictionary, key: String, element: String, normalize: Callable) -> Dictionary:
	var elements := elements_at(field, key, normalize)
	elements[element] = 0
	field[key] = elements
	return elements


func add_to_unit(unit: Dictionary, element: String, layers: int, normalize: Callable) -> Dictionary:
	var elements := Dictionary(normalize.call(Dictionary(unit.get("elements", {}))))
	elements[element] = int(elements.get(element, 0)) + max(1, layers)
	unit["elements"] = elements
	return elements


func clear_from_unit(unit: Dictionary, element: String, normalize: Callable) -> Dictionary:
	var elements := Dictionary(normalize.call(Dictionary(unit.get("elements", {}))))
	elements[element] = 0
	unit["elements"] = elements
	return elements


func has_active_element(elements: Dictionary) -> bool:
	for value in elements.values():
		if int(value) > 0:
			return true
	return false
