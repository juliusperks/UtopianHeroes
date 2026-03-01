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
var _pending_source_board: Variant = null
var _pending_source_bench: int = -1
var _press_local_mouse: Vector2 = Vector2.ZERO

const PICK_RADIUS := 38.0
const DRAG_START_DISTANCE := 8.0

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
## True press-hold-release drag: mousedown picks up the nearest unit,
## mouseup drops it on the nearest hex cell or bench slot.

func _input(event: InputEvent) -> void:
	var local_mouse := to_local(get_global_mouse_position())
	if event is InputEventMouseMotion:
		_try_start_drag(local_mouse)
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_left_pressed(local_mouse)
		else:
			_on_left_released(local_mouse)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_try_sell(local_mouse)

func _on_left_pressed(local_mouse: Vector2) -> void:
	_press_local_mouse = local_mouse
	_pending_source_board = null
	_pending_source_bench = -1
	for coord in board_units.keys():
		if _hex_to_pixel(coord).distance_to(local_mouse) < PICK_RADIUS:
			_pending_source_board = coord
			get_viewport().set_input_as_handled()
			return
	for i in bench_units.size():
		if bench_units[i] != null and bench_slots[i].position.distance_to(local_mouse) < PICK_RADIUS:
			_pending_source_bench = i
			get_viewport().set_input_as_handled()
			return

func _on_left_released(local_mouse: Vector2) -> void:
	if _dragged_unit != null:
		_try_drop(local_mouse)
		return

	# Quick click: show unit info instead of forcing drag.
	if _pending_source_board != null and board_units.has(_pending_source_board):
		var board_unit: Node = board_units[_pending_source_board]
		SignalBus.show_unit_tooltip.emit(board_unit.unit_data, board_unit.instance_data)
		get_viewport().set_input_as_handled()
	elif _pending_source_bench >= 0 and _pending_source_bench < bench_units.size() and bench_units[_pending_source_bench] != null:
		var bench_unit: Node = bench_units[_pending_source_bench]
		SignalBus.show_unit_tooltip.emit(bench_unit.unit_data, bench_unit.instance_data)
		get_viewport().set_input_as_handled()
	else:
		SignalBus.hide_unit_tooltip.emit()

	_pending_source_board = null
	_pending_source_bench = -1

func _try_start_drag(local_mouse: Vector2) -> void:
	if _dragged_unit != null:
		return
	if not RoundManager.is_prep():
		return
	if _pending_source_board == null and _pending_source_bench < 0:
		return
	if _press_local_mouse.distance_to(local_mouse) < DRAG_START_DISTANCE:
		return
	if _pending_source_board != null:
		if board_units.has(_pending_source_board):
			_start_drag_from_board(_pending_source_board)
			get_viewport().set_input_as_handled()
	elif _pending_source_bench >= 0:
		if _pending_source_bench < bench_units.size() and bench_units[_pending_source_bench] != null:
			_start_drag_from_bench(_pending_source_bench)
			get_viewport().set_input_as_handled()
	_pending_source_board = null
	_pending_source_bench = -1

func _try_drop(local_mouse: Vector2) -> void:
	if _dragged_unit == null:
		return
	get_viewport().set_input_as_handled()
	# Nearest hex cell within snap radius
	var best_coord := Vector2i(-1, -1)
	var best_dist := 42.0
	for coord in hex_cells.keys():
		var d: float = _hex_to_pixel(coord).distance_to(local_mouse)
		if d < best_dist:
			best_dist = d
			best_coord = coord
	if best_coord != Vector2i(-1, -1):
		_finish_drop(best_coord)
		return
	# Nearest bench slot
	var best_bench := -1
	var best_bench_dist := 42.0
	for i in bench_slots.size():
		var d: float = bench_slots[i].position.distance_to(local_mouse)
		if d < best_bench_dist:
			best_bench_dist = d
			best_bench = i
	if best_bench >= 0:
		_finish_drop_to_bench(best_bench)
		return
	_cancel_drag()

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
	_sync_bench_state_from_visual()

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
		var displaced: Node = board_units[target_coord]
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
		var displaced: Node = bench_units[slot_idx]
		_place_unit_on_bench(_dragged_unit, slot_idx)
		if _drag_source_board != null:
			_place_unit_on_board(displaced, _drag_source_board)
		else:
			_place_unit_on_bench(displaced, _drag_source_bench)
	else:
		_place_unit_on_bench(_dragged_unit, slot_idx)
	_dragged_unit = null
	_drag_source_board = null
	_drag_source_bench = -1

func _cancel_drag() -> void:
	if _dragged_unit == null:
		return
	if _drag_source_board != null:
		_place_unit_on_board(_dragged_unit, _drag_source_board)
	elif _drag_source_bench >= 0:
		_place_unit_on_bench(_dragged_unit, _drag_source_bench)
	_dragged_unit = null
	_drag_source_board = null
	_drag_source_bench = -1

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
	_sync_bench_state_from_visual()

func _sync_bench_state_from_visual() -> void:
	var ps := GameState.local_player()
	ps.bench.clear()
	for unit_node in bench_units:
		if unit_node != null:
			ps.bench.append(unit_node.instance_data.duplicate())

func _try_sell(local_mouse: Vector2) -> void:
	if not RoundManager.is_prep():
		return
	# Sell from board
	for coord in board_units.keys():
		if _hex_to_pixel(coord).distance_to(local_mouse) < 38.0:
			var sold := ShopManager.sell_unit(GameState.local_player_id, board_units[coord].instance_id)
			if sold:
				SignalBus.show_message.emit("Unit sold.", 1.0)
				populate_from_state()
				get_viewport().set_input_as_handled()
			return
	# Sell from bench
	for i in bench_units.size():
		if bench_units[i] != null and bench_slots[i].position.distance_to(local_mouse) < 38.0:
			var sold := ShopManager.sell_unit(GameState.local_player_id, bench_units[i].instance_id)
			if sold:
				SignalBus.show_message.emit("Unit sold.", 1.0)
				populate_from_state()
				get_viewport().set_input_as_handled()
			return

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

func _on_phase_changed(phase: int) -> void:
	# During combat, disable board interaction
	var is_combat_phase := (phase == RoundManager.Phase.COMBAT)
	for cell in hex_cells.values():
		cell.input_pickable = not is_combat_phase
