# systems/

Pure-logic GDScript classes with **no scene dependency**. These scripts extend `RefCounted` or `Node` but never access `get_tree()`, `get_node()`, or any scene-specific API. This makes them independently testable and reusable outside of the Godot scene graph.

## Subdirectories

| Directory | Contents |
|---|---|
| `battle/` | Stateless helpers used by `BattleSystem` during auto-combat |
| `ai/` | AI player decision-making (one instance per AI opponent) |
| `networking/` | Multiplayer stubs — no-ops in single-player, expandable for online play |

## Design Principle

The separation between `scenes/` and `systems/` mirrors the **Model-View** split:
- `systems/` = pure model/logic — no rendering, no input handling
- `scenes/` = view + controller — instantiates systems, handles Godot lifecycle

This means `TargetSelector`, `DamageCalculator`, and the AI scripts can be tested in a headless Godot environment (or ported to a server-side simulation) without any scene tree.
