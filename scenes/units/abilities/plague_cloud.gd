## plague_cloud — Undead Mystic ability.
## Deals magic damage to the largest cluster of enemies and slows their attack speed.
extends UnitAbility

const HEX_SIZE := 64.0

func execute(allies: Array, enemies: Array) -> void:
	if enemies.is_empty():
		return

	# Find center of mass of all enemies
	var center := Vector2.ZERO
	var alive_enemies := enemies.filter(func(u): return is_instance_valid(u) and u.is_alive)
	for u in alive_enemies:
		center += u.global_position
	if alive_enemies.is_empty():
		return
	center /= float(alive_enemies.size())

	# Find the enemy closest to the center as the cloud's epicenter
	var epicenter_unit: Node = null
	var min_dist := INF
	for u in alive_enemies:
		var d := center.distance_to(u.global_position)
		if d < min_dist:
			min_dist = d
			epicenter_unit = u

	if epicenter_unit == null:
		return

	var dmg := get_value()
	var targets := get_units_in_range(epicenter_unit, alive_enemies, 2, HEX_SIZE)
	for t in targets:
		deal_magic_damage(t, dmg)
		t.apply_buff("atk_speed_slow", 20.0, 3.0)
