# scenes/units/

The universal `Unit` scene and the ability system.

## `Unit.gd`

Every unit in the game — player-owned or AI-owned, on the board or in combat — uses a single `Unit` scene (`Area2D`). The visual appearance and stats are set at runtime via `init_from_data(instance_data)`.

### Lifecycle

```
instantiate Unit.tscn
  └── Unit._ready()       — builds visual sub-nodes, creates StatusEffectManager

init_from_data(inst)      — called by Board.gd (prep) or BattleArena.gd (combat)
  ├── Reads unit_id, star from instance Dictionary
  ├── Loads UnitData from DataLoader
  └── Creates _ability via _create_ability()

setup_combat_stats(bonuses) — called by BattleArena before battle starts
  ├── Applies star multiplier to HP and ATK
  ├── Applies synergy bonus percentages/flats
  └── Applies item stat bonuses from instance_data["items"]

battle_tick(delta, allies, enemies) — called by BattleSystem every 0.1s
  ├── Ticks status effects (StatusEffectManager)
  ├── Decrements attack cooldown
  ├── Selects target via TargetSelector
  ├── Moves toward target if out of range
  ├── Attacks if in range and cooldown ready
  └── Fires ability when current_mana >= mana_max
```

### Stat Fields

All combat stats are **live copies** — `UnitData` is never modified:

| Field | Source |
|---|---|
| `max_hp` / `current_hp` | `UnitData.base_hp × star_multiplier × (1 + hp_pct/100)` |
| `current_atk` | `base_atk × star_multiplier × (1 + atk_pct/100)` |
| `current_armor` / `current_mr` | `base_armor/mr + flat_bonuses` |
| `current_atk_speed` | `UnitData.atk_speed × (1 + speed_pct/100)` |
| `current_mana` | Starts at `synergy_bonuses["mana_flat"]` + item mana bonus |

### Ability System

`_create_ability()` attempts to load `res://scenes/units/abilities/[ability_id].gd`. If the file doesn't exist it falls back to `_GenericMagicAbility` — a nested class inside `Unit.gd` that simply deals magic damage to the nearest enemy. This means any unit will function even if its ability script hasn't been written yet.

### Item Effects

`_apply_item_bonuses()` reads `instance_data["items"]` (array of item IDs), looks each up in `DataLoader.items`, and adds their stat bonuses. Special `effect_id` values (`lifesteal`, `revive`, etc.) are cached as member variables (`_lifesteal_ratio`, `_revive_hp`) and checked during `_do_attack()` and `_on_death()`.

---

## `UnitAbility.gd` — `class_name UnitAbility`

Base class for all abilities. Subclass it and override `execute(allies, enemies)`.

Provided utility methods:
```gdscript
get_value() -> float          # scaled ability value for current star level, with ability_dmg_pct applied
deal_magic_damage(target, amount)
deal_physical_damage(target, amount)
heal(target, amount)
get_lowest_hp_unit(units) -> Node
get_units_in_range(origin, all_units, hex_range, hex_size) -> Array
```

`get_value()` reads `unit_data.ability_values[star - 1]` and multiplies by `(1 + ability_dmg_pct / 100)`, accumulating bonuses from both trait synergies (applied in `setup_combat_stats`) and items (via `caster.get_ability_dmg_bonus()`).

---

## `abilities/` — Ability Implementations

| File | Unit | Effect |
|---|---|---|
| `divine_shield.gd` | Avian Paladin | Applies a damage-absorbing shield buff to self |
| `war_banner.gd` | Dwarf General | Grants all allies an `atk_speed_buff` status for 4s |
| `arcane_blast.gd` | Elf Mystic | Magic damage to primary target + 50% to 2 nearest enemies |
| `holy_radiance.gd` | Elf Paladin | Heals all allies + temporary armor buff |
| `plague_cloud.gd` | Undead Mystic | AoE magic damage around the enemy cluster center + attack speed slow |

Any unit whose `ability.id` doesn't match an existing file uses `_GenericMagicAbility` automatically. To add a new ability:

1. Create `scenes/units/abilities/[ability_id].gd`
2. `extends UnitAbility`
3. Override `func execute(allies: Array, enemies: Array) -> void:`
4. Use `deal_magic_damage()`, `heal()`, `apply_buff()` etc. from the base class
5. Set `"ability": { "id": "[ability_id]", ... }` in `data/units.json`
