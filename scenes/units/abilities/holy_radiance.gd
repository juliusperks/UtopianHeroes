## holy_radiance — Elf Paladin ability.
## Heals all allies and grants temporary armor.
extends UnitAbility

func execute(allies: Array, enemies: Array) -> void:
	var heal_amount := get_value()
	for ally in allies:
		if is_instance_valid(ally) and ally.is_alive:
			heal(ally, heal_amount)
			ally.apply_buff("armor_buff", 20.0, 3.0)
