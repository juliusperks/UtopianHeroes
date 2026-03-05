## GameState — single source of truth for all mutable game state.
##
## MULTIPLAYER SEAM: PlayerState uses only plain dicts/arrays/primitives.
## No Node references live here. A future StateReplicator can diff and sync
## the entire `players` array over ENet/WebSocket without touching any other system.
##
## Systems read from this; they update it through their own logic, then emit signals
## on SignalBus so UI and other systems react.
extends Node

const PLAYER_COUNT := 8
const INVALID_ID   := -1

var local_player_id: int = 0
var current_round: int = 0
var current_phase: int = 0   # mirrors RoundManager.Phase

# The shared unit pool: unit_id -> count remaining in pool
var unit_pool: Dictionary = {}

## Full combat log — one entry per battle, every round.
## Each entry: { round, player_id, opponent_id, winner_id, loser_id, damage, overtime: bool }
## Query via helpers below: get_combat_history(), get_wins_vs(), get_overtime_count().
var combat_log: Array = []

## Convenience alias — overtime-only subset of combat_log.
## Kept separate so UI/advisors can reference it without filtering.
var overtime_log: Array = []

# All 8 players' states (0 = local human, 1-7 = AI in single-player)
var players: Array = []   # Array[PlayerState]

# ── PlayerState inner class ──────────────────────────────────────────────────
class PlayerState:
	var player_id: int = 0
	var is_ai: bool = false
	var is_alive: bool = true

	# Economy
	var gold: int = 3
	var xp: int = 0
	var level: int = 1

	# Combat
	var hp: int = 100
	var win_streak: int = 0
	var loss_streak: int = 0

	# Units  (each unit instance is a Dictionary — see _make_unit_instance below)
	var bench: Array = []          # Array[Dictionary] — up to max_bench_size
	var board: Dictionary = {}     # Vector2i -> Dictionary (unit instance)

	# Shop (unit ids, "" = empty slot)
	var shop_slots: Array = []     # Array[String], length = shop_size

	# Items not yet equipped
	var item_inventory: Array = [] # Array[String] item_ids

	# Purchased advisors (persist for the whole game)
	var advisors: Array = []       # Array[String] advisor_ids

	# Shop lock — when true the shop is not refreshed at round start
	var shop_locked: bool = false

	# Tracks how many overdraft (merc) units were dismissed last battle
	# EconomyManager reads this at income time then resets it to 0
	var mercs_last_battle: int = 0

	# Temporary per-round bonuses (from trait effects like Merchant gold_per_win)
	var pending_win_gold: int = 0
	var free_rerolls_remaining: int = 0

# ── Unit instance dictionary schema ──────────────────────────────────────────
# {
#   "instance_id": String,   unique id for this specific unit on the board/bench
#   "unit_id":     String,   references DataLoader.units key
#   "star":        int,      1 / 2 / 3
#   "items":       Array,    Array[String] item_ids (max 3)
#   "hp":          float,    current HP — set at combat start from UnitData + star
# }

static func make_unit_instance(unit_id: String, star: int = 1) -> Dictionary:
	return {
		"instance_id": _generate_instance_id(),
		"unit_id": unit_id,
		"star": star,
		"items": [],
		"hp": -1.0   # -1 means "use base stat" — set by BattleSystem at combat start
	}

static func _generate_instance_id() -> String:
	# Simple unique id using a monotonic counter + randomness
	return "%d_%d" % [Time.get_ticks_msec(), randi() % 99999]

# ── Initialization ────────────────────────────────────────────────────────────

func _ready() -> void:
	pass  # Players are set up when a game starts via init_game()

func init_game(ai_count: int = 7) -> void:
	if AdvisorManager != null:
		AdvisorManager.reset_for_new_game()
	players.clear()
	combat_log.clear()
	overtime_log.clear()
	for i in PLAYER_COUNT:
		var ps := PlayerState.new()
		ps.player_id = i
		ps.is_ai     = (i != local_player_id)
		ps.gold      = DataLoader.economy.get("starting_gold", 3)
		ps.level     = int(DataLoader.economy.get("starting_level", 1))
		ps.xp        = int(DataLoader.economy.get("starting_xp", 0))
		ps.hp        = DataLoader.economy.get("starting_hp", 100)
		players.append(ps)
	_init_pool()
	current_round = 0

func _init_pool() -> void:
	unit_pool.clear()
	var pool_sizes: Dictionary = DataLoader.economy.get("pool_sizes", {})
	for uid in DataLoader.units:
		var cost: int = DataLoader.units[uid].cost
		var pool_key := str(cost)
		unit_pool[uid] = int(pool_sizes.get(pool_key, 18))

# ── Accessors ─────────────────────────────────────────────────────────────────

func get_player(player_id: int) -> PlayerState:
	if player_id < 0 or player_id >= players.size():
		return null
	return players[player_id]

