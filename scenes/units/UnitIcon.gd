## UnitIcon — procedural hex portrait for a unit.
## Draws a flat-top hexagon in the origin faction's colour with a
## class-specific white silhouette inside.  No external assets needed.
extends Node2D

# ── Hex geometry ──────────────────────────────────────────────────────────────
const HEX_R := 26.0   # circumradius in pixels

# Set by Unit.init_from_data() before the node is ready
var origin_color: Color  = Color(0.38, 0.38, 0.42)
var unit_class:   String = ""

func setup(p_origin: String, p_class: String) -> void:
	origin_color = _origin_color(p_origin)
	unit_class   = p_class
	queue_redraw()

# ── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	var r   := HEX_R
	var mid := r - 3.0
	var hex := _hex_verts(r)

	# 1. Dark outer border
	draw_colored_polygon(hex, origin_color.darkened(0.50))
	# 2. Main fill
	draw_colored_polygon(_hex_verts(mid), origin_color)
	# 3. Top-third highlight for depth (top 3 verts form a triangle)
	draw_colored_polygon(PackedVector2Array([
		hex[4],             # top-left  (-r*0.866, -r*0.5)
		hex[5],             # top        (0, -r)
		hex[0],             # top-right  (r*0.866, -r*0.5)
		Vector2(mid * 0.6,  -1.0),
		Vector2(-mid * 0.6, -1.0),
	]), origin_color.lightened(0.28))
	# 4. Bottom-third shadow
	draw_colored_polygon(PackedVector2Array([
		hex[1],             # bottom-right
		hex[2],             # bottom
		hex[3],             # bottom-left
		Vector2(-mid * 0.5, 1.0),
		Vector2( mid * 0.5, 1.0),
	]), origin_color.darkened(0.20))

	# 5. Class silhouette
	_draw_class_icon()


