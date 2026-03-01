# systems/ai/

AI decision-making for the seven non-human players. Each AI player is an independent `AIPlayer` instance managed by `AIDirector`. The AI runs entirely during the PREP phase — it makes all its decisions synchronously before the human player's timer expires.

---

## Architecture

```
AIDirector (autoload)
└── Array[AIPlayer]                    ← one per AI-controlled player slot
    ├── AIShopStrategy                 ← decides what to buy / whether to reroll
    └── AIBoardPositioner              ← arranges purchased units on the board
```

All three classes extend `RefCounted`, not `Node` — they hold no scene references and do not require a scene tree.

---

## `AIPlayer.gd` — `class_name AIPlayer`

Orchestrates one AI player's prep phase. On construction, `_pick_random_comp()` selects 2–3 random trait IDs as the AI's target composition for the game. This composition is passed to `AIShopStrategy`.

```gdscript
func do_prep_phase() -> void:
    _maybe_buy_xp(ps)    # Level up if board is at capacity and gold allows
    _buy_units(ps)        # Buy slots that match strategy, starting from slot 0
    _maybe_reroll(ps)     # Reroll once if strategy recommends it and gold > threshold
    _positioner.arrange_board()
```

**Gold conservation**: The AI never rerolls unless it has more than `reroll_cost + 10` gold, preserving interest income. This mirrors a basic TFT strategy heuristic — saving gold to hit interest breakpoints.

---

## `AIShopStrategy.gd` — `class_name AIShopStrategy`

Scores each shop slot and recommends buy/reroll decisions.

### `wants_unit(unit_id) -> bool`

Returns `true` if any of these conditions hold:
1. Buying this unit would complete a 3-copy merge (the AI already has 2 copies).
2. The unit's origin or class is in `_target_comp`.
3. The unit costs 1 gold and the AI already owns one copy (early-game consistency).

This is an intentionally simple heuristic. More sophisticated strategies (e.g. scouting opponents, eco management, pivot detection) can be layered in here without changing any other system.

### `should_reroll() -> bool`

Returns `true` if the AI has a 2-copy unit (wants the 3rd), or if zero current shop slots match the desired composition.

---

## `AIBoardPositioner.gd` — `class_name AIBoardPositioner`

Places units on the AI's board. Strategy: sort by attack range (melee units front, ranged/casters back), then fill positions from the back row forward.

```gdscript
func arrange_board() -> void:
    # 1. Collect all units from both board and bench
    # 2. Sort by atk_range ascending (melee → front rows)
    # 3. Place top N (max_board_size) onto board; rest go to bench
    # 4. Recalculate synergies
```

The AI's board uses the same `GameState.PlayerState.board` dictionary as a human player — there is no separate AI board representation. `BattleArena` reads from `GameState` regardless of whether a player slot is human or AI.

---

## Extending the AI

To add a new AI difficulty tier or strategy:
1. Subclass `AIShopStrategy` and override `wants_unit()` / `should_reroll()`.
2. Subclass `AIBoardPositioner` and override `arrange_board()` for positioning logic (e.g. item-aware placement, front-line tanking).
3. Pass the new strategy/positioner to `AIPlayer.__init__()`.
4. In `AIDirector.setup_ai_players()`, assign difficulty tiers based on `player_id` or a game-mode setting.

No other systems need to change.
