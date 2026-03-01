## divine_shield — Avian Paladin ability.
## Grants a damage-absorbing shield to self.
extends UnitAbility

func execute(allies: Array, enemies: Array) -> void:
	var shield_amount := get_value()
	caster.apply_buff("shield", shield_amount, 3.0)
	# Override take_damage on caster to absorb from shield first
	caster.set_meta("shield_hp", shield_amount)
