# systems/networking/

Stubs for future multiplayer support. Both files are no-ops in the current single-player build. They exist to document the intended multiplayer seam and prevent ad-hoc network code from being scattered across other systems when multiplayer is implemented.

---

## Multiplayer Design Intent

The game is designed for **server-authoritative** multiplayer with a **lockstep state replication** model:

1. One player hosts (or a dedicated server runs).
2. The server runs all game logic: `RoundManager`, `ShopManager`, `EconomyManager`, `SynergyManager`, and all `AIPlayer` instances.
3. Clients send **inputs** (buy slot N, sell unit X, reroll, buy XP, place unit at coord) to the server.
4. The server validates inputs, mutates `GameState`, and broadcasts **state diffs** back to all clients each phase.
5. Clients apply diffs to their local `GameState` and re-render.

The reason this is feasible without a rewrite: `GameState.PlayerState` contains only serializable primitives (int, float, String, Array, Dictionary) — no `Node` references. `GameState.serialize()` can produce a full snapshot; a diff is just the delta between two snapshots.

### Why not delta-authority per action?

For a prep-phase game (not a real-time shooter), broadcasting the full `GameState` per phase transition is acceptable bandwidth. Diffing can be added later as an optimisation.

---

## `NetworkManager.gd`

Intended to wrap Godot's `ENetMultiplayerPeer` or `WebSocketMultiplayerPeer`. When active:
- `host_server(port, max_players)` — sets up an `ENetMultiplayerPeer` as host, registers RPC handlers.
- `connect_to_server(address, port)` — joins as a client.
- `broadcast_state_diff(diff)` — server-only; sends serialized state to all peers via `@rpc`.

In single-player, `is_multiplayer_active = false` and none of these are called.

---

## `StateReplicator.gd`

Intended to sit between game logic and the network layer:
- `serialize_diff()` — calls `GameState.serialize()` (full snapshot for now; delta-diff later).
- `apply_diff(diff)` — patches `GameState.players` from received data.

When networking is implemented, `RoundManager` would call `StateReplicator.serialize_diff()` at each phase transition and pass the result to `NetworkManager.broadcast_state_diff()`. Clients would receive it via RPC and call `StateReplicator.apply_diff()`.

---

## Implementation Checklist (when adding multiplayer)

- [ ] Implement `NetworkManager.host_server()` and `connect_to_server()`
- [ ] Add input RPCs: `buy_unit_rpc`, `sell_unit_rpc`, `reroll_rpc`, `buy_xp_rpc`, `place_unit_rpc`
- [ ] Server validates each RPC before calling the corresponding manager method
- [ ] Implement `StateReplicator.apply_diff()` to patch `GameState` from received data
- [ ] In `RoundManager`, gate phase transitions on all-players-ready acknowledgment
- [ ] Replace `AIDirector` slot assignment with multiplayer lobby peer assignment
- [ ] Add `LobbyScreen.gd` navigation to `MainMenu`
