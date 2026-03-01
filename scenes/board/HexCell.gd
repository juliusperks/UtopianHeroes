## HexCell — a single tile on the hexagonal board.
## Handles hover highlights and click-to-place logic.
## The hex shape and collision are created programmatically.
extends Area2D

signal clicked(coord: Vector2i)
signal hovered(coord: Vector2i)
signal unhovered(coord: Vector2i)

const HEX_RADIUS := 36.0   # pixels, flat-top hex (circumradius)
const HEX_COLOR_NORMAL   := Color(0.25, 0.28, 0.35, 0.8)
const HEX_COLOR_HOVER    := Color(0.45, 0.55, 0.75, 0.9)
const HEX_COLOR_OCCUPIED := Color(0.22, 0.25, 0.30, 0.8)
const HEX_COLOR_INVALID  := Color(0.7, 0.2, 0.2, 0.7)

var coord: Vector2i = Vector2i.ZERO
var is_occupied: bool = false
var is_player_half: bool = true  # false for enemy half (shown during combat)

var _polygon: Polygon2D
var _collision: CollisionPolygon2D

func _ready() -> void:
	_build_hex()
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func _build_hex() -> void:
	var verts := _hex_vertices(HEX_RADIUS)

	_polygon = Polygon2D.new()
	_polygon.polygon = verts
	_polygon.color = HEX_COLOR_NORMAL
	add_child(_polygon)

	_collision = CollisionPolygon2D.new()
	_collision.polygon = verts
	add_child(_collision)

func _hex_vertices(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle_deg := 60.0 * i - 30.0  # flat-top orientation
		var angle_rad := deg_to_rad(angle_deg)
		pts.append(Vector2(r * cos(angle_rad), r * sin(angle_rad)))
	return pts

func set_highlight(active: bool) -> void:
	_polygon.color = HEX_COLOR_HOVER if active else (HEX_COLOR_OCCUPIED if is_occupied else HEX_COLOR_NORMAL)

func set_invalid(invalid: bool) -> void:
	if invalid:
		_polygon.color = HEX_COLOR_INVALID
	else:
		_polygon.color = HEX_COLOR_NORMAL

func mark_occupied(occupied: bool) -> void:
	is_occupied = occupied
	_polygon.color = HEX_COLOR_OCCUPIED if occupied else HEX_COLOR_NORMAL

func _on_mouse_entered() -> void:
	if not is_occupied:
		_polygon.color = HEX_COLOR_HOVER
	hovered.emit(coord)

func _on_mouse_exited() -> void:
	_polygon.color = HEX_COLOR_OCCUPIED if is_occupied else HEX_COLOR_NORMAL
	unhovered.emit(coord)

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(coord)
