# scenes/main/

The root scene instantiated when the player clicks "Play" from the main menu.

## `Main.gd`

Responsibilities:
1. **Instantiates and adds all subscenes** — Board, BattleArena, ShopPanel, HUD, SynergyPanel, PlayerList, UnitInfoPopup, RoundResultBanner — and positions them in the viewport.
2. **Starts the game** by calling `AIDirector.setup_ai_players()` then `RoundManager.start_game()`.
3. **Toggles subscene visibility** on `SignalBus.phase_changed`: Board + ShopPanel are shown during PREP; BattleArena is shown during COMBAT.
4. **Handles game over** — shows a message, then transitions back to `MainMenu.tscn` after 5 seconds.

`Main.gd` holds no game logic of its own. It is purely a composition and routing layer — the orchestrator pattern. All logic lives in the autoloads and the subscenes.

## Scene Structure

```
Main (Node)
├── ColorRect (bg)
├── Node2D (world, centered at 640,360)
│   ├── Board
│   └── BattleArena
├── HUD (CanvasLayer)
├── RoundResultBanner (CanvasLayer)
├── CanvasLayer → UnitInfoPopup
├── CanvasLayer → ShopPanel (anchored bottom)
└── CanvasLayer → SynergyPanel + PlayerList
```

UI elements live in `CanvasLayer` nodes so they render on top of the 2D world regardless of camera transformations.
