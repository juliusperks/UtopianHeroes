## war_banner — Dwarf General ability.
## Grants nearby allies bonus attack speed for 4 seconds.
extends UnitAbility

func execute(allies: Array, enemies: Array) -> void:
	var bonus_pct := get_value()   # e.g. 15 / 25 / 40
	for ally in allies:
		if is_instance_valid(ally) and ally.is_alive:
			ally.apply_buff("atk_speed_buff", bonus_pct, 4.0)
