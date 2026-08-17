extends RefCounted

## Pure triangular element-settlement damage. Mechanic lookup remains with the
## catalog owner; callers pass only the already-resolved ignite modifier.


static func damage(layers: int, ignite_bonus: bool = false, per_layer: int = 1) -> int:
	var normalized_layers: int = max(0, layers)
	var result: int = int((normalized_layers * (normalized_layers + 1)) / 2)
	if ignite_bonus:
		result += normalized_layers * per_layer
	return result
