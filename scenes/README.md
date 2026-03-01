# scenes/

Contains all Godot scene files (`.tscn`) and their attached scripts (`.gd`). Each `.tscn` file declares a root node type and registers its script; all child nodes are built **programmatically in `_ready()`** rather than in the scene editor. This keeps scenes as thin wrappers and puts all logic in version-controlled GDScript.

## Scene Graph Overview

```
Main (Node)                         ← root; wires all subscenes, starts game
├── ColorRect                       ← background fill
├── Node2D (world)
│   ├── Board (Node2D)              ← prep-phase hex grid + bench
│   └── BattleArena (Node2D)       ← combat view (hidden during prep)
├── HUD (CanvasLayer)               ← gold, HP, round label, timer, ready button
├── RoundResultBanner (CanvasLayer) ← "VICTORY!" / "DEFEAT" flash
├── CanvasLayer
│   └── UnitInfoPopup               ← hover tooltip (follows mouse)
├── CanvasLayer
│   └── ShopPanel                   ← 5 shop cards + reroll + buy-XP
└── CanvasLayer
    ├── SynergyPanel                ← active traits sidebar
    └── PlayerList                  ← 8-player HP list
```

`Board` and `BattleArena` share the world `Node2D` and are toggled visible by `Main` on `SignalBus.phase_changed`.

## Subdirectories

| Directory | Contents |
|---|---|
| `main/` | Root scene and top-level wiring |
| `menus/` | MainMenu (entry point) |
| `board/` | Hex grid tiles, bench slots, drag-and-drop controller |
| `units/` | Universal unit node + ability base class + ability implementations |
| `battle/` | BattleArena (spawns units for combat) + BattleSystem (tick loop) |
| `shop/` | ShopPanel (container) + ShopSlot (individual card) |
| `ui/` | HUD, SynergyPanel, PlayerList, UnitInfoPopup, RoundResultBanner |
