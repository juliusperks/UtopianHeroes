## BenchSlot — one of 9 reserve slots below the player's board.
## Units on the bench don't fight but can be placed onto the board during prep.
extends Area2D

signal clicked(slot_index: int)
signal hovered(slot_index: int)
signal unhovered(slot_index: int)

const SLOT_SIZE := Vector2(60.0, 60.0)
const COLOR_EMPTY    := Color(0.2, 0.22, 0.28, 0.8)
const COLOR_OCCUPIED := Color(0.28, 0.3, 0.38, 0.9)
const COLOR_HOVER    := Color(0.4, 0.5, 0.7, 0.9)

var slot_index: int = 0
var is_occupied: bool = false

var _rect: ColorRect
var _collision: CollisionShape2D

func _ready() -> void:
	_build_slot()
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func _build_slot() -> void:
	_rect = ColorRect.new()
	_rect.size = SLOT_SIZE
	_rect.position = -SLOT_SIZE / 2.0
	_rect.color = COLOR_EMPTY
	add_child(_rect)

	var shape := RectangleShape2D.new()
	shape.size = SLOT_SIZE
	_collision = CollisionShape2D.new()
	_collision.shape = shape
	add_child(_collision)

func mark_occupied(occupied: bool) -> void:
	is_occupied = occupied
	_rect.color = COLOR_OCCUPIED if occupied else COLOR_EMPTY

func _on_mouse_entered() -> void:
	_rect.color = COLOR_HOVER
	hovered.emit(slot_index)

func _on_mouse_exited() -> void:
	_rect.color = COLOR_OCCUPIED if is_occupied else COLOR_EMPTY
	unhovered.emit(slot_index)

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(slot_index)