func local_player() -> PlayerState:
	return get_player(local_player_id)

func alive_players() -> Array:
	return players.filter(func(p): return p.is_alive)

func alive_player_count() -> int:
	return alive_players().size()

## Returns a unit instance dict from either board or bench. Returns null if not found.
func find_unit_instance(player_id: int, instance_id: String) -> Dictionary:
	var ps := get_player(player_id)
	if ps == null:
		return {}
	for inst in ps.bench:
		if inst.get("instance_id", "") == instance_id:
			return inst
	for coord in ps.board:
		var inst: Dictionary = ps.board[coord]
		if inst.get("instance_id", "") == instance_id:
			return inst
	return {}

## Count how many copies of unit_id the player has (board + bench, all stars)
func count_unit_copies(player_id: int, unit_id: String) -> int:
	var ps := get_player(player_id)
	if ps == null:
		return 0
	var count := 0
	for inst in ps.bench:
		if inst.get("unit_id", "") == unit_id:
			count += 1
	for coord in ps.board:
		if ps.board[coord].get("unit_id", "") == unit_id:
			count += 1
	return count

## Try to merge 3 copies of the same unit into a 2-star (returns true if merge happened)
func try_merge_units(player_id: int, unit_id: String) -> bool:
	var ps := get_player(player_id)
	if ps == null:
		return false

	# Collect all 1-star instances
	var one_stars: Array = []
	for inst in ps.bench:
		if inst.get("unit_id") == unit_id and inst.get("star", 1) == 1:
			one_stars.append({"source_type": "bench", "source": -1, "inst": inst})
	for coord in ps.board:
		var inst: Dictionary = ps.board[coord]
		if inst.get("unit_id") == unit_id and inst.get("star", 1) == 1:
			one_stars.append({"source_type": "board", "source": coord, "inst": inst})

	if one_stars.size() < 3:
		return false

	# Remove 3 one-stars and add 1 two-star
	var removed := 0
	var first_board_coord: Variant = null
	for entry in one_stars:
		if removed >= 3:
			break
		if entry["source_type"] == "bench":
			ps.bench.erase(entry["inst"])
		else:
			if first_board_coord == null:
				first_board_coord = entry["source"]
			ps.board.erase(entry["source"])
		removed += 1

	var new_inst := make_unit_instance(unit_id, 2)
	# Preserve items from the first instance if any
	if not one_stars.is_empty():
		new_inst["items"] = one_stars[0]["inst"].get("items", []).duplicate()

	if first_board_coord != null:
		ps.board[first_board_coord] = new_inst
	else:
		ps.bench.append(new_inst)

	SignalBus.unit_upgraded.emit(player_id, unit_id, 2)
	return true

## Serialise all player states to a Dictionary (for save/multiplayer sync)
func serialize() -> Dictionary:
	var out := {"round": current_round, "phase": current_phase, "players": []}
	for ps in players:
		out["players"].append({
			"player_id": ps.player_id,
			"is_ai": ps.is_ai,
			"is_alive": ps.is_alive,
			"gold": ps.gold,
			"xp": ps.xp,
			"level": ps.level,
			"hp": ps.hp,
			"win_streak": ps.win_streak,
			"loss_streak": ps.loss_streak,
			"bench": ps.bench.duplicate(true),
			"board": _serialize_board(ps.board),
			"shop_slots": ps.shop_slots.duplicate(),
			"item_inventory": ps.item_inventory.duplicate()
		})
	return out

# ── Combat history queries ────────────────────────────────────────────────────
# All helpers treat (a vs b) and (b vs a) as the same matchup unless noted.

## All combat entries involving both player_a and player_b.
func get_combat_history(player_a: int, player_b: int) -> Array:
	return combat_log.filter(func(r): return \
		(r["player_id"] == player_a and r["opponent_id"] == player_b) or \
		(r["player_id"] == player_b and r["opponent_id"] == player_a))

## Number of times player_a beat player_b.
func get_wins_vs(player_a: int, player_b: int) -> int:
	return get_combat_history(player_a, player_b).filter(
		func(r): return r["winner_id"] == player_a).size()

## Number of times these two players went to overtime.
func get_overtime_count(player_a: int, player_b: int) -> int:
	return get_combat_history(player_a, player_b).filter(
		func(r): return r["overtime"]).size()

## Total overtimes the local player has been involved in this game.
func local_overtime_count() -> int:
	return combat_log.filter(func(r): return \
		r["overtime"] and \
		(r["player_id"] == local_player_id or r["opponent_id"] == local_player_id)).size()

func _serialize_board(board: Dictionary) -> Array:
	var arr := []
	for coord in board:
		arr.append({"x": coord.x, "y": coord.y, "unit": board[coord].duplicate(true)})
	return arr
