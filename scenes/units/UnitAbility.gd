## UnitAbility — base class for all unit abilities.
## Subclass this and override execute() to implement specific ability logic.
## Abilities are instantiated by BattleSystem when a unit reaches full mana.
class_name UnitAbility
extends RefCounted

var unit_data: UnitData
var caster: Node     # The Unit node casting this ability
var star: int = 1    # 1/2/3 — determines which value from ability_values to use

func _init(p_unit_data: UnitData, p_caster: Node, p_star: int) -> void:
	unit_data = p_unit_data
	caster = p_caster
	star = p_star

## Override in subclass. `allies` and `enemies` are arrays of live Unit nodes.
func execute(allies: Array, enemies: Array) -> void:
	pass

## Returns the scaled ability value for the current star level.
func get_value() -> float:
	var values: Array = unit_data.ability_values
	if values.is_empty():
		return 0.0
	var idx := clampi(star - 1, 0, values.size() - 1)
	var base := float(values[idx])
	# Apply ability damage % bonus from traits and items
	var ability_dmg_pct := caster.get_ability_dmg_bonus()
	return base * (1.0 + ability_dmg_pct / 100.0)

## Utility: deal magic damage from caster to target
func deal_magic_damage(target: Node, amount: float) -> void:
	if not is_instance_valid(target) or not target.is_alive:
		return
	var mr := target.current_mr
	# Heretic MR shred
	var shred: float = caster.get("mr_shred_flat") if caster.get("mr_shred_flat") else 0.0
	if shred > 0.0:
		mr = DamageCalculator.apply_mr_shred(mr, shred)
	var final_dmg := DamageCalculator.magic(amount, mr)
	target.take_damage(final_dmg, false)

## Utility: deal physical damage from caster to target
func deal_physical_damage(target: Node, amount: float) -> void:
	if not is_instance_valid(target) or not target.is_alive:
		return
	var final_dmg := DamageCalculator.physical(amount, target.current_armor)
	target.take_damage(final_dmg, true)

## Utility: heal target for `amount` HP (capped at max HP)
func heal(target: Node, amount: float) -> void:
	if not is_instance_valid(target) or not target.is_alive:
		return
	target.receive_heal(amount)

## Utility: find the unit with lowest HP in an array
func get_lowest_hp_unit(units: Array) -> Node:
	var best: Node = null
	for u in units:
		if is_instance_valid(u) and u.is_alive:
			if best == null or u.current_hp < best.current_hp:
				best = u
	return best

## Utility: find all units within `hex_range` hexes of `origin_unit`
func get_units_in_range(origin_unit: Node, all_units: Array, hex_range: int, hex_size: float) -> Array:
	var result := []
	for u in all_units:
		if not is_instance_valid(u) or not u.is_alive:
			continue
		var dist := origin_unit.global_position.distance_to(u.global_position)
		if dist <= float(hex_range) * hex_size + 4.0:
			result.append(u)
	return result
