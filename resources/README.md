# resources/

Typed GDScript `Resource` subclasses that act as strongly-typed wrappers for the data parsed from `data/*.json`.

## Why Resource Subclasses?

Godot's `Resource` base class provides:
- **Typed properties** with `@export` — editor-inspectable and serialisable
- **Reference semantics with ownership** — resources can be shared or duplicated cleanly
- **`class_name` global registration** — usable as type hints anywhere in the project

`DataLoader` constructs these at startup. All other systems treat them as **immutable** — read-only after `DataLoader._ready()` completes.

> Never modify a `UnitData` instance at runtime. To apply combat stat modifications, copy the values into local variables on the `Unit` node (`current_hp`, `current_atk`, etc.).

---

## `unit_data.gd` — `class_name UnitData`

Represents one unit definition as loaded from `data/units.json`.

Key method:
```gdscript
func get_stat_at_star(base_val: float, star: int) -> float
```
Returns `base_val × star2_multiplier` (★2) or `base_val × star3_multiplier` (★3). Used by `Unit.setup_combat_stats()` to compute scaled HP and ATK before a battle.

---

## `trait_data.gd` — `class_name TraitData`

Represents one origin or class synergy.

Key methods:
```gdscript
func get_tier_for_count(count: int) -> int
# Returns 0 if no tier is active, otherwise 1-indexed tier number.

func get_bonuses_for_tier(tier: int) -> Dictionary
# Returns the bonuses dict for a given tier (e.g. { "atk_speed_pct": 30 }).
```

`thresholds` is a typed `Array[int]` (e.g. `[2, 4, 6]`). `tiers` is an untyped array of plain dictionaries matching the JSON structure.

---

## `item_data.gd` — `class_name ItemData`

Represents one item (component or combined).

Stat bonus fields (`hp_bonus`, `atk_bonus`, etc.) are applied additively in `Unit._apply_item_bonuses()` before combat begins.

`effect_id` is a string key that `Unit._apply_item_bonuses()` matches against a set of known passive effect types (lifesteal, revive, rage_stack, etc.). Adding a new effect type requires handling it in `Unit.gd` and/or `BattleSystem.gd`.

---

## `round_config.gd` — `class_name RoundConfig`

Represents one round's configuration.

`pve_enemies` is an array of plain Dictionaries: `{ unit_id, count, star }`. `BattleArena` reads this to spawn the enemy board during PvE rounds. `carousel_units` is an array of unit IDs offered to all players during a carousel round.
