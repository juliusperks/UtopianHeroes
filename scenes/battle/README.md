# scenes/battle/

The combat subsystem. Active only during the COMBAT phase; hidden and idle during PREP and RESULTS.

## Architecture

```
BattleArena (Node2D)           ← scene root; owns the combat view
  └── BattleSystem (Node)      ← tick loop; does not own any Unit nodes
      └── Timer (0.1s)         ← drives _battle_tick()
```

`BattleArena` is responsible for **spawning and positioning** unit nodes. `BattleSystem` is responsible for **running the simulation** — it holds references to the spawned nodes but never creates or destroys them.

---

## `BattleArena.gd`

Listens for `SignalBus.phase_changed(COMBAT)` and orchestrates the following sequence:

1. **Clean up** any unit nodes from the previous round.
2. **Pick an opponent** — random alive non-local player from `GameState.alive_players()`.
3. **Spawn unit nodes** for both sides:
   - Local player's `GameState.local_player().board` → team 0 (bottom of screen)
   - Opponent's `GameState.get_player(opponent_id).board` → team 1 (top of screen, Y-mirrored)
4. **Apply synergy bonuses** via `SynergyManager.get_unit_bonuses()` + call `unit_node.setup_combat_stats(bonuses)` on each.
5. **Start `BattleSystem`** with the two unit arrays.

On `BattleSystem.battle_complete(winner_team, surviving_count)`:
- Determines winner/loser player IDs.
- Calls `EconomyManager.apply_combat_damage(loser_id, surviving_count, round)`.
- Updates win/loss streaks and Merchant gold bonuses.
- Emits `SignalBus.combat_ended` and calls `RoundManager.on_combat_complete()`.

### Board Coordinate → World Position

Player units use a `BOARD_OFFSET_Y_PLAYER = 200` offset (below center). Enemy units use `BOARD_OFFSET_Y_ENEMY = -200` (above center). Hex math is identical to `Board.gd`:
```
x = HEX_W × col + (HEX_W × 0.5 if odd row else 0) - (3 × HEX_W)  ← centered
y = HEX_H × row + y_offset
```

---

## `BattleSystem.gd`

A pure simulation node. No scene dependency — it could be extracted to `systems/battle/` and tested headlessly.

### Tick Loop

Every `TICK_RATE = 0.1s`, `_battle_tick()`:
1. Filters `_player_units` and `_enemy_units` for alive nodes.
2. If either side is empty → `_end_battle()`.
3. For each alive unit, calls `unit.battle_tick(delta, allies, enemies)`.

Unit `battle_tick()` handles its own movement, attack cooldown, and ability logic (see `scenes/units/README.md`). `BattleSystem` only coordinates the cadence and checks the end condition.

### Why 0.1s ticks instead of `_process`?

- Deterministic: the same sequence of random rolls produces the same battle result regardless of frame rate.
- Network-friendly: in multiplayer, both server and clients can run the same tick loop from the same initial state and get identical results (lockstep simulation).
- Easier to test: ticks can be called manually in unit tests without a running scene tree.

---

## Adding AI-vs-AI Combat (future)

Currently `BattleArena` always involves the local player. For spectator mode or AI-vs-AI simulation rounds, add a `simulate_ai_combat(player_id_a, player_id_b)` method that spawns two AI boards and runs `BattleSystem` to completion — the result is used only for damage calculation, with no visual output.
