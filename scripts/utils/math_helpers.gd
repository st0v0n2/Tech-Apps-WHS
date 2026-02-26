class_name MathHelpers
extends RefCounted

## Returns true with given probability (0.0 to 1.0)
static func chance(probability: float) -> bool:
	return randf() < probability


## Linear interpolation between two values
static func lerp_value(a: float, b: float, t: float) -> float:
	return a + (b - a) * clampf(t, 0.0, 1.0)


## Clamp value between min and max
static func clamp_value(value: float, min_val: float, max_val: float) -> float:
	return max(min_val, min(max_val, value))
