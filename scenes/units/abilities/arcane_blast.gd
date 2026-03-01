## arcane_blast — Elf Mystic ability.
## Deals magic damage to primary target and bounces to 2 nearby enemies for 50%.
extends UnitAbility

func execute(allies: Array, enemies: Array) -> void:
	var primary := TargetSelector.get_target(caster, enemies)
	if primary == null:
		return

	var dmg := get_value()
	deal_magic_damage(primary, dmg)

	# Bounce to up to 2 other enemies closest to primary
	var others := enemies.filter(func(u): return u != primary and is_instance_valid(u) and u.is_alive)
	others.sort_custom(func(a, b):
		return primary.global_position.distance_to(a.global_position) < primary.global_position.distance_to(b.global_position)
	)
	for i in mini(2, others.size()):
		deal_magic_damage(others[i], dmg * 0.5)
