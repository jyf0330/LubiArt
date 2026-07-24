extends RefCounted

## Pure route ViewModel/command adapter. Rendering remains in the authored view.


func options(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("route_options", [])).duplicate(true)


func choose_command(option: Dictionary, kind: String) -> Dictionary:
	return {
		"type": "CHOOSE_ROUTE",
		"option_id": String(option.get("id", "")),
		"kind": kind,
	}
