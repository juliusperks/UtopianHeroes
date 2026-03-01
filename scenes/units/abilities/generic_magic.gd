## Generic fallback ability — fires when a unit has no specific ability script.
## Deals magic damage equal to get_value() to the nearest enemy.
extends "res://scenes/units/UnitAbility.gd"

func execute(allies: Array, enemies: Array) -> void:
	var target := TargetSelector.get_target(caster, enemies)
	if target != null:
		deal_magic_damage(target, get_value())
