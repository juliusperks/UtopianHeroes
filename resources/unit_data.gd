class_name UnitData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var origin: String = ""         # maps to a trait id in traits.json
@export var unit_class: String = ""     # maps to a trait id in traits.json
@export var cost: int = 1               # 1-5

# Base stats (star 1)
@export var base_hp: float = 500.0
@export var base_atk: float = 50.0
@export var base_armor: float = 20.0
@export var base_mr: float = 20.0       # magic resistance
@export var atk_speed: float = 0.7      # attacks per second
@export var atk_range: int = 1          # 1 = melee, 2+ = ranged

# Ability
@export var ability_id: String = ""
@export var ability_name: String = ""
@export var ability_description: String = ""
@export var ability_mana_cost: int = 60
@export var ability_values: Array = []  # [star1_val, star2_val, star3_val]

# Star scaling
@export var star2_multiplier: float = 1.8
@export var star3_multiplier: float = 3.24

# Visuals
@export var sprite_path: String = ""

# Pool size is determined by cost tier, not stored here
# Pool sizes: cost1=29, cost2=22, cost3=18, cost4=12, cost5=10

func get_stat_at_star(base_val: float, star: int) -> float:
	match star:
		2: return base_val * star2_multiplier
		3: return base_val * star3_multiplier
		_: return base_val
