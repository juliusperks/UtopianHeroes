## AIBoardPositioner — places AI units onto the hex board each prep phase.
## Strategy: put tanks (high HP) in front rows, ranged/casters in back rows.
class_name AIBoardPositioner
extends RefCounted

const ROWS := 4
const COLS := 7

var _player_id: int

func _init(player_id: int) -> void:
	_player_id = player_id

func arrange_board() -> void:
	var ps := GameState.get_player(_player_id)
	if ps == null:
		return

	var max_board := EconomyManager.max_board_size(_player_id)

	# Collect all available units (bench + board)
	var all_units: Array = []
	for inst in ps.bench:
		all_units.append(inst)
	for coord in ps.board:
		all_units.append(ps.board[coord])

	# Sort: high-range units to back (row 3), tanky units to front (row 0)
	all_units.sort_custom(func(a, b):
		var da: UnitData = DataLoader.units[a.get("unit_id", "")]
		var db: UnitData = DataLoader.units[b.get("unit_id", "")]
		if da == null or db == null:
			return false
		# Ranged/casters go back, melee/tanks go front
		return da.atk_range < db.atk_range
	)

	# Clear board and bench, re-place top N units
	ps.board.clear()
	ps.bench.clear()

	var placed := 0
	for inst in all_units:
		if placed >= max_board:
			ps.bench.append(inst)
			continue
		var coord := _next_empty_coord(ps.board, placed)
		ps.board[coord] = inst
		placed += 1

	SynergyManager.recalculate(_player_id)

func _next_empty_coord(board: Dictionary, index: int) -> Vector2i:
	# Fill from back row to front row, left to right
	# AI uses rows 4-7 (enemy side, but for state purposes rows 0-3)
	var positions: Array = []
	for row in range(ROWS - 1, -1, -1):
		for col in range(COLS):
			var c := Vector2i(col, row)
			if not board.has(c):
				positions.append(c)
	if index < positions.size():
		return positions[index]
	return Vector2i(0, 0)
