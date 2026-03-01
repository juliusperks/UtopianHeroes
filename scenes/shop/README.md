# scenes/shop/

The shop UI shown during the PREP phase. Displays the player's current five-slot shop, a Reroll button, and a Buy XP button.

## `ShopPanel.gd`

Container scene that:
1. Instantiates five `ShopSlot` nodes and lays them in an `HBoxContainer`.
2. Adds Reroll, Buy XP buttons, and a gold/level label row.
3. Calls `ShopManager.buy_unit()`, `ShopManager.reroll_shop()`, and `EconomyManager.buy_xp()` on button press.
4. Refreshes by reading `GameState.local_player().shop_slots` on every relevant signal (`shop_refreshed`, `gold_changed`, `player_leveled_up`).

`ShopPanel` is **read-only with respect to game state** — it never modifies state directly. All mutations go through the manager autoloads, which then emit signals that cause `ShopPanel._refresh()` to re-read and re-render.

## `ShopSlot.gd`

Individual unit card. Displays:
- Unit display name
- Origin and class (color-coded)
- Cost (gold-colored star label)
- Buy button (disabled if player can't afford or slot is locked)
- "LOCKED" label (shown when the shop is locked between rounds)

Background color is driven by cost tier (grey → green → blue → purple → gold) via `_cost_color(cost)`.

### Locked Shop

When `ShopManager.lock_shop()` is called, slot IDs are prefixed with `"LOCKED:"`. `ShopSlot.set_unit()` strips this prefix for display but keeps the buy button disabled. The lock/unlock feature is available for future UI exposure (e.g. a lock button between rounds).

## Data Flow

```
SignalBus.shop_refreshed(player_id)
  └── ShopPanel._on_shop_refreshed()
      └── ShopPanel._refresh()
          ├── Reads GameState.local_player().shop_slots[i]
          ├── ShopSlot.set_unit(unit_id)         ← visual update
          └── ShopSlot.set_affordable(bool)       ← button enable/disable
```
