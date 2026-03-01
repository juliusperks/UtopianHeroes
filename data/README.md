# data/

All balance configuration lives here as JSON. **No GDScript changes are needed to rebalance the game** — edit a file and restart Godot (or call `DataLoader._load_all()` for hot-reload in editor tooling).

`DataLoader.gd` parses these files at startup into typed `Resource` objects. The raw JSON is never accessed after that point.

---

## `units.json` — Array of unit definitions

Each entry is one playable unit. Fields:

| Field | Type | Description |
|---|---|---|
| `id` | string | Snake-case unique key (e.g. `"dwarf_general"`) |
| `name` | string | Display name shown in UI |
| `origin` | string | Must match a trait `id` in `traits.json` → `origins` |
| `class` | string | Must match a trait `id` in `traits.json` → `classes` |
| `cost` | int 1–5 | Shop cost and pool size tier |
| `stats.hp` | float | Base HP at ★1 |
| `stats.atk` | float | Base attack damage at ★1 |
| `stats.armor` | float | Physical damage reduction input |
| `stats.mr` | float | Magic damage reduction input |
| `stats.atk_speed` | float | Attacks per second at ★1 |
| `stats.atk_range` | int | 1 = melee, 2+ = ranged (in hex units) |
| `ability.id` | string | Filename key for `scenes/units/abilities/[id].gd` |
| `ability.mana_cost` | int | Mana required to fire ability |
| `ability.values` | Array[number] | Per-star ability values `[★1, ★2, ★3]` |
| `star2_multiplier` | float | HP and ATK are multiplied by this at ★2 (default 1.8) |
| `star3_multiplier` | float | HP and ATK multiplier at ★3 (default 3.24 = 1.8²) |
| `sprite` | string | `res://` path to the unit's sprite texture |

**Pool sizes** are determined by `cost` tier, defined in `economy.json["pool_sizes"]`:
- Cost 1: 29 copies, Cost 2: 22, Cost 3: 18, Cost 4: 12, Cost 5: 10

---

## `traits.json` — Origins and Classes

Top-level object with two arrays: `origins` and `classes`. Both follow the same schema.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique key; must match `origin`/`class` fields in units |
| `display_name` | string | Shown in SynergyPanel |
| `type` | string | `"origin"` or `"class"` |
| `description` | string | Tooltip text |
| `thresholds` | Array[int] | Unit counts that unlock each tier, e.g. `[2, 4, 6]` |
| `tiers[n].count` | int | The threshold count for tier `n+1` |
| `tiers[n].bonuses` | Dictionary | Key→value bonus applied to all units with this trait |

### Bonus Keys

All bonuses are **additive** across multiple active traits:

| Key | Effect |
|---|---|
| `hp_pct` | % bonus to max HP |
| `atk_pct` | % bonus to attack damage |
| `armor_flat` | Flat armor added |
| `mr_flat` | Flat magic resistance added |
| `atk_speed_pct` | % bonus to attack speed |
| `ability_dmg_pct` | % bonus to all ability damage |
| `dodge_pct` | % chance to dodge incoming attacks |
| `heal_on_kill` | HP restored when this unit kills an enemy |
| `gold_per_round` | Extra gold at round start (Merchant) |
| `gold_per_win` | Extra gold when combat is won (Merchant) |
| `free_rerolls` | Extra free shop rerolls per prep phase (Human) |
| `xp_per_round` | Bonus XP each round (Human tier 2) |
| `mana_flat` | Starting mana each combat (Gnome) |
| `hp_regen_pct` | % of max HP regenerated per second in combat (Shepherd) |
| `mr_shred_flat` | Flat MR reduction applied to targets hit by abilities (Heretic) |
| `shield_per_round` | HP shield granted to lowest-HP ally each round (Paladin tier 2) |
| `sage_scaling` | Boolean flag; Sage damage scales with round number |

---

## `items.json` — Components and Combined Items

Top-level object: `{ "components": [...], "combined": [...] }`.

Component items are base items (dropped in carousels/PvE). Combined items are crafted from two components.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique key |
| `name` | string | Display name |
| `is_component` | bool | `true` = base item |
| `components` | Array[string] | Two item `id`s required to craft (combined only) |
| `stats.*_bonus` | float | Stat directly added to the holding unit |
| `effect_id` | string | Special passive effect key (see below) |
| `effect_value` | float | Numeric parameter for the effect |

### Effect IDs

| `effect_id` | Behavior |
|---|---|
| `lifesteal` | Heals attacker for `effect_value` × physical damage dealt |
| `rage_stack` | Each attack increases attack speed by `effect_value`% (max 8 stacks) |
| `revive` | On first death, revive at `effect_value` HP |
| `hp_regen_pct` | Regenerate `effect_value`% max HP per second |
| `mana_on_attack` | Restore `effect_value` mana on each basic attack |
| `ionic_aura` | Nearby enemies have MR halved; deal `effect_value` magic dmg on cast |
| `thorns` | Reflect `effect_value`% of incoming physical damage |

---

## `rounds.json` — Array of round configs

Defines the first N rounds explicitly. Rounds beyond the last defined entry use PvP defaults.

| Field | Type | Description |
|---|---|---|
| `round` | int | 1-indexed round number |
| `type` | string | `"pvp"`, `"pve"`, or `"carousel"` |
| `display_label` | string | Shown in HUD |
| `enemies` | Array | `[{unit_id, star, count}]` — PvE only |
| `carousel_units` | Array[string] | Unit ids offered — carousel only |
| `base_damage` | int | Flat damage dealt to loser regardless of survivors |
| `damage_per_surviving_unit` | int | Additional damage per unit still alive on winner's board |

---

## `shop_odds.json`

Maps player level (as string key `"1"`–`"9"`) to an array of five probabilities, one per cost tier. Must sum to 1.0. Example:
```json
"5": [0.20, 0.35, 0.30, 0.15, 0.00]
```
At level 5: 20% chance for a cost-1 unit, 35% for cost-2, etc.

---

## `economy.json`

Flat configuration for all economic constants:

| Key | Description |
|---|---|
| `base_income` | Gold given to every player at round start |
| `interest_rate` | Fraction of banked gold added as interest (e.g. 0.1 = 10%) |
| `max_interest` | Cap on interest per round |
| `reroll_cost` | Gold cost of a manual shop reroll |
| `xp_buy_cost` | Gold cost of buying 4 XP |
| `xp_per_round` | Free XP every player earns per round |
| `xp_to_level` | Array; `xp_to_level[i]` = XP needed to reach level `i+2` |
| `max_level` | Maximum player level (default 9) |
| `max_board_size_by_level` | Array; entry `i` = board slots at level `i+1` |
| `streak_bonus` | Object mapping minimum streak length → gold bonus |
| `starting_gold` | Gold at game start |
| `starting_hp` | Player HP at game start |
| `max_bench_size` | Number of bench slots (default 9) |
| `pool_sizes` | Object: cost tier (as string) → total copies in shared pool |
| `sell_values` | Object: cost tier → gold refunded on sell |
