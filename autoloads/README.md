# autoloads/

Godot **autoloads** are singletons instantiated before the first scene loads and accessible globally by name throughout the project. All eight scripts here are registered in `project.godot` under `[autoload]`.

## Dependency Order

Autoloads are instantiated in registration order. The dependency graph is:

```
SignalBus          ← no dependencies
DataLoader         ← no dependencies (reads files)
GameState          ← DataLoader (reads economy config during init_game)
RoundManager       ← GameState, ShopManager, EconomyManager, SynergyManager, AIDirector
ShopManager        ← GameState, DataLoader, SynergyManager, SignalBus
EconomyManager     ← GameState, DataLoader, SynergyManager, SignalBus
SynergyManager     ← GameState, DataLoader, SignalBus
AIDirector         ← GameState, ShopManager, EconomyManager, SynergyManager (via AIPlayer)
```

> **Rule**: Never create a circular dependency between autoloads. All cross-system events go through `SignalBus` rather than direct method calls.

## File Reference

### `SignalBus.gd`
Global signal hub. Every signal in the game is declared here. Systems `emit` and `connect` here rather than referencing each other directly.

**Why**: Decoupling. Adding multiplayer means the server can emit `SignalBus.gold_changed` and all UI reacts identically whether the source was a local action or a network packet.

### `DataLoader.gd`
Reads all six JSON files at startup and converts raw dictionaries into typed `Resource` objects (`UnitData`, `TraitData`, etc.). After `_ready()`, its dictionaries are **read-only** — no system should ever mutate a `UnitData` instance.

Key API:
```gdscript
DataLoader.units          # Dictionary[String, UnitData]
DataLoader.traits         # Dictionary[String, TraitData]
DataLoader.items          # Dictionary[String, ItemData]
DataLoader.rounds         # Array[RoundConfig]
DataLoader.shop_odds      # Dictionary[String, Array[float]]
DataLoader.economy        # Dictionary (flat key-value config)
DataLoader.get_round(n)   # -> RoundConfig or null
DataLoader.get_units_by_cost(cost)  # -> Array[String]
```

### `GameState.gd`
The **single source of truth** for all mutable game state. Contains eight `PlayerState` instances (one human, seven AI in single-player) and the shared `unit_pool`.

**Multiplayer seam**: `PlayerState` stores only primitives, arrays, and plain dictionaries — never `Node` references. This means `GameState.serialize()` can produce a fully-diffable snapshot that `StateReplicator` can sync over the network.

Key API:
```gdscript
GameState.local_player_id              # int (always 0 in single-player)
GameState.players                      # Array[PlayerState]
GameState.unit_pool                    # Dictionary[String, int] — copies remaining
GameState.get_player(id)               # -> PlayerState or null
GameState.local_player()               # -> PlayerState for the human
GameState.make_unit_instance(uid, star) # -> Dictionary (instance schema)
GameState.count_unit_copies(pid, uid)  # -> int
GameState.try_merge_units(pid, uid)    # 3x 1-star → 1x 2-star
GameState.serialize()                  # -> Dictionary (full snapshot)
```

**Unit instance schema** (Dictionary):
```gdscript
{
    "instance_id": String,  # unique per placed copy
    "unit_id":     String,  # key into DataLoader.units
    "star":        int,     # 1 / 2 / 3
    "items":       Array,   # Array[String] item_ids (max 3)
    "hp":          float    # -1 = use base stat (set at combat start)
}
```

### `RoundManager.gd`
Drives the **phase state machine**. Phases (defined in `enum Phase`):

```
LOBBY → CAROUSEL/PREP → COMBAT → RESULTS → (next round or GAME_OVER)
```

Transitions are time-driven (Timers) or event-driven (`on_combat_complete()`, `on_carousel_complete()`). Each transition emits `SignalBus.phase_changed(phase)`.

The prep phase timer is broadcast via `SignalBus.prep_timer_updated` every `_process` tick so the HUD can display a countdown without coupling to `RoundManager` directly.

### `ShopManager.gd`
Manages the **shared unit pool** and generates shop offerings per player. Pool sizes per cost tier are defined in `data/economy.json` under `pool_sizes`.

Rolling algorithm: weighted random selection of a cost tier (using `data/shop_odds.json` odds by player level), then uniform random selection of an available unit within that tier.

Handles the **3-copy merge**: after every purchase, `GameState.try_merge_units` is called. If three 1-star copies exist, they merge to a 2-star; three 2-stars merge to a 3-star.

### `EconomyManager.gd`
Handles **gold income, XP, and leveling**. Income formula each round:
```
total = base_income + interest + streak_bonus + trait_bonus
interest = min(floor(banked_gold × interest_rate), max_interest)
streak_bonus = streak_table[max(win_streak, loss_streak)]
trait_bonus  = SynergyManager.get_bonus_value("gold_per_round")
```

All constants come from `data/economy.json`. To change the interest cap, edit `max_interest` there.

`max_board_size(player_id)` returns the number of units the player can place on the board at their current level, read from `economy.json["max_board_size_by_level"]`.

### `SynergyManager.gd`
Counts origins and classes of all units on a player's board, determines which trait tiers are active, and caches the merged bonus values. Recalculates on every board change.

Downstream systems read bonuses via:
```gdscript
SynergyManager.get_unit_bonuses(player_id, unit_id)  # bonuses for one unit
SynergyManager.get_all_bonuses(player_id)             # all merged bonuses
SynergyManager.get_bonus_value(player_id, key, default)
SynergyManager.get_display_synergies(player_id)       # for UI rendering
```

### `AIDirector.gd`
Owns all `AIPlayer` instances. Called once per prep phase by `RoundManager`. In single-player, this simulates seven independent opponents each making buy/place decisions. In a future multiplayer implementation, remote human players would replace AI slots and `AIDirector` would only manage remaining AI-controlled seats.
