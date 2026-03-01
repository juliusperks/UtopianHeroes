class_name ItemData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var is_component: bool = true   # true = base item, false = combined item
@export var component_ids: Array = []   # [item_id_a, item_id_b] for combined items

# Stat bonuses granted to the unit holding this item
@export var hp_bonus: float = 0.0
@export var atk_bonus: float = 0.0
@export var armor_bonus: float = 0.0
@export var mr_bonus: float = 0.0
@export var atk_speed_bonus: float = 0.0  # additive, e.g. 0.1 = +10%
@export var mana_bonus: int = 0

# Special effect
@export var effect_id: String = ""          # e.g. "burn_on_hit", "shield_on_round_start"
@export var effect_value: float = 0.0

@export var sprite_path: String = ""
