## StatusEffectManager — tracks and ticks active status effects on a unit.
## Attach one instance per Unit node; call tick(delta) each battle tick.
class_name StatusEffectManager
extends RefCounted

# Effect entry: { id, value, duration_remaining, source_unit_id }
var _effects: Array = []

## Add or refresh a status effect. If same id exists, refreshes duration.
func apply(effect_id: String, value: float, duration: float, source_id: String = "") -> void:
	for effect in _effects:
		if effect["id"] == effect_id:
			effect["duration_remaining"] = duration
			effect["value"] = value
			return
	_effects.append({
		"id": effect_id,
		"value": value,
		"duration_remaining": duration,
		"source_id": source_id
	})

func remove(effect_id: String) -> void:
	_effects = _effects.filter(func(e): return e["id"] != effect_id)

func has_effect(effect_id: String) -> bool:
	for e in _effects:
		if e["id"] == effect_id:
			return true
	return false

func get_value(effect_id: String, default: float = 0.0) -> float:
	for e in _effects:
		if e["id"] == effect_id:
			return float(e["value"])
	return default

## Tick effects, reducing duration. Returns Array of expired effect ids.
func tick(delta: float) -> Array:
	var expired: Array = []
	for effect in _effects:
		effect["duration_remaining"] -= delta
		if effect["duration_remaining"] <= 0.0:
			expired.append(effect["id"])
	_effects = _effects.filter(func(e): return e["duration_remaining"] > 0.0)
	return expired

func clear() -> void:
	_effects.clear()

## Returns true if the unit is stunned (cannot act)
func is_stunned() -> bool:
	return has_effect("stun")

## Returns the attack speed multiplier from all active effects (e.g. slow, haste)
func atk_speed_multiplier() -> float:
	var mult := 1.0
	if has_effect("atk_speed_slow"):
		mult *= (1.0 - get_value("atk_speed_slow") / 100.0)
	if has_effect("atk_speed_buff"):
		mult *= (1.0 + get_value("atk_speed_buff") / 100.0)
	return maxf(0.1, mult)
