extends RefCounted

## Runtime operation IDs are implemented by core/stats/operations plugins.
## FLAT_ADD_PER_STACK is a content adapter consumed by StatusService before the
## modifier reaches StatResolver.

const FLAT_ADD := "flat_add"
const PERCENT_ADD := "percent_add"
const MULTIPLIER := "multiplier"
const OVERRIDE := "override"
const CLAMP_MIN := "clamp_min"
const CLAMP_MAX := "clamp_max"
const FLAT_ADD_PER_STACK := "flat_add_per_stack"

const RUNTIME := [
	CLAMP_MAX,
	CLAMP_MIN,
	FLAT_ADD,
	MULTIPLIER,
	OVERRIDE,
	PERCENT_ADD,
]
const CONTENT_ADAPTERS := [FLAT_ADD_PER_STACK]
