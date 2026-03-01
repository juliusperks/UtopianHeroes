## BattleArena — manages the full combat scene.
## Shows both the player's board and the opponent's board side-by-side (or top/bottom).
## Instantiates Unit nodes from both boards, runs BattleSystem, then reports results.
extends Node2D

const UnitScene := preload("res://scenes/units/Unit.tscn")

var _battle_system: BattleSystem
var _player_units: Array = []
var _enemy_units: Array = []
var _opponent_id: int = -1

func _ready() -> void:
	_battle_system = BattleSystem.new()
	_battle_system.battle_complete.connect(_on_battle_complete)
	add_child(_battle_system)

	SignalBus.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: int) -> void:
	if phase == RoundManager.Phase.COMBAT:
		_begin_combat()

func _begin_combat() -> void:
	_cleanup_units()

	# Pick a random opponent from alive non-local players
	_opponent_id = _pick_opponent()
	if _opponent_id < 0:
		# No valid opponent (shouldn't happen in normal play)
		RoundManager.on_combat_complete()
		return

	var ps_local := GameState.local_player()
	var ps_enemy := GameState.get_player(_opponent_id)

	SignalBus.combat_started.emit(GameState.local_player_id, _opponent_id)

	# Spawn player units (team 0) — bottom half of screen
	for coord in ps_local.board:
		var inst: Dictionary = ps_local.board[coord]
		var unit_node := _spawn_unit(inst, 0, coord, false)
		_player_units.append(unit_node)

	# Spawn enemy units (team 1) — top half of screen (mirrored)
	for coord in ps_enemy.board:
		var inst: Dictionary = ps_enemy.board[coord]
		var unit_node := _spawn_unit(inst, 1, coord, true)
		_enemy_units.append(unit_node)

	if _player_units.is_empty() and _enemy_units.is_empty():
		RoundManager.on_combat_complete()
		return

	_battle_system.start_battle(_player_units, _enemy_units)

func _spawn_unit(inst: Dictionary, team: int, coord: Vector2i, mirror: bool) -> Node:
	var unit_node: Node = UnitScene.instantiate()
	unit_node.team = team
	unit_node.init_from_data(inst)

	# Position: player board on bottom, enemy on top (mirrored Y)
	var pixel_pos := _board_coord_to_world(coord, mirror)
	unit_node.position = pixel_pos
	add_child(unit_node)

	# Apply synergy bonuses to combat stats
	var bonuses: Dictionary = SynergyManager.get_unit_bonuses(
		GameState.local_player_id if team == 0 else _opponent_id,
		inst.get("unit_id", "")
	)
	unit_node.setup_combat_stats(bonuses)

	return unit_node

func _board_coord_to_world(coord: Vector2i, mirror: bool) -> Vector2:
	const HEX_W := 74.0
	const HEX_H := 64.0
	const BOARD_OFFSET_Y_PLAYER := 200.0
	const BOARD_OFFSET_Y_ENEMY  := -200.0

	var offset_x := HEX_W * 0.5 if (coord.y % 2 != 0) else 0.0
	var x := HEX_W * coord.x + offset_x - (3.0 * HEX_W)  # center board
	var y := HEX_H * coord.y + (BOARD_OFFSET_Y_ENEMY if mirror else BOARD_OFFSET_Y_PLAYER)
	return Vector2(x, y)

func _pick_opponent() -> int:
	var candidates := []
	for ps in GameState.alive_players():
		if ps.player_id != GameState.local_player_id:
			candidates.append(ps.player_id)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]

func _on_battle_complete(winner_team: int, surviving_count: int) -> void:
	_battle_system.stop_battle()

	var winner_id  := GameState.local_player_id if winner_team == 0 else _opponent_id
	var loser_id   := _opponent_id if winner_team == 0 else GameState.local_player_id

	# Apply damage to loser
	var damage := EconomyManager.apply_combat_damage(loser_id, surviving_count, GameState.current_round)

	# Update streaks
	var ps_winner := GameState.get_player(winner_id)
	var ps_loser  := GameState.get_player(loser_id)
	if ps_winner != null:
		ps_winner.win_streak += 1
		ps_winner.loss_streak = 0
		# Merchant gold bonus on win
		var win_gold: int = SynergyManager.get_bonus_value(winner_id, "gold_per_win", 0)
		if win_gold > 0:
			ps_winner.gold += win_gold
			SignalBus.gold_changed.emit(winner_id, ps_winner.gold)
	if ps_loser != null:
		ps_loser.loss_streak += 1
		ps_loser.win_streak = 0

	SignalBus.combat_ended.emit(winner_id, loser_id, damage)
	RoundManager.on_combat_complete()

func _cleanup_units() -> void:
	for u in _player_units + _enemy_units:
		if is_instance_valid(u):
			u.queue_free()
	_player_units.clear()
	_enemy_units.clear()
