## AIDirector — owns and orchestrates all AI player instances.
## In single-player: manages 7 AI opponents.
## In multiplayer (future): only the server runs AIDirector; remote players replace AI slots.
extends Node

var ai_players: Array = []   # Array[AIPlayer]

func _ready() -> void:
	pass  # AI instances created when game starts

func setup_ai_players() -> void:
	ai_players.clear()
	for player_id in GameState.players.size():
		if GameState.players[player_id].is_ai:
			ai_players.append(AIPlayer.new(player_id))

## Called each prep phase by RoundManager
func do_prep_phase() -> void:
	for ai in ai_players:
		ai.do_prep_phase()

## Called by BattleArena to get a snapshot of an AI player's board for combat
func get_ai_board_snapshot(player_id: int) -> Dictionary:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return {}
	return ps.board.duplicate(true)
