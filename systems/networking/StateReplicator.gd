## StateReplicator — stub for future multiplayer state synchronization.
## When multiplayer is active:
##   - Server calls serialize_diff() each round and broadcasts to clients.
##   - Clients call apply_diff() to update their local GameState.
##   - The seam is GameState.serialize() — all player states are plain dicts.
extends Node

## Serialise only the parts of GameState that changed since last tick.
## (Stub — returns full state in the future this would be a delta.)
func serialize_diff() -> Dictionary:
	return GameState.serialize()

## Apply a received state diff from the server.
func apply_diff(diff: Dictionary) -> void:
	# Future implementation: patch GameState.players from diff["players"]
	pass
