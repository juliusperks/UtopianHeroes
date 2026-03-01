class_name TraitData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var trait_type: String = "origin"  # "origin" or "class"
@export var description: String = ""
@export var thresholds: Array[int] = []    # e.g. [2, 4, 6] — unit counts for each tier
@export var tiers: Array = []              # Array of Dicts: {count, bonuses:{stat_key: value}}

# Bonus keys used in tiers[n]["bonuses"]:
#   hp_pct          — percent bonus to HP
#   atk_pct         — percent bonus to attack damage
#   armor_flat      — flat armor added
#   mr_flat         — flat magic resistance added
#   atk_speed_pct   — percent bonus to attack speed
#   dmg_amp_pct     — percent bonus to all damage dealt
#   gold_per_round  — extra gold at round start (Merchant)
#   ability_dmg_pct — percent bonus to ability damage
#   dodge_pct       — percent chance to dodge attacks
#   heal_on_kill    — HP restored on killing a unit

func get_tier_for_count(count: int) -> int:
	# Returns 0 if no tier active, otherwise 1-indexed tier
	var active_tier := 0
	for i in thresholds.size():
		if count >= thresholds[i]:
			active_tier = i + 1
	return active_tier

func get_bonuses_for_tier(tier: int) -> Dictionary:
	if tier <= 0 or tier > tiers.size():
		return {}
	return tiers[tier - 1].get("bonuses", {})
