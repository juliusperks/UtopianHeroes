# UtopianHeroes

A **Team Fight Tactics-style auto-battler** built in Godot 4, themed around the medieval fantasy factions of [Utopia-Game](https://utopia-game.com). Eight players (one human, seven AI) draft units from a shared pool, build synergy compositions on a hexagonal board, and auto-battle each round until one player remains.

## Design Priorities

| Priority | Mechanism |
|---|---|
| **Data-driven balance** | All units, traits, items, and round configs live in `data/*.json`. No code changes are needed to rebalance — edit JSON and restart. |
| **Multiplayer-ready** | `GameState.PlayerState` is pure serializable data (no Node refs). A future `StateReplicator` can diff and sync it over ENet/WebSocket without touching any other system. |
| **Loosely coupled systems** | All cross-system communication goes through `SignalBus`. Systems read from `GameState`; they never hold references to each other. |

## Tech Stack

- **Engine**: Godot 4.3 (GL Compatibility renderer)
- **Language**: GDScript
- **Resolution**: 1280×720

## Project Structure

```
UtopianHeroes/
├── autoloads/      Singletons — core game logic (DataLoader, GameState, managers)
├── data/           JSON balance files — the only place you need to edit to rebalance
├── resources/      Typed GDScript Resource subclasses (UnitData, TraitData, etc.)
├── scenes/         Scene trees (.tscn) and their attached scripts (.gd)
│   ├── main/       Root scene — wires all subscenes together
│   ├── menus/      MainMenu
│   ├── board/      Hex grid, bench slots
│   ├── units/      Universal Unit node + ability implementations
│   ├── battle/     BattleArena + BattleSystem (auto-combat)
│   ├── shop/       ShopPanel + ShopSlot UI
│   └── ui/         HUD, SynergyPanel, PlayerList, tooltips, banners
└── systems/        Pure-logic scripts with no scene dependency
    ├── battle/     TargetSelector, DamageCalculator, StatusEffectManager
    ├── ai/         AIPlayer, AIShopStrategy, AIBoardPositioner
    └── networking/ Multiplayer stubs (NetworkManager, StateReplicator)
```

## Game Loop

```
start_game()
└── RoundManager._advance_round()
    ├── Phase: PREP (30s)
    │   ├── EconomyManager.grant_round_income() → all players
    │   ├── ShopManager.refresh_shops_for_all()
    │   ├── AIDirector.do_prep_phase() → 7 AI players buy/place
    │   └── Human player buys, places units, adjusts comp
    ├── Phase: COMBAT
    │   ├── BattleArena pairs player vs random opponent
    │   ├── BattleSystem ticks every 0.1s
    │   └── Units call battle_tick() → move, attack, cast abilities
    └── Phase: RESULTS
        ├── EconomyManager.apply_combat_damage() → loser takes HP damage
        ├── Streaks updated, Merchant gold bonus applied
        └── Check game_over → if 1 player alive, winner declared
```

## Adding Content

**New unit**: Add an entry to `data/units.json`. If it has a new ability, add `scenes/units/abilities/[ability_id].gd` extending `UnitAbility`.

**New trait**: Add to `data/traits.json` under `origins` or `classes`. Define `thresholds` and `tiers[n].bonuses`.

**New item**: Add to `data/items.json` under `components` or `combined`.

**New round**: Add an entry to `data/rounds.json`. Supports `pvp`, `pve` (with `enemies` array), and `carousel` types.

See each subdirectory's README for deeper documentation.
