## BattleSystem — orchestrates auto-combat on the BattleArena.
## Runs a tick-based simulation (TICK_RATE seconds per tick).
## Attached as a child of BattleArena.
class_name BattleSystem
extends Node

signal battle_complete(winner_team: int, surviving_unit_count: int)

const TICK_RATE := 0.1

var _player_units: Array = []   # Array[Unit] — team 0
var _enemy_units: Array = []    # Array[Unit] — team 1
var _all_units: Array = []
var _is_running: bool = false
var _tick_timer: Timer

func _ready() -> void:
	_tick_timer = Timer.new()
	_tick_timer.one_shot = false
	_tick_timer.wait_time = TICK_RATE
	_tick_timer.timeout.connect(_battle_tick)
	add_child(_tick_timer)

## Called by BattleArena to start combat.
## player_units / enemy_units are arrays of Unit nodes already added to the scene.
func start_battle(player_units: Array, enemy_units: Array) -> void:
	_player_units = player_units
	_enemy_units  = enemy_units
	_all_units    = player_units + enemy_units
	_is_running   = true
	_tick_timer.start()

func stop_battle() -> void:
	_is_running = false
	_tick_timer.stop()

func _battle_tick() -> void:
	if not _is_running:
		return

	# Filter alive units
	var alive_players := _player_units.filter(func(u): return is_instance_valid(u) and u.is_alive)
	var alive_enemies := _enemy_units.filter(func(u): return is_instance_valid(u) and u.is_alive)

	# Check end condition
	if alive_players.is_empty() or alive_enemies.is_empty():
		_end_battle(alive_players, alive_enemies)
		return

	# Tick all alive units
	for unit in _all_units:
		if not is_instance_valid(unit) or not unit.is_alive:
			continue
		var enemies_for_unit := alive_enemies if unit.team == 0 else alive_players
		var allies_for_unit  := alive_players if unit.team == 0 else alive_enemies
		unit.battle_tick(TICK_RATE, allies_for_unit, enemies_for_unit)

func _end_battle(alive_players: Array, alive_enemies: Array) -> void:
	_is_running = false
	_tick_timer.stop()

	var winner_team := 0 if not alive_players.is_empty() else 1
	var surviving := alive_players.size() if winner_team == 0 else alive_enemies.size()
	battle_complete.emit(winner_team, surviving)
