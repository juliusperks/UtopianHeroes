class_name RoundConfig
extends Resource

@export var round_number: int = 1
@export var round_type: String = "pvp"  # "pvp", "pve", "carousel"

# For PvE rounds: list of enemy unit ids and counts
@export var pve_enemies: Array = []  # [{unit_id, count, star}]

# For carousel rounds: pool of units offered
@export var carousel_units: Array = []  # [unit_id, ...]

# Damage formula: base + (surviving_unit_count * per_unit)
@export var base_damage: int = 2
@export var damage_per_surviving_unit: int = 1

# Label shown in HUD
@export var display_label: String = ""
