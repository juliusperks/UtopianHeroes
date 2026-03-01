# systems/battle/

Stateless helper classes for the auto-combat simulation. All three scripts use only `static func` or instance methods with no persistent state. They are called by `Unit.gd` during `battle_tick()` and by `BattleArena.gd` during combat setup.

---

## `TargetSelector.gd` — `class_name TargetSelector`

Implements targeting rules for units choosing whom to attack.

### `get_target(attacker, enemies) -> Node`

Default rule: nearest enemy by Euclidean pixel distance. Priority override: if any enemy has `has_taunt = true`, it is preferred over closer non-taunting enemies. Returns `null` if no valid target exists (all dead or array empty).

### `is_in_range(attacker, target, atk_range, hex_size) -> bool`

Converts attack range (in hex units) to pixels: `atk_range × hex_size + 4px tolerance`. The tolerance accounts for sub-pixel positioning during movement.

### `step_toward(from_pos, target_pos, step_size) -> Vector2`

Returns a position one `step_size`-pixel step from `from_pos` toward `target_pos`. Called in `Unit.battle_tick()` when a target is out of range.

---

## `DamageCalculator.gd` — `class_name DamageCalculator`

All damage formulas in one place.

### Physical and Magic Damage

Both use the same attenuation formula, matching TFT's model:
```
effective_damage = raw_damage × (100 / (100 + defense))
```
At 100 armor: 50% reduction. At 200 armor: 33% reduction. Defense is floored at 0 (negative armor/MR is valid and amplifies damage).

### Supporting Functions

```gdscript
static func lifesteal(damage_dealt, lifesteal_ratio) -> float
static func apply_armor_shred(current_armor, shred_flat) -> float   # Heretic class
static func apply_mr_shred(current_mr, shred_flat) -> float         # Heretic class
```

All functions are pure (no side effects, no state). To change the damage formula for the entire game, edit only this file.

---

## `StatusEffectManager.gd` — `class_name StatusEffectManager`

Manages a list of timed status effects on a single unit. One instance is created per `Unit` node and cleared at the start of each combat.

### Effect Schema

Each effect is a plain Dictionary:
```gdscript
{ "id": String, "value": float, "duration_remaining": float, "source_id": String }
```

### Key API

```gdscript
apply(id, value, duration, source_id)  # Add or refresh an effect
remove(id)                             # Remove by id
has_effect(id) -> bool
get_value(id, default) -> float
tick(delta) -> Array                   # Advance time; returns expired effect ids
is_stunned() -> bool
atk_speed_multiplier() -> float        # Combines all speed buffs/slows
```

`tick()` is called in `Unit.battle_tick()` before any other logic. Expired effects are returned so the caller can react (e.g. reset armor after a shred effect expires).

### Supported Effect IDs

| ID | Applied by |
|---|---|
| `stun` | Future ability/item |
| `atk_speed_slow` | `plague_cloud` ability |
| `atk_speed_buff` | `war_banner` ability |
| `shield` | `divine_shield` ability |
| `armor_buff` | `holy_radiance` ability |

New effects only require adding them to whatever ability/item creates them — `StatusEffectManager` stores and ticks any string ID generically.
