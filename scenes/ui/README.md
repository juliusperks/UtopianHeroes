# scenes/ui/

In-game UI components. All live in `CanvasLayer` nodes (added by `Main.gd`) so they render above the 2D world regardless of any camera or viewport transform.

Every UI component follows the same pattern:
1. Build node hierarchy programmatically in `_build_ui()` (called from `_ready()`).
2. Connect to `SignalBus` signals in `_connect_signals()`.
3. React to signals by reading from `GameState` and updating labels/bars.

**UI components never write to GameState.** They are purely reactive views.

---

## `HUD.gd` — `HUD (CanvasLayer)`

Top-bar overlay. Displays gold, HP, round label, phase label, countdown timer, and a "Ready!" button.

- **Timer**: `RoundManager.prep_time_remaining` is broadcast via `SignalBus.prep_timer_updated` each `_process` frame. `HUD` displays `ceil(seconds_left)`.
- **Ready button**: calls `RoundManager.skip_prep()`, advancing immediately to COMBAT. Hidden during non-PREP phases.
- **Message banner**: a centered `Label` shown temporarily via `SignalBus.show_message(text, duration)`. Uses a manual `_message_timer` float decremented in `_process` — no `Timer` node required.

---

## `SynergyPanel.gd` — `SynergyPanel (PanelContainer)`

Left sidebar listing active trait synergies. Rebuilds on `SignalBus.synergies_updated`.

Each row shows:
- A tier pip: `●` (max tier, gold), `◐` (partial tier, green), `○` (no tier active, grey)
- `"TraitName (count)"` colored by tier

Data comes from `SynergyManager.get_display_synergies(local_player_id)`, which returns a sorted array of trait display dictionaries. `SynergyPanel` is a pure view — it never calls `SynergyManager` to modify anything.

---

## `PlayerList.gd` — `PlayerList (PanelContainer)`

Right sidebar showing all 8 players' HP as progress bars + numeric labels.

- Bars are color-coded: green (>50% HP), yellow (25–50%), red (<25%).
- On `SignalBus.player_eliminated`, the eliminated player's row dims to 40% opacity and shows a ✗.
- Player 0 (local) is labeled "You" and colored aqua; others are labeled "Player N".

---

## `UnitInfoPopup.gd` — `UnitInfoPopup (PanelContainer)`

Mouse-following tooltip shown on unit hover. Listens to `SignalBus.show_unit_tooltip(unit_data, instance)` and `SignalBus.hide_unit_tooltip()`.

Displays:
- Name + star rating
- Origin/class
- Stat block (HP, ATK, armor, MR, speed, range, cost)
- Ability name + description with the star-appropriate value substituted
- Equipped items

Position is updated in `_process()` to follow `get_viewport().get_mouse_position()` with a 16px offset so it doesn't obscure the cursor. `z_index = 100` ensures it renders above all other UI.

---

## `RoundResultBanner.gd` — `RoundResultBanner (CanvasLayer)`

Brief centered flash of "VICTORY!" or "DEFEAT -N HP" after each combat. Fades out over ~3 seconds by decrementing `_anim_timer` and setting `modulate.a = min(1.0, timer * 2.0)`. No `Tween` required — simple linear fade in `_process()`.
