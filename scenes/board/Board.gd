## Board — manages the 4×7 hex grid for the local player.
## Handles unit placement, drag-and-drop between board and bench.
## Grid coordinate (0,0) = top-left.  Player occupies rows 0-3 (bottom half shown to player).
extends Node2D

const ROWS := 4
const COLS := 7
const HEX_W := 74.0   # horizontal distance between hex centers (flat-top)
const HEX_H := 64.0   # vertical distance between hex centers

const HexCellScene  := preload("res://scenes/board/HexCell.tscn")
const BenchSlotScene := preload("res://scenes/board/BenchSlot.tscn")
const UnitScene     := preload("res://scenes/units/Unit.tscn")

# Visual nodes for hex cells and bench slots
var hex_cells: Dictionary = {}   # Vector2i -> HexCell node
var bench_slots: Array = []      # Array[BenchSlot] — 9 slots

# Live unit nodes (visual only — source of truth is GameState)
var board_units: Dictionary = {} # Vector2i -> Unit node
var bench_units: Array = []      # Array[Unit or null], length = max_bench

# Drag state
var _dragged_unit: Node = null        # Unit node being dragged
var _drag_source_board: Variant = null  # Vector2i if from board, null if from bench
var _drag_source_bench: int = -1       # bench index if from bench, -1 if from board

func _ready() -> void:
	_build_grid()
	_build_bench()
	_connect_signals()

func _build_grid() -> void:
	for row in ROWS:
		for col in COLS:
			var coord := Vector2i(col, row)
			var cell: Node = HexCellScene.instantiate()
			cell.coord = coord
			cell.position = _hex_to_pixel(coord)
			cell.clicked.connect(_on_cell_clicked.bind(coord))
			cell.hovered.connect(_on_cell_hovered.bind(coord))
			add_child(cell)
			hex_cells[coord] = cell

func _build_bench() -> void:
	var max_bench: int = DataLoader.economy.get("max_bench_size", 9)
	var bench_y := (ROWS + 0.5) * HEX_H + 20.0
	var total_w := max_bench * 68.0
	var start_x := -total_w / 2.0 + 34.0

	for i in max_bench:
		var slot: Node = BenchSlotScene.instantiate()
		slot.slot_index = i
		slot.position = Vector2(start_x + i * 68.0, bench_y)
		slot.clicked.connect(_on_bench_slot_clicked.bind(i))
		add_child(slot)
		bench_slots.append(slot)
		bench_units.append(null)

func _connect_signals() -> void:
	SignalBus.unit_placed_on_board.connect(_on_unit_placed_on_board)
	SignalBus.unit_removed_from_board.connect(_on_unit_removed_from_board)
	SignalBus.unit_placed_on_bench.connect(_on_unit_placed_on_bench)
	SignalBus.unit_upgraded.connect(_on_unit_upgraded)
	SignalBus.synergies_updated.connect(_on_synergies_updated)
	SignalBus.phase_changed.connect(_on_phase_changed)

# ── Hex coordinate math ───────────────────────────────────────────────────────

func _hex_to_pixel(coord: Vector2i) -> Vector2:
	var offset_x := HEX_W * 0.5 if (coord.y % 2 != 0) else 0.0
	var x := HEX_W * coord.x + offset_x
	var y := HEX_H * coord.y
	return Vector2(x, y)

# ── Input / Drag & Drop ───────────────────────────────────────────────────────

func _on_cell_clicked(coord: Vector2i) -> void:
	if _dragged_unit != null:
		_finish_drop(coord)
		return

	# If a unit is on this cell, start dragging it
	if board_units.has(coord):
		_start_drag_from_board(coord)

func _on_bench_slot_clicked(slot_idx: int) -> void:
	if _dragged_unit != null:
		_finish_drop_to_bench(slot_idx)
		return
	if bench_units[slot_idx] != null:
		_start_drag_from_bench(slot_idx)

func _start_drag_from_board(coord: Vector2i) -> void:
	if not RoundManager.is_prep():
		return
	_dragged_unit = board_units[coord]
	_drag_source_board = coord
	_drag_source_bench = -1
	_dragged_unit.z_index = 10
	board_units.erase(coord)
	hex_cells[coord].mark_occupied(false)
	GameState.get_player(GameState.local_player_id).board.erase(coord)
	SynergyManager.recalculate(GameState.local_player_id)

func _start_drag_from_bench(slot_idx: int) -> void:
	if not RoundManager.is_prep():
		return
	_dragged_unit = bench_units[slot_idx]
	_drag_source_board = null
	_drag_source_bench = slot_idx
	_dragged_unit.z_index = 10
	bench_units[slot_idx] = null
	bench_slots[slot_idx].mark_occupied(false)
	# Remove from GameState bench
	var ps := GameState.local_player()
	if slot_idx < ps.bench.size():
		ps.bench.remove_at(slot_idx)

func _finish_drop(target_coord: Vector2i) -> void:
	if not hex_cells.has(target_coord):
		_cancel_drag()
		return

	# Check board size limit
	var max_board := EconomyManager.max_board_size(GameState.local_player_id)
	if not board_units.has(target_coord) and board_units.size() >= max_board:
		SignalBus.show_message.emit("Board full! Level up to place more units.", 2.0)
		_cancel_drag()
		return

	# Swap if target is occupied
	if board_units.has(target_coord):
		var displaced := board_units[target_coord]
		_place_unit_on_board(_dragged_unit, target_coord)
		# Move displaced unit back to source
		if _drag_source_board != null:
			_place_unit_on_board(displaced, _drag_source_board)
		else:
			_place_unit_on_bench(displaced, _drag_source_bench)
	else:
		_place_unit_on_board(_dragged_unit, target_coord)

	_dragged_unit = null
	_drag_source_board = null
	_drag_source_bench = -1

