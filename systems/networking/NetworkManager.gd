## NetworkManager — stub for future multiplayer support.
## Currently a no-op. When multiplayer is added:
##   - Wrap Godot's ENetMultiplayerPeer or WebSocketMultiplayerPeer here.
##   - Route all state changes through StateReplicator instead of modifying
##     GameState directly.
##   - Server-authoritative: only the server modifies GameState; clients receive
##     diffs via StateReplicator.
extends Node

var is_multiplayer_active: bool = false
var is_server: bool = true

func _ready() -> void:
	pass  # No-op in single-player mode

## Future: connect to a server
## func connect_to_server(address: String, port: int) -> void: ...

## Future: host a lobby
## func host_server(port: int, max_players: int) -> void: ...

## Future: send game state diff to all clients
## func broadcast_state_diff(diff: Dictionary) -> void: ...
