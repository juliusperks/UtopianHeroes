# scenes/board/

The player-facing board: a 4×7 hexagonal grid plus a 9-slot bench below it. During the PREP phase the player drags units between board, bench, and (via ShopPanel) the shop.

## Hex Grid Layout

The grid uses **offset coordinates** with a flat-top hex orientation:
- Odd rows are shifted right by `HEX_W / 2`
- `HEX_W = 74px`, `HEX_H = 64px` (center-to-center)

Pixel position from grid coordinate `(col, row)`:
```
x = HEX_W × col + (HEX_W × 0.5 if row is odd else 0)
y = HEX_H × row
```

Player controls rows 0–3. In combat, the AI occupies a mirrored set of rows above center. The coordinate system is the same; `BattleArena` applies a Y-offset to mirror the enemy.

## `Board.gd`

Manages:
- **28 `HexCell` nodes** in a `hex_cells: Dictionary[Vector2i, HexCell]`
- **9 `BenchSlot` nodes** below the grid
- **Live unit node** dictionaries (`board_units`, `bench_units`) that mirror `GameState.PlayerState.board` and `.bench`
- **Drag-and-drop** state machine (`_dragged_unit`, `_drag_source_board`, `_drag_source_bench`)

### Drag-and-Drop Flow

```
User clicks occupied cell/bench  →  _start_drag_from_board/bench()
  ├── Removes unit from board_units / bench_units
  ├── Clears corresponding GameState entry
  └── Sets _dragged_unit; _process() follows mouse each frame

User clicks target cell          →  _finish_drop(coord)
  ├── If board full: cancel + show message
  ├── If target occupied: swap units between positions
  └── If target empty: place unit, sync GameState, recalculate synergies
```

### State Sync

Every placement calls `SynergyManager.recalculate(local_player_id)` and updates `GameState.local_player().board`. The board is the **view** of `GameState`; `GameState` is always the source of truth. `populate_from_state()` rebuilds all visual nodes from `GameState` (called after merges, phase changes, etc.).

### Phase Awareness

On `SignalBus.phase_changed(COMBAT)`, all `HexCell.input_pickable` is set to `false` — the player cannot move units mid-battle. It is restored on PREP.

## `HexCell.gd`

`Area2D` with a programmatically-built `Polygon2D` (flat-top hexagon at radius 36px) and matching `CollisionPolygon2D`. Emits `clicked(coord)` and `hovered/unhovered(coord)`.

Color states:
- **Normal**: dark slate
- **Hover**: lighter blue
- **Occupied**: slightly dimmer
- **Invalid**: red tint (used when a drop target is illegal)

## `BenchSlot.gd`

`Area2D` with a `ColorRect` (60×60px square) and `RectangleShape2D` collision. Functionally identical to `HexCell` but rectangular. Emits `clicked(slot_index)`.