func _finish_drop_to_bench(slot_idx: int) -> void:
	if bench_units[slot_idx] != null:
		var displaced := bench_units[slot_idx]
		_place_unit_on_bench(_dragged_unit, slot_idx)
		if _drag_source_board != null:
			_place_unit_on_board(displaced, _drag_source_board)
		else:
			_place_unit_on_bench(displaced, _drag_source_bench)
	else:
		_place_unit_on_bench(_dragged_unit, slot_idx)
	_dragged_unit = null

func _cancel_drag() -> void:
	if _dragged_unit == null:
		return
	if _drag_source_board != null:
		_place_unit_on_board(_dragged_unit, _drag_source_board)
	elif _drag_source_bench >= 0:
		_place_unit_on_bench(_dragged_unit, _drag_source_bench)
	_dragged_unit = null

func _process(_delta: float) -> void:
	if _dragged_unit != null:
		_dragged_unit.global_position = get_global_mouse_position()

# ── Placement ─────────────────────────────────────────────────────────────────

func _place_unit_on_board(unit_node: Node, coord: Vector2i) -> void:
	unit_node.z_index = 1
	unit_node.position = _hex_to_pixel(coord)
	board_units[coord] = unit_node
	hex_cells[coord].mark_occupied(true)

	# Sync to GameState
	var ps := GameState.local_player()
	ps.board[coord] = unit_node.instance_data.duplicate()
	SynergyManager.recalculate(GameState.local_player_id)
	SignalBus.unit_placed_on_board.emit(GameState.local_player_id, unit_node.instance_id, coord)

func _place_unit_on_bench(unit_node: Node, slot_idx: int) -> void:
	unit_node.z_index = 1
	unit_node.position = bench_slots[slot_idx].position
	bench_units[slot_idx] = unit_node
	bench_slots[slot_idx].mark_occupied(true)

	# Sync to GameState
	var ps := GameState.local_player()
	ps.bench.append(unit_node.instance_data.duplicate())

# ── Spawn unit nodes from GameState ──────────────────────────────────────────

## Called on game start or when loading saved state
func populate_from_state() -> void:
	_clear_unit_nodes()
	var ps := GameState.local_player()
	for coord in ps.board:
		var inst: Dictionary = ps.board[coord]
		var unit_node := _spawn_unit_node(inst)
		board_units[coord] = unit_node
		unit_node.position = _hex_to_pixel(coord)
		hex_cells[coord].mark_occupied(true)
		add_child(unit_node)
	for i in ps.bench.size():
		if i >= bench_slots.size():
			break
		var inst: Dictionary = ps.bench[i]
		var unit_node := _spawn_unit_node(inst)
		bench_units[i] = unit_node
		unit_node.position = bench_slots[i].position
		bench_slots[i].mark_occupied(true)
		add_child(unit_node)

func _spawn_unit_node(instance_data: Dictionary) -> Node:
	var unit_node: Node = UnitScene.instantiate()
	unit_node.init_from_data(instance_data)
	return unit_node

func _clear_unit_nodes() -> void:
	for unit_node in board_units.values():
		if is_instance_valid(unit_node):
			unit_node.queue_free()
	board_units.clear()
	for i in bench_units.size():
		if bench_units[i] != null and is_instance_valid(bench_units[i]):
			bench_units[i].queue_free()
		bench_units[i] = null
	for slot in bench_slots:
		slot.mark_occupied(false)
	for cell in hex_cells.values():
		cell.mark_occupied(false)

# ── Signal callbacks ──────────────────────────────────────────────────────────

func _on_unit_placed_on_board(player_id: int, instance_id: String, coord: Vector2i) -> void:
	if player_id != GameState.local_player_id:
		return
	# Already handled in _place_unit_on_board; this is for external placements (future net)

func _on_unit_removed_from_board(player_id: int, instance_id: String) -> void:
	if player_id != GameState.local_player_id:
		return
	for coord in board_units.keys():
		var unit_node: Node = board_units[coord]
		if unit_node.instance_id == instance_id:
			board_units.erase(coord)
			hex_cells[coord].mark_occupied(false)
			unit_node.queue_free()
			return

func _on_unit_placed_on_bench(player_id: int, _instance_id: String) -> void:
	if player_id == GameState.local_player_id:
		populate_from_state()  # Refresh visual from state

func _on_unit_upgraded(player_id: int, _unit_id: String, _new_star: int) -> void:
	if player_id == GameState.local_player_id:
		populate_from_state()

func _on_synergies_updated(player_id: int, _bonuses: Dictionary) -> void:
	pass  # SynergyPanel handles this

func _on_cell_hovered(_coord: Vector2i) -> void:
	pass

func _on_phase_changed(phase: int) -> void:
	# During combat, disable board interaction
	var is_combat_phase := (phase == RoundManager.Phase.COMBAT)
	for cell in hex_cells.values():
		cell.input_pickable = not is_combat_phase
