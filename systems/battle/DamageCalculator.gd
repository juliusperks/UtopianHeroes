## DamageCalculator — resolves physical and magic damage with armor/MR mitigation.
## Formula mirrors TFT: damage * (100 / (100 + defense))
class_name DamageCalculator
extends RefCounted

## Calculate physical damage after armor reduction.
static func physical(raw_damage: float, target_armor: float) -> float:
	var effective_armor := maxf(0.0, target_armor)
	var multiplier := 100.0 / (100.0 + effective_armor)
	return maxf(0.0, raw_damage * multiplier)

## Calculate magic damage after MR reduction.
static func magic(raw_damage: float, target_mr: float) -> float:
	var effective_mr := maxf(0.0, target_mr)
	var multiplier := 100.0 / (100.0 + effective_mr)
	return maxf(0.0, raw_damage * multiplier)

## Apply lifesteal: returns HP to heal based on damage dealt and lifesteal ratio.
static func lifesteal(damage_dealt: float, lifesteal_ratio: float) -> float:
	return damage_dealt * lifesteal_ratio

## Apply armor shred from Heretic trait. Returns reduced armor value.
static func apply_armor_shred(current_armor: float, shred_flat: float) -> float:
	return maxf(0.0, current_armor - shred_flat)

## Apply MR shred from Heretic class. Returns reduced MR value.
static func apply_mr_shred(current_mr: float, shred_flat: float) -> float:
	return maxf(0.0, current_mr - shred_flat)
