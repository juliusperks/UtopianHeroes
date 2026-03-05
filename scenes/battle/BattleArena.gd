## BattleArena — manages the full combat scene.
## Shows both the player's board and the opponent's board side-by-side (or top/bottom).
## Instantiates Unit nodes from both boards, runs BattleSystem, then reports results.
extends Node2D

const UnitScene := preload("res://scenes/units/Unit.tscn")

var _battle_system: BattleSystem
var _player_units: Array = []
var _enemy_units: Array = []
var _opponent_id: int = -1
var _overtime_this_battle: bool = false   # latched when overtime fires

func _ready() -> void:
	_battle_system = BattleSystem.new()
	_battle_system.battle_complete.connect(_on_battle_complete)
	_battle_system.battle_overtime.connect(_on_battle_overtime)
	add_child(_battle_system)

	SignalBus.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: int) -> void:
	if phase == RoundManager.Phase.COMBAT:
		_begin_combat()

func _begin_combat() -> void:
	_overtime_this_battle = false
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

	# Apply synergy bonuses merged with advisor bonuses to combat stats.
	var owner_id: int = GameState.local_player_id if team == 0 else _opponent_id
	var bonuses: Dictionary = SynergyManager.get_unit_bonuses(owner_id, inst.get("unit_id", ""))
	# Merge in advisor bonuses (additive, same key convention as synergies).
	var advisor_bonuses: Dictionary = AdvisorManager.get_bonuses(owner_id)
	for key in advisor_bonuses:
		bonuses[key] = float(bonuses.get(key, 0)) + float(advisor_bonuses[key])
	# Lean army bonus: +N% ATK and HP per empty board slot (capped at 25%).
	# Overdraft units count against the lean bonus — field fewer for bigger reward.
	var ps_owner := GameState.get_player(owner_id)
	if ps_owner != null:
		var max_slots  := EconomyManager.max_board_size(owner_id)
		var fielded    := ps_owner.board.size()
		var empty      := maxi(0, max_slots - fielded)
		var lean_per   := float(DataLoader.economy.get("lean_army_bonus_pct", 6))
		var lean_cap   := float(DataLoader.economy.get("lean_army_bonus_cap_pct", 25))
		var lean_pct   := minf(lean_cap, float(empty) * lean_per)
		if lean_pct > 0.0:
			bonuses["atk_pct"] = float(bonuses.get("atk_pct", 0)) + lean_pct
			bonuses["hp_pct"]  = float(bonuses.get("hp_pct",  0)) + lean_pct
	unit_node.setup_combat_stats(bonuses)

	return unit_node

func _board_coord_to_world(coord: Vector2i, mirror: bool) -> Vector2:
	const HEX_W := 74.0
	const HEX_H := 64.0
	const ROWS  := 4

	var offset_x := HEX_W * 0.5 if (coord.y % 2 != 0) else 0.0
	var x := HEX_W * coord.x + offset_x
	var y: float
	if mirror:
		# Enemy starts above the board; row 3 (their frontline) is one hex above row 0,
		# so they walk downward to engage player units on the visible hex tiles.
		y = -HEX_H * float(ROWS - coord.y)
	else:
		# Player: identical to Board._hex_to_pixel so units land on their prep tiles.
		y = HEX_H * coord.y
	return Vector2(x, y)

func _pick_opponent() -> int:
	var local_size := GameState.local_player().board.size()
	var all_candidates := []
	for ps in GameState.alive_players():
		if ps.player_id != GameState.local_player_id:
			all_candidates.append(ps)
	if all_candidates.is_empty():
		return -1
	# Prefer opponents fielding a similar number of units (±2 fielded).
	var close := all_candidates.filter(func(ps): return abs(ps.board.size() - local_size) <= 2)
	var pool := close if not close.is_empty() else all_candidates
	return pool[randi() % pool.size()].player_id

func _on_battle_overtime() -> void:
	_overtime_this_battle = true
	SignalBus.show_message.emit("⚔ Overtime! Battle speed doubled.", 2.0)

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

	# Dismiss overdraft (mercenary) units — they leave after each battle.
	_dismiss_overdraft_units(GameState.local_player_id)

	# Log every combat result — synergies/advisors query this for rivalries, streaks, etc.
	var combat_record := {
		"round":       GameState.current_round,
		"player_id":   GameState.local_player_id,
		"opponent_id": _opponent_id,
		"winner_id":   winner_id,
		"loser_id":    loser_id,
		"damage":      damage,
		"overtime":    _overtime_this_battle,
	}
	GameState.combat_log.append(combat_record)
	if _overtime_this_battle:
		GameState.overtime_log.append(combat_record)
		SignalBus.combat_overtime.emit(combat_record)

	SignalBus.combat_ended.emit(winner_id, loser_id, damage)
	RoundManager.on_combat_complete()

func _cleanup_units() -> void:
	for u in _player_units + _enemy_units:
		if is_instance_valid(u):
			u.queue_free()
	_player_units.clear()
	_enemy_units.clear()

## Remove units beyond the player's normal board cap (overdraft / mercenaries).
## Uses the same row-0-first sort as Board._refresh_overdraft_visuals so the
## same units that glowed red during prep are the ones dismissed.
func _dismiss_overdraft_units(player_id: int) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return
	var max_board := EconomyManager.max_board_size(player_id)
	var dismiss_count := ps.board.size() - max_board
	if dismiss_count <= 0:
		return

	# Same sort as Board._refresh_overdraft_visuals: most-recently-placed first.
	var coords := ps.board.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var oa: int = ps.board.get(a, {}).get("placed_order", 0)
		var ob: int = ps.board.get(b, {}).get("placed_order", 0)
		return oa > ob
	)

	for i in dismiss_count:
		var coord: Vector2i = coords[i]
		var inst: Dictionary = ps.board[coord]
		var unit_id: String  = inst.get("unit_id", "")
		ps.board.erase(coord)
		# Return one copy to the shared pool.
		if unit_id != "" and GameState.unit_pool.has(unit_id):
			GameState.unit_pool[unit_id] += 1
		SignalBus.unit_removed_from_board.emit(player_id, inst.get("instance_id", ""))

	# Record how many mercs were used so EconomyManager can apply the income penalty.
	ps.mercs_last_battle = dismiss_count
	SynergyManager.recalculate(player_id)
	var msg := "1 mercenary left after battle." if dismiss_count == 1 \
		else "%d mercenaries left after battle." % dismiss_count
	SignalBus.show_message.emit(msg, 2.5)