func _draw_class_icon() -> void:
	var c := Color(1.0, 1.0, 1.0, 0.90)
	var s := 9.0

	match unit_class:
		"paladin":
			# Kite shield with cross
			draw_colored_polygon(PackedVector2Array([
				Vector2(0,       -s*1.40),
				Vector2( s*0.85, -s*0.55),
				Vector2( s*0.65,  s*0.90),
				Vector2(0,        s*1.35),
				Vector2(-s*0.65,  s*0.90),
				Vector2(-s*0.85, -s*0.55),
			]), c)
			var cross_c := origin_color.darkened(0.35)
			draw_line(Vector2(0, -s*0.65), Vector2(0,       s*0.80), cross_c, 2.5)
			draw_line(Vector2(-s*0.46, 0), Vector2(s*0.46, 0),       cross_c, 2.5)

		"rogue":
			# Two crossed daggers
			for sign in [1.0, -1.0]:
				var blade := PackedVector2Array([
					Vector2( sign * s*1.2,  -s*1.2),
					Vector2( sign * s*1.2 + s*0.22, -s*0.85),
					Vector2(-sign * s*0.0,  s*0.55),
					Vector2(-sign * s*0.22,  s*0.85),
				])
				draw_colored_polygon(blade, c)
				# Crossguard
				draw_line(
					Vector2(sign * s*0.85, -s*0.35),
					Vector2(sign * s*0.25, -s*0.75),
					c, 3.0)

		"general":
			# Five-pointed command star
			draw_colored_polygon(_star_points(s * 1.25, s * 0.50), c)

		"sage":
			# Open tome — two pages side by side
			for xf in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([
					Vector2(xf * s*0.06, -s*0.82),
					Vector2(xf * s*0.90, -s*0.82),
					Vector2(xf * s*0.90,  s*0.82),
					Vector2(xf * s*0.06,  s*0.82),
				]), c)
			# Spine shadow
			draw_line(Vector2(0, -s*0.9), Vector2(0, s*0.9),
					  origin_color.darkened(0.6), 2.5)
			# Page rulings
			for i in 3:
				var ly := -s*0.42 + i * s*0.37
				draw_line(Vector2( s*0.14, ly), Vector2( s*0.78, ly), origin_color.lightened(0.5), 1.2)
				draw_line(Vector2(-s*0.78, ly), Vector2(-s*0.14, ly), origin_color.lightened(0.5), 1.2)

		"mystic":
			# Tall crystal — outer diamond + inner glow edge
			draw_colored_polygon(PackedVector2Array([
				Vector2(0,       -s*1.45),
				Vector2( s*0.95,  0),
				Vector2(0,        s*1.45),
				Vector2(-s*0.95,  0),
			]), c)
			draw_polyline(PackedVector2Array([
				Vector2(0,        -s*0.70),
				Vector2( s*0.46,   0),
				Vector2(0,         s*0.70),
				Vector2(-s*0.46,   0),
				Vector2(0,        -s*0.70),
			]), origin_color.lightened(0.55), 1.5)

		"heretic":
			# Downward triangle with lidded eye
			draw_colored_polygon(PackedVector2Array([
				Vector2(-s*1.10, -s*0.90),
				Vector2( s*1.10, -s*0.90),
				Vector2(0,        s*1.15),
			]), c)
			# Sclera
			draw_circle(Vector2(0, -s*0.15), s*0.42, origin_color.darkened(0.20))
			# Iris
			draw_circle(Vector2(0, -s*0.15), s*0.20, origin_color.darkened(0.55))
			# Pupil
			draw_circle(Vector2(0, -s*0.15), s*0.08, Color(0, 0, 0, 0.8))

		"shepherd":
			# Crook — vertical staff with curved top hook
			draw_line(Vector2(s*0.38,  s*1.40), Vector2(s*0.38, -s*0.28), c, 3.2)
			draw_arc(Vector2(-s*0.02, -s*0.28), s*0.40,
					 deg_to_rad(0.0), deg_to_rad(180.0), 20, c, 3.2)
			# Small bud at crook tip
			draw_circle(Vector2(-s*0.42, -s*0.28), s*0.18, c)
			# Decorative notch on staff
			draw_line(Vector2(s*0.10, s*0.55), Vector2(s*0.65, s*0.55), c, 2.0)

		"merchant":
			# Gold coin — outer ring, recessed face, currency mark
			draw_circle(Vector2(0, 0), s*1.12, c)
			draw_circle(Vector2(0, 0), s*0.82, origin_color.darkened(0.12))
			draw_line(Vector2(0, -s*0.55), Vector2(0,        s*0.55), c, 3.2)
			draw_line(Vector2(-s*0.34, -s*0.22), Vector2(s*0.34, -s*0.22), c, 2.2)
			draw_line(Vector2(-s*0.34,  s*0.22), Vector2(s*0.34,  s*0.22), c, 2.2)

		_:
			# Unknown — plain diamond
			draw_colored_polygon(PackedVector2Array([
				Vector2(0,       -s*1.15),
				Vector2( s*0.80,  0),
				Vector2(0,        s*1.15),
				Vector2(-s*0.80,  0),
			]), c)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _hex_verts(r: float) -> PackedVector2Array:
	var v := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 30.0)   # flat-top orientation
		v.append(Vector2(r * cos(a), r * sin(a)))
	return v

func _star_points(outer_r: float, inner_r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := deg_to_rad(i * 36.0 - 90.0)
		var r := outer_r if (i % 2 == 0) else inner_r
		pts.append(Vector2(r * cos(a), r * sin(a)))
	return pts

func _origin_color(origin: String) -> Color:
	match origin:
		"avian":                    return Color(0.24, 0.63, 0.84)  # sky blue
		"dwarf":                    return Color(0.55, 0.38, 0.22)  # warm brown
		"elf":                      return Color(0.22, 0.54, 0.33)  # forest green
		"darkelf", "dark_elf":      return Color(0.35, 0.16, 0.55)  # deep purple
		"orc":                      return Color(0.28, 0.48, 0.15)  # moss green
		"undead":                   return Color(0.45, 0.58, 0.40)  # pallid sage
		"halfling":                 return Color(0.76, 0.65, 0.46)  # warm tan
		"faerie":                   return Color(0.82, 0.32, 0.59)  # fuchsia
		_:                          return Color(0.38, 0.38, 0.42)  # slate grey
