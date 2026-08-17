extends RefCounted

## Pure semantic accessors for skill execution. Shape definitions own only
## geometry; skill definitions/effects own which direction slot is selected and
## how often an effect is applied. Legacy field names remain readable while
## authored content migrates.

const DEFAULT_ACTION_SLOT_INDEX := 0
const DEFAULT_APPLICATION_COUNT := 1


static func action_slot_index(definition: Dictionary) -> int:
	if definition.has("action_slot_index"):
		return max(0, int(definition.get("action_slot_index", DEFAULT_ACTION_SLOT_INDEX)))
	return max(0, int(definition.get("shape_slot", DEFAULT_ACTION_SLOT_INDEX)))


static func physical_strike_count(definition: Dictionary, effect: Dictionary) -> int:
	if effect.has("strike_count"):
		return max(1, int(effect.get("strike_count", DEFAULT_APPLICATION_COUNT)))
	if effect.has("repeat_count"):
		return max(1, int(effect.get("repeat_count", DEFAULT_APPLICATION_COUNT)))
	if definition.has("strike_count"):
		return max(1, int(definition.get("strike_count", DEFAULT_APPLICATION_COUNT)))
	return max(1, int(definition.get("repeat_count", DEFAULT_APPLICATION_COUNT)))


static func legacy_action_strike_count(unit: Dictionary, shape_definition: Dictionary) -> int:
	if unit.has("action_strike_count"):
		return max(1, int(unit.get("action_strike_count", DEFAULT_APPLICATION_COUNT)))
	# Compatibility boundary for authored shape data. No attack option or formal
	# skill consumes this legacy field directly.
	return max(1, int(shape_definition.get("settle_count", DEFAULT_APPLICATION_COUNT)))


static func element_application_count(effect: Dictionary) -> int:
	return max(1, int(effect.get("application_count", DEFAULT_APPLICATION_COUNT)))
