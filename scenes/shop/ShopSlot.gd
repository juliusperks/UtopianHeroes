## ShopSlot — one of 5 shop cards showing a purchasable unit.
## Created and managed by ShopPanel.
extends PanelContainer

signal purchase_requested(slot_index: int)

var slot_index: int = 0
var unit_id: String = ""

var _name_label: Label
var _cost_label: Label
var _origin_label: Label
var _class_label: Label
var _buy_button: Button
var _locked_label: Label
var _icon_bg: ColorRect
var _icon_glyph: Label

func _ready() -> void:
	custom_minimum_size = Vector2(110, 150)
	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(0, 58)
	vbox.add_child(icon_wrap)

	_icon_bg = ColorRect.new()
	_icon_bg.custom_minimum_size = Vector2(52, 52)
	_icon_bg.color = Color(0.2, 0.26, 0.34)
	icon_wrap.add_child(_icon_bg)

	_icon_glyph = Label.new()
	_icon_glyph.text = "?"
	_icon_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_glyph.size = Vector2(52, 52)
	_icon_glyph.add_theme_font_size_override("font_size", 28)
	_icon_glyph.add_theme_constant_override("outline_size", 2)
	_icon_glyph.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_icon_bg.add_child(_icon_glyph)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text = "—"
	vbox.add_child(_name_label)

	_origin_label = Label.new()
	_origin_label.add_theme_font_size_override("font_size", 10)
	_origin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_origin_label.modulate = Color(0.7, 0.9, 1.0)
	vbox.add_child(_origin_label)

	_class_label = Label.new()
	_class_label.add_theme_font_size_override("font_size", 10)
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_label.modulate = Color(1.0, 0.85, 0.6)
	vbox.add_child(_class_label)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 14)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.modulate = Color.GOLD
	vbox.add_child(_cost_label)

	_buy_button = Button.new()
	_buy_button.text = "Buy"
	_buy_button.add_theme_font_size_override("font_size", 14)
	_buy_button.custom_minimum_size = Vector2(0, 34)
	_buy_button.pressed.connect(func(): purchase_requested.emit(slot_index))
	_style_buy_button(Color(0.10, 0.55, 0.20))
	vbox.add_child(_buy_button)

	_locked_label = Label.new()
	_locked_label.text = "LOCKED"
	_locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_locked_label.modulate = Color.LIGHT_YELLOW
	_locked_label.visible = false
	vbox.add_child(_locked_label)

func set_unit(p_unit_id: String) -> void:
	unit_id = p_unit_id
	var is_locked := p_unit_id.begins_with("LOCKED:")
	var effective_id := p_unit_id.substr(7) if is_locked else p_unit_id

	_locked_label.visible = is_locked

	if effective_id == "":
		_name_label.text = "Empty"
		_origin_label.text = ""
		_class_label.text = ""
		_cost_label.text = ""
		_icon_bg.color = Color(0.2, 0.26, 0.34, 0.7)
		_icon_glyph.text = ""
		_buy_button.visible = false
		var empty_sb := StyleBoxFlat.new()
		empty_sb.bg_color = Color(0.16, 0.24, 0.48, 0.95)
		empty_sb.border_width_left = 2
		empty_sb.border_width_right = 2
		empty_sb.border_width_top = 2
		empty_sb.border_width_bottom = 2
		empty_sb.border_color = Color(0.42, 0.58, 0.95, 0.85)
		empty_sb.corner_radius_top_left = 4
		empty_sb.corner_radius_top_right = 4
		empty_sb.corner_radius_bottom_left = 4
		empty_sb.corner_radius_bottom_right = 4
		add_theme_stylebox_override("panel", empty_sb)
		return

	_buy_button.visible = true
	var udata: UnitData = DataLoader.units.get(effective_id, null)
	if udata == null:
		return

	_name_label.text = udata.display_name
	_origin_label.text = udata.origin.capitalize()
	_class_label.text = udata.unit_class.capitalize()
	_cost_label.text = "%d ★" % udata.cost
	_icon_bg.color = _origin_icon_color(udata.origin)
	_icon_glyph.text = _class_glyph(udata.unit_class)
	_buy_button.disabled = is_locked

	# Color background by cost tier
	var panel_color := _cost_color(udata.cost)
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel_color
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_color = panel_color.lightened(0.3)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", sb)

func _cost_color(cost: int) -> Color:
	match cost:
		1: return Color(0.38, 0.42, 0.50, 0.98)
		2: return Color(0.17, 0.48, 0.21, 0.98)
		3: return Color(0.14, 0.33, 0.74, 0.98)
		4: return Color(0.56, 0.12, 0.56, 0.98)
		5: return Color(0.78, 0.58, 0.06, 0.98)
		_: return Color(0.28, 0.30, 0.36, 0.98)

func set_affordable(can_afford: bool) -> void:
	var disabled := not can_afford or unit_id.begins_with("LOCKED:")
	_buy_button.disabled = disabled
	_buy_button.modulate = Color(1, 1, 1, 0.55) if disabled else Color(1, 1, 1, 1)

func _style_buy_button(base: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = base.lightened(0.25)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	_buy_button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = base.lightened(0.15)
	_buy_button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = base.darkened(0.18)
	_buy_button.add_theme_stylebox_override("pressed", pressed)

func _origin_icon_color(origin: String) -> Color:
	match origin:
		"avian": return Color(0.23, 0.55, 0.87)
		"dwarf": return Color(0.60, 0.43, 0.23)
		"elf": return Color(0.21, 0.58, 0.34)
		"dark_elf", "darkelf": return Color(0.42, 0.22, 0.62)
		"orc": return Color(0.34, 0.52, 0.17)
		"undead": return Color(0.46, 0.56, 0.45)
		"halfling": return Color(0.66, 0.55, 0.35)
		"faerie": return Color(0.77, 0.28, 0.58)
		"human": return Color(0.26, 0.45, 0.80)
		"gnome": return Color(0.45, 0.40, 0.73)
		"dryad": return Color(0.20, 0.50, 0.31)
		_: return Color(0.30, 0.35, 0.43)

func _class_glyph(unit_class: String) -> String:
	match unit_class:
		"paladin": return "P"
		"rogue": return "R"
		"general": return "G"
		"sage": return "S"
		"mystic": return "M"
		"heretic": return "H"
		"shepherd": return "D"
		"merchant": return "$"
		_: return "?"
