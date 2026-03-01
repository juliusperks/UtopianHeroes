## TargetSelector — picks combat targets for units.
## Default rule: nearest enemy (Euclidean distance on hex pixel positions).
## Supports future aggro/taunt overrides.
class_name TargetSelector
extends RefCounted

## Returns the best target for `attacker` from `enemies` (Array of Unit nodes).
## Returns null if no valid target exists.
static func get_target(attacker: Node, enemies: Array) -> Node:
	if enemies.is_empty():
		return null

	var best: Node = null
	var best_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		# Taunt check: if any enemy has taunt, prefer them
		if enemy.get("has_taunt") and (best == null or not best.get("has_taunt")):
			best = enemy
			best_dist = attacker.global_position.distance_to(enemy.global_position)
			continue

		var dist: float = (attacker.global_position as Vector2).distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy

	return best

## Returns true if `attacker` is within attack range of `target`.
## `hex_size` is the pixel size of one hex (used to convert range in hexes to pixels).
static func is_in_range(attacker: Node, target: Node, atk_range: int, hex_size: float) -> bool:
	if not is_instance_valid(target):
		return false
	var dist: float = (attacker.global_position as Vector2).distance_to(target.global_position)
	return dist <= float(atk_range) * hex_size + 4.0  # +4 pixel tolerance

## Returns the pixel position one step toward `target` from `from_pos`.
static func step_toward(from_pos: Vector2, target_pos: Vector2, step_size: float) -> Vector2:
	var dir := (target_pos - from_pos).normalized()
	return from_pos + dir * step_size
